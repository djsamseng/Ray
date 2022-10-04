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
    var depthImage: Data?
    var colorImage: Data?
    var cameraIntrinsics: matrix_float3x3
    var cameraReferenceDimesnions: CGSize
    
    init(depth: CVPixelBuffer? = nil,
         color: CVImageBuffer? = nil,
         cameraIntrinsics: matrix_float3x3 = matrix_float3x3(),
         cameraReferenceDimesnions: CGSize = .zero) {
        if let depth = depth {
            self.depthImage = ImageHelpers.cvPixelBufferToData(cvPixelBuffer: depth)
        }
        if let color = color {
            self.colorImage = ImageHelpers.cvImageBufferToData(cvImageBuffer: color)
        }
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
        do {
            try self.setupSession()
        }
        catch {
            fatalError("Failed to setup lidar camera capture session")
        }
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
            format.formatDescription.dimensions.width == self.preferredWidthResolution &&
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
        // print("Got audio:", sampleBuffer.numSamples)
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
        let captureData = LidarCameraCaptureData(depth: syncedDepthData.depthData.depthDataMap, color: pixelBuffer, cameraIntrinsics: cameraCalibrationData.intrinsicMatrix, cameraReferenceDimesnions: cameraCalibrationData.intrinsicMatrixReferenceDimensions)
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(captureData)
        self.serverStreamer.streamData(data: data)
    }
}
