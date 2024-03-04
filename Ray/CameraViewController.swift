//
//  CameraViewController.swift
//  Ray
//
//  Created by Samuel Seng on 2/29/24.
//

import AVFoundation
import Foundation
import UIKit
import SwiftUI


final class CameraViewController: UIViewController {
    
    var lidarCameraController: LidarCameraController?
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastOrientation = UIDeviceOrientation.unknown
    
    
    required init(lidarCameraController: LidarCameraController?) {
        self.lidarCameraController = lidarCameraController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for CameraViewController")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        
        guard let lidarCameraController = self.lidarCameraController else {
            print("No LidarCameraController")
            return
        }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: lidarCameraController.session)
        guard let previewLayer = self.previewLayer else {
            print("Could not create preview layer")
            return
        }
        let bounds = self.view.bounds
        print(bounds)
        previewLayer.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: bounds.width, height: bounds.height))
        previewLayer.videoGravity = .resizeAspect
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        print("Created previewLayer")
        self.view.layer.addSublayer(previewLayer)
        
        
    }
    
    func updateOrientation() {
        guard let previewLayer = self.previewLayer else { return }
        guard let connection = previewLayer.connection else { return }
        
        let statusBarOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .landscapeLeft
        var newAngle: CGFloat = 90.0
        if statusBarOrientation == .landscapeLeft {
            newAngle = 0
        }
        else if statusBarOrientation == .landscapeRight {
            newAngle = 180
        }
        else if statusBarOrientation == .portraitUpsideDown {
            newAngle = 270
        }
        if previewLayer.connection?.videoRotationAngle == newAngle {
            return
        }
        guard connection.isVideoRotationAngleSupported(newAngle) else { return }
        previewLayer.frame = self.view.frame
        previewLayer.connection?.videoRotationAngle = newAngle
        previewLayer.removeAllAnimations()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil, completion: {[weak self] (context) in
            DispatchQueue.main.async(execute: {
                self?.updateOrientation()
            })
        })
    }
}

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    var lidarCameraController: LidarCameraController?
    
    public typealias UIViewControllerType = CameraViewController
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraViewControllerRepresentable>) -> CameraViewController {
        let viewController = CameraViewController(lidarCameraController: lidarCameraController)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: UIViewControllerRepresentableContext<CameraViewControllerRepresentable>) {
        
        
    }
}
