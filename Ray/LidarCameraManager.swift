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

class AudioCaptureData: Encodable {
    var audioData: Data
    init(audioData: Data) {
        self.audioData = audioData
    }
}

class LidarCameraCaptureData: Encodable {
    var depthImage: Data?
    var colorImage: Data?
    var userAcceleration: [Double]?
    var cameraIntrinsics: matrix_float3x3
    var cameraReferenceDimesnions: CGSize
    
    init(depth: CVPixelBuffer? = nil,
         color: CVImageBuffer? = nil,
         userAcceleration: [Double]? = nil,
         cameraIntrinsics: matrix_float3x3 = matrix_float3x3(),
         cameraReferenceDimesnions: CGSize = .zero) {
        if let depth = depth {
            self.depthImage = ImageHelpers.cvPixelBufferToData(cvPixelBuffer: depth)
        }
        if let color = color {
            self.colorImage = ImageHelpers.cvImageBufferToData(cvImageBuffer: color)
        }
        self.userAcceleration = userAcceleration
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimesnions = cameraReferenceDimesnions
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
    private let audioServerStreamer = ServerStreamer(port: 10002)

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
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("audioDeviceUnavailable")
            throw ConfigurationError.audioDeviceUnavailable
        }
        let deviceInput = try AVCaptureDeviceInput(device: audioDevice)
        self.session.addInput(deviceInput)
    }
    
    private func setupCaptureInput() throws {
        guard let lidarDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera, for:. video, position: .back) else {
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
    
    func getAudioData(sampleBuffer: CMSampleBuffer) -> Data {
        var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 0, mDataByteSize: 0, mData: nil))
        var blockBuffer: CMBlockBuffer?

        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)

        let audioBuffer = audioBufferList.mBuffers
        let data : Data = Data.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
        return (data as NSData).copy() as! Data
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == self.audioOutput {
            self.printAudioFormatOnce(sampleBuffer: sampleBuffer)
            let audioData = self.getAudioData(sampleBuffer: sampleBuffer)
            
            let audioCaptureData = AudioCaptureData(audioData: audioData)
            let encoder = JSONEncoder()
            let data = try! encoder.encode(audioCaptureData)
            self.audioServerStreamer.streamData(data: data)
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
            print("Failed to get pixelBuffer and cameraCalibrationData")
            return
        }
        var userAcceleration: [Double]? = nil
        if let motionData = self.motionManager.deviceMotion {
            userAcceleration = [motionData.userAcceleration.x, motionData.userAcceleration.y, motionData.userAcceleration.z]
        }
        let captureData = LidarCameraCaptureData(depth: syncedDepthData.depthData.depthDataMap, color: pixelBuffer, userAcceleration: userAcceleration, cameraIntrinsics: cameraCalibrationData.intrinsicMatrix, cameraReferenceDimesnions: cameraCalibrationData.intrinsicMatrixReferenceDimensions)
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(captureData)
        self.serverStreamer.streamData(data: data)
    }
    
    func printAudioFormatOnce(sampleBuffer: CMSampleBuffer) {
        if didPrintAudioFormat {
            return
        }
        didPrintAudioFormat = true
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            print("Could not get audio format description")
            return
        }
        guard let audioDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format) else {
            print("Could not get audio stream basic description")
            return
        }
        let numChannels = audioDescription.pointee.mChannelsPerFrame
        let audioFormat = audioDescription.pointee.mFormatID
        let bitsPerChannel = audioDescription.pointee.mBitsPerChannel
        if audioFormat == kAudioFormatLinearPCM && numChannels == 1 && bitsPerChannel == 16 {
            print("Audio Format: LinearPCM, 1 channel, 16 bits per channel")
        }
        else {
            print("Unhandled audio format: \(audioFormat), \(numChannels) channels, \(bitsPerChannel) bits per channel")
        }
    }
}
