//
//  ContentView.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//

import SwiftUI
import RealityKit
import ARKit

struct ContentView : View {
    var arDataProvider: ARDataProvider = ARDataProvider.instance
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
        .onAppear(perform: {
                arDataProvider.start()
            })
    }
}

struct ARViewContainer: UIViewRepresentable {
    var arDataProvider: ARDataProvider = ARDataProvider.instance
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = arDataProvider.arReceiver.arSession

        // Add the box anchor to the scene
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)
        
        let realityKitAnchor = try! Experience.loadBox()
        realityKitAnchor.position = SIMD3(0, -0.1, -0.2)
        
        arView.scene.anchors.append(realityKitAnchor)
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
