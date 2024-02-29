//
//  LidarContentView.swift
//  Ray
//
//  Created by Samuel Seng on 10/4/22.
//

import SwiftUI

struct LidarDepthView: View {
    var body: some View {
        EmptyView()
    }
}

struct LidarColorView: View {
    var lidarCameraController: LidarCameraController
    var body: some View {
        CameraViewControllerRepresentable(lidarCameraController: lidarCameraController)
    }
}

struct LidarContentView: View {
    private var lidarCameraController = LidarCameraController()
    var body: some View {
        VStack {
            ZStack {
                LidarColorView(lidarCameraController: lidarCameraController)
                LidarDepthView()
            }
        }
        .onAppear(perform: {
            DispatchQueue.global(qos: .background).async {
                lidarCameraController.startStream()
            }
        })
    }
}

struct LidarContentView_Previews: PreviewProvider {
    static var previews: some View {
        LidarContentView()
    }
}
