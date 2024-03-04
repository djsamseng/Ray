//
//  LidarCameraManager.swift
//  Ray
//
//  Created by Samuel Seng on 10/4/22.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import CoreImage
import CoreMotion

func cvPixelBufferToCvImageBuffer(cvPixelBuffer: CVPixelBuffer) -> CVImageBuffer? {
    guard let sampleBuffer = sampleBufferFromPixelBuffer(pixelBuffer: cvPixelBuffer, seconds: 0) else { return nil }
    guard let capture: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
    return capture
}

extension matrix_float3x3: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode([SIMD3<Float>].self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode([columns.0,columns.1, columns.2])
    }
}



class LidarCameraCaptureData: Encodable {
    var depthImage: Data
    var colorImage: Data?
    var userAcceleration: [Double]?
    var userDirection: [Double]?
    var cameraIntrinsics: matrix_float3x3
    var cameraReferenceDimesnions: CGSize
    var pixelSize: Float
    
    init(depth: Data,
         color: CVImageBuffer,
         userAcceleration: [Double]?,
         userDirection: [Double]?,
         cameraIntrinsics: matrix_float3x3,
         cameraReferenceDimesnions: CGSize,
         pixelSize: Float) {
        self.depthImage = depth
        self.colorImage = ImageHelpers.cvImageBufferToData(cvImageBuffer: color)
        self.userAcceleration = userAcceleration
        self.userDirection = userDirection
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimesnions = cameraReferenceDimesnions
        self.pixelSize = pixelSize
    }
}

