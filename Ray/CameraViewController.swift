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
    
    var lidarCameraController: LidarCameraController
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    required init(lidarCameraController: LidarCameraController) {
        self.lidarCameraController = lidarCameraController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for CameraViewController")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.lidarCameraController.session)
        guard let previewLayer = self.previewLayer else {
            print("Could not create preview layer")
            return
        }
        let bounds = self.view.bounds
        previewLayer.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: bounds.width, height: bounds.height))
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        print("Created previewLayer")
        self.view.layer.addSublayer(previewLayer)
    }
}

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    var lidarCameraController: LidarCameraController
    
    public typealias UIViewControllerType = CameraViewController
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraViewControllerRepresentable>) -> CameraViewController {
        let viewController = CameraViewController(lidarCameraController: lidarCameraController)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: UIViewControllerRepresentableContext<CameraViewControllerRepresentable>) {
        
        
    }
}
