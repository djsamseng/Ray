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


class LidarCameraController: NSObject, ObservableObject, AVCaptureDataOutputSynchronizerDelegate {
    private let captureMotion = false;
    
    private let preferredWidthResolution = 1920
    private let videoQueue = DispatchQueue(label: "VideoQueue", qos: .userInteractive)
    private let audioQueue = DispatchQueue(label: "AudioQueuue", qos: .userInteractive)
    private(set) var session: AVCaptureSession!
    private var audioOutput: AVCaptureAudioDataOutput!
    private var videoOutput: AVCaptureVideoDataOutput!
    private var depthOutput: AVCaptureDepthDataOutput!
    private var videoSync: AVCaptureDataOutputSynchronizer!
    
    private let ciContext = CIContext(options: nil)
    
    private var videoStreamer: ServerStreamer2
    private var depthStreamer: ServerStreamer2

    private var didPrintAudioFormat = false
    
    private var motionManager = CMMotionManager()
    
    fileprivate var previousOrientation = UIDeviceOrientation.unknown
    
    var ips: [String]
    @Published private(set) var ip: String
    @Published private(set) var selectedIpIdx: Int
    
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
        let ips = getIP()
        let selectedIpIdx = 0
        let ip = ips[selectedIpIdx]
        self.ip = ip
        self.ips = ips
        self.selectedIpIdx = selectedIpIdx
        self.videoStreamer = ServerStreamer2(ip: ip, port: 10001)
        self.depthStreamer = ServerStreamer2(ip: ip, port: 10002)
        
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
    
    func changeIp(ip: String) {
        if ip != self.ip {
            self.stopStream()
            self.videoStreamer.stopStreaming()
            self.depthStreamer.stopStreaming()
            self.ip = ip
            self.selectedIpIdx = self.ips.firstIndex(of: ip) ?? 0
            self.videoStreamer = ServerStreamer2(ip: ip, port: 10001)
            self.depthStreamer = ServerStreamer2(ip: ip, port: 10002)
            self.startStream()
        }
    }
    
    private func setupDeviceMotion() {
        if !self.captureMotion {
            return
        }
        self.motionManager.deviceMotionUpdateInterval = 1.0 / 100.0
        self.motionManager.showsDeviceMovementDisplay = true
        self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
    }
    
    private func setupSession() throws {
        self.session = AVCaptureSession()
        self.session.sessionPreset = .inputPriority
        self.session.beginConfiguration()
        
        try self.setupCaptureInput()
        self.setupCaptureOutputs()
        self.session.commitConfiguration()
    }
    
    private func setupCaptureInput() throws {
        guard let lidarDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera, for:. video, position: .back) else {
            print("No lidar device")
            throw ConfigurationError.lidarDeviceUnavailable
        }
        guard let format = (lidarDevice.formats.last { format in
            print("Availble format:", format.formatDescription.dimensions.width)
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
        if self.captureMotion {
            if outputConnection.isCameraIntrinsicMatrixDeliverySupported {
                outputConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
    }
    
    func startStream() {
        self.session.startRunning()
    }
    
    func stopStream() {
        self.session.stopRunning()
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
    
    private func streamDepth(depthData: AVDepthData) {
        if depthData.depthDataType != kCVPixelFormatType_DepthFloat16 {
            print("Unhandled depth type:", depthData.depthDataType)
        }
        
        guard let depthImage = CIImage(depthData: depthData) else { return }
        let uiImage = UIImage(ciImage: depthImage)
        guard let depthImageToSend = uiImage.jpegData(compressionQuality: 0) else { return }
        self.depthStreamer.streamData(data: depthImageToSend)
    }
    
    private func streamVideo(videoData: CMSampleBuffer) {
        
        guard let capture = CMSampleBufferGetImageBuffer(videoData) else { return }
        
        let ciImage = CIImage(cvImageBuffer: capture, options: nil)
        let uiImage = UIImage(ciImage: ciImage)
        guard let resizedImage = resizeImage(im: uiImage) else { return }
        guard let videoImageToSend = resizedImage.jpegData(compressionQuality: 0.8) else { return }
        self.videoStreamer.streamData(data: videoImageToSend)
        
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
        self.updateOrientation()
        //print("Success pixelBuffer")
        if self.captureMotion {
            var userAcceleration: [Double]? = nil
            var userDirection: [Double]? = nil
            if let motionData = self.motionManager.deviceMotion {
                userAcceleration = [motionData.userAcceleration.x, motionData.userAcceleration.y, motionData.userAcceleration.z]
                userDirection = [motionData.attitude.roll, motionData.attitude.pitch, motionData.attitude.yaw]
            }
        }
        self.streamVideo(videoData: syncedVideoData.sampleBuffer)
        self.streamDepth(depthData: syncedDepthData.depthData)
    }
    
    fileprivate func updateOrientation() {
        let currentOrientation = UIDevice.current.orientation
        if currentOrientation != self.previousOrientation {
            switch currentOrientation {
            case .portrait:
                self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
                self.depthOutput.connection(with: .depthData)?.videoRotationAngle = 90
            case .landscapeRight:
                self.videoOutput.connection(with: .video)?.videoRotationAngle = 180
                self.depthOutput.connection(with: .depthData)?.videoRotationAngle = 180
            case .landscapeLeft:
                self.videoOutput.connection(with: .video)?.videoRotationAngle = 0
                self.depthOutput.connection(with: .depthData)?.videoRotationAngle = 0
            case .portraitUpsideDown:
                self.videoOutput.connection(with: .video)?.videoRotationAngle = 270
                self.depthOutput.connection(with: .depthData)?.videoRotationAngle = 270
            default:
                self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
                self.depthOutput.connection(with: .depthData)?.videoRotationAngle = 90
            }

            self.previousOrientation = currentOrientation
        }
    }
}