class LidarCameraController: NSObject, ObservableObject, AVCaptureDataOutputSynchronizerDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let preferredWidthResolution = 1920
    private let videoQueue = DispatchQueue(label: "VideoQueue", qos: .userInteractive)
    private let audioQueue = DispatchQueue(label: "AudioQueuue", qos: .userInteractive)
    private(set) var session: AVCaptureSession!
    private var audioOutput: AVCaptureAudioDataOutput!
    private var videoOutput: AVCaptureVideoDataOutput!
    private var depthOutput: AVCaptureDepthDataOutput!
    private var videoSync: AVCaptureDataOutputSynchronizer!
    
    private let serverStreamer = ServerStreamer()
    //private let audioServerStreamer = ServerStreamer(port: 10002)

    private var didPrintAudioFormat = false
    
    private var motionManager = CMMotionManager()
    
    var isFilteringEnabled = true {
        didSet {
            self.depthOutput.isFilteringEnabled = isFilteringEnabled
        }
    }
    enum ConfigurationError: Error {
        case lidarDeviceUnavailable
        case requiredFormatUnavailable
        case audioDeviceUnavailable
    }
    override init() {
        //CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MetalEnvironment.shared.metalDevice, nil, &textureCache)
        super.init()
        print("Created LidarCameraController")
        self.setupDeviceMotion()
        do {
            try self.setupSession()
        }
        catch {
            fatalError("Failed to setup lidar camera capture session")
        }
    }
    
    private func setupDeviceMotion() {
        self.motionManager.deviceMotionUpdateInterval = 1.0 / 100.0
        self.motionManager.showsDeviceMovementDisplay = true
        self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
    }
    
    private func setupSession() throws {
        self.session = AVCaptureSession()
        self.session.sessionPreset = .inputPriority
        self.session.beginConfiguration()
        
        try self.setupAudioCaptureInput()
        try self.setupCaptureInput()
        self.setupCaptureOutputs()
        self.session.commitConfiguration()
    }
    
    private func setupAudioCaptureInput() throws {
        return
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("audioDeviceUnavailable")
            throw ConfigurationError.audioDeviceUnavailable
        }
        let deviceInput = try AVCaptureDeviceInput(device: audioDevice)
        self.session.addInput(deviceInput)
    }
    
    private func setupCaptureInput() throws {
        guard let lidarDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera, for:. video, position: .back) else {
            print("No lidar device")
            throw ConfigurationError.lidarDeviceUnavailable
        }
        guard let format = (lidarDevice.formats.last { format in
            return format.formatDescription.dimensions.width == self.preferredWidthResolution &&
            format.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange &&
            !format.isVideoBinned &&
            !format.supportedDepthDataFormats.isEmpty
        }) else {
            print("Format failed")
            throw ConfigurationError.requiredFormatUnavailable
        }
        guard let depthFormat = (format.supportedDepthDataFormats.last { depthFormat in
            depthFormat.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_DepthFloat16
        }) else {
            print("Depth format failed")
            throw ConfigurationError.requiredFormatUnavailable
        }
        try lidarDevice.lockForConfiguration()
        lidarDevice.activeFormat = format
        lidarDevice.activeDepthDataFormat = depthFormat
        lidarDevice.unlockForConfiguration()
        print("Video format: \(lidarDevice.activeFormat) Depth format: \(String(describing: lidarDevice.activeDepthDataFormat))")
        
        let deviceInput = try AVCaptureDeviceInput(device: lidarDevice)
        self.session.addInput(deviceInput)
    }
    
    private func setupCaptureOutputs() {
        self.audioOutput = AVCaptureAudioDataOutput()
        self.session.addOutput(self.audioOutput)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
        
        self.videoOutput = AVCaptureVideoDataOutput()
        self.session.addOutput(self.videoOutput)
        
        self.depthOutput = AVCaptureDepthDataOutput()
        self.depthOutput.isFilteringEnabled = self.isFilteringEnabled
        self.session.addOutput(self.depthOutput)
        
        self.videoSync = AVCaptureDataOutputSynchronizer(dataOutputs: [self.depthOutput, self.videoOutput])
        self.videoSync.setDelegate(self, queue: self.videoQueue)
        
        guard let outputConnection = self.videoOutput.connection(with: .video) else {
            print("Failed to create videoOutput connection")
            return
        }
        if outputConnection.isCameraIntrinsicMatrixDeliverySupported {
            outputConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }
    }
    
    func startStream() {
        self.session.startRunning()
    }
    
    func stopStream() {
        self.session.stopRunning()
    }
    
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == self.audioOutput {
            self.printAudioFormatOnce(sampleBuffer: sampleBuffer)
            let audioData = AudioHelpers.getAudioData(sampleBuffer: sampleBuffer)
            
            let audioCaptureData = AudioCaptureData(audioData: audioData)
            let encoder = JSONEncoder()
            let data = try! encoder.encode(audioCaptureData)
            //self.audioServerStreamer.streamData(data: data)
        }
    }
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: self.depthOutput) as? AVCaptureSynchronizedDepthData,
              let syncedVideoData = synchronizedDataCollection.synchronizedData(for: self.videoOutput) as? AVCaptureSynchronizedSampleBufferData else {
            // print("Failed to synchronize depth and video")
            return
        }
        guard let pixelBuffer = syncedVideoData.sampleBuffer.imageBuffer,
              let cameraCalibrationData = syncedDepthData.depthData.cameraCalibrationData else {
            //print("Failed to get pixelBuffer and cameraCalibrationData")
            return
        }
        //print("Success pixelBuffer")
        var userAcceleration: [Double]? = nil
        var userDirection: [Double]? = nil
        if let motionData = self.motionManager.deviceMotion {
            userAcceleration = [motionData.userAcceleration.x, motionData.userAcceleration.y, motionData.userAcceleration.z]
            userDirection = [motionData.attitude.roll, motionData.attitude.pitch, motionData.attitude.yaw]
        }
        if syncedDepthData.depthData.depthDataType != kCVPixelFormatType_DepthFloat16 {
            print("Unhandled depth type:", syncedDepthData.depthData.depthDataType)
        }
        guard let resized = resizeVideoBuffer(videoData: syncedVideoData.sampleBuffer) else {
            print("Could not resize")
            return
        }
        let depthFloatData = ImageHelpers.convertDepthDataToArray(depthData: syncedDepthData.depthData)
        
        
        let captureData = LidarCameraCaptureData(depth: depthFloatData, color: resized, userAcceleration: userAcceleration, userDirection: userDirection, cameraIntrinsics: cameraCalibrationData.intrinsicMatrix, cameraReferenceDimesnions: cameraCalibrationData.intrinsicMatrixReferenceDimensions, pixelSize: cameraCalibrationData.pixelSize)
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(captureData)
        self.serverStreamer.streamData(data: data)
    }
    
    func printAudioFormatOnce(sampleBuffer: CMSampleBuffer) {
        if didPrintAudioFormat {
            return
        }
        didPrintAudioFormat = true
        AudioHelpers.printAudioFormat(sampleBuffer: sampleBuffer)
    }
    
    func pixelBufferFromCGImage(image: CGImage) -> CVPixelBuffer? {
        var pxbuffer: CVPixelBuffer? = nil
        let options: NSDictionary = [:]

        let width =  image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow
        
        let dataFromImageDataProvider = CFDataCreateMutableCopy(kCFAllocatorDefault, 0, image.dataProvider!.data)
        guard let x = CFDataGetMutableBytePtr(dataFromImageDataProvider) else { return nil}

        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            width,
            height,
            
            kCVPixelFormatType_32BGRA,
            x,
            bytesPerRow,
            nil,
            nil,
            options,
            &pxbuffer
        )
        return pxbuffer;
    }
    
    func resizeVideoBuffer(videoData: CMSampleBuffer) -> CVPixelBuffer? {
        guard let capture = CMSampleBufferGetImageBuffer(videoData) else { return nil }
        
        let ciImage = CIImage(cvImageBuffer: capture, options: nil)
        let uiImage = UIImage(ciImage: ciImage)
        guard let resizedImage = resizeImage(im: uiImage) else { return nil }
        guard let cgImage = resizedImage.cgImage else { return nil }
        return pixelBufferFromCGImage(image: cgImage)
    }
    
    func resizeImage(im: UIImage) -> UIImage? {
        let scale = 0.2
        let newWidth = im.size.width * scale
        let newHeight = im.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        im.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}
