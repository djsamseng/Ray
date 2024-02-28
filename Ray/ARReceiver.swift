//
//  ARReceiver.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//

import Foundation
import SwiftUI
import Combine
import RealityKit
import ARKit

class ARReceiver: NSObject, ARSessionDelegate {
    weak var delegate: ARDataProvider?
    private(set) var arSession: ARSession = ARSession()
    override init() {
        super.init()
        print("Created ARReceiver")
        self.arSession.delegate = self
        self.start()
    }
    
    func start() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) else {
            print("===== Could not start WorldTrackingConfiguration =====")
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        //config.providesAudioData = true
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        self.arSession.run(config)
    }
    
    func pause() {
        self.arSession.pause()
    }
    
    func session(_ session:ARSession, didUpdate frame: ARFrame) {
        if frame.sceneDepth != nil && frame.smoothedSceneDepth != nil {
            // Stream the data!
            self.delegate?.onNewARData(arFrame: frame)
        }
    }
    
    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        self.delegate?.onNewAudioData(sampleBuffer: audioSampleBuffer)
    }
}
