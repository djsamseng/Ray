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


class LidarCameraController: NSObject, ObservableObject {
    private let captureMotion = false;
    
    private let preferredWidthResolution = 1920
    private let videoQueue = DispatchQueue(label: "VideoQueue", qos: .userInteractive)
    private let audioQueue = DispatchQueue(label: "AudioQueuue", qos: .userInteractive)
    private(set) var session: AVCaptureSession!
    private var lidarDevice: AVCaptureDevice?
    private var audioOutput: AVCaptureAudioDataOutput!
    private var videoOutput: AVCaptureVideoDataOutput!
    private var depthOutput: AVCaptureDepthDataOutput!
    private var videoSync: AVCaptureDataOutputSynchronizer!
    
    private let ciContext = CIContext(options: nil)
    
    var cameraServer: CameraServer

    private var didPrintAudioFormat = false
    
    private var motionManager = CMMotionManager()
    
    fileprivate var previousOrientation = UIDeviceOrientation.unknown
    
    var ips: [String]
    @Published private(set) var ip: String
    @Published private(set) var selectedIpIdx: Int
    
    private var focusDepth: Float = 0.5
    
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
    required init(cameraServer: CameraServer) {
        //CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MetalEnvironment.shared.metalDevice, nil, &textureCache)
        let ips = getIP()
        let selectedIpIdx = 0
        let ip = ips[selectedIpIdx]
        self.ip = ip
        self.ips = ips
        self.selectedIpIdx = selectedIpIdx
        self.cameraServer = cameraServer
        
        super.init()
    }
    
    func changeIp(ip: String) {
        if ip != self.ip {
            self.stopStream()
            self.ip = ip
            self.selectedIpIdx = self.ips.firstIndex(of: ip) ?? 0
            self.startStream()
        }
    }
    
    func setFocusDepth(depth: Float) {
        guard depth != self.focusDepth else { return }
        self.focusDepth = depth
        guard let lidarDevice = self.cameraServer.getDevice() else { return } //self.lidarDevice else { return }
        guard lidarDevice.isLockingFocusWithCustomLensPositionSupported else { return }
        guard (try? lidarDevice.lockForConfiguration()) != nil else { return }
        lidarDevice.setFocusModeLocked(lensPosition: depth, completionHandler: { time in
            print("Set focus to:\(depth) in \(time)")
            lidarDevice.unlockForConfiguration()
        })
        
    }
    
    func startStream() {
        self.cameraServer.startup()
    }
    
    func stopStream() {
        self.cameraServer.shutdown()
    }
}
