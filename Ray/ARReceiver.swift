//
//  ARReceiver.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//

import Foundation
import SwiftUI
import Combine
import ARKit

class ARReceiver: NSObject, ARSessionDelegate {
    weak var delegate: ARDataProvider?
    private var arSession: ARSession? = nil
    override init() {
        super.init()
        //self.arSession!.delegate = self
        //self.start()
    }
    
    func setArSession(arSession: ARSession) {
        self.arSession = arSession
        self.arSession!.delegate = self
        self.start()
    }
    
    func start() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) else { return }
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        self.arSession?.run(config)
    }
    
    func pause() {
        self.arSession?.pause()
    }
    
    func session(_ session:ARSession, didUpdate frame: ARFrame) {
        if frame.sceneDepth != nil && frame.smoothedSceneDepth != nil {
            // Stream the data!
            self.delegate?.onNewARData(arFrame: frame)
        }
    }
}
