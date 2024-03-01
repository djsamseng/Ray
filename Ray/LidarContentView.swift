//
//  LidarContentView.swift
//  Ray
//
//  Created by Samuel Seng on 10/4/22.
//

import SwiftUI

struct LidarDepthView: View {
    @StateObject var lidarCameraController: LidarCameraController
    
    var ips = getIP()
    var body: some View {
        HStack(alignment:.top) {
            VStack(alignment:.leading) {
                Text(lidarCameraController.ip)
                    .foregroundColor(.blue)
                ForEach(lidarCameraController.ips ?? [], id: \.self) { ip in
                    if ip == lidarCameraController.ip {
                        EmptyView()
                    }
                    else {
                        Button(action: {
                            lidarCameraController.changeIp(ip: ip)
                        }, label: {
                            Text(ip)
                        })
                    }
                }
                Spacer()
            }
            Spacer()
        }
            .foregroundColor(.white)
            .padding()
        
    }
}

struct LidarColorView: View {
    var lidarCameraController: LidarCameraController?
    var body: some View {
        CameraViewControllerRepresentable(lidarCameraController: lidarCameraController)
    }
}

struct LidarContentView: View {
    @StateObject var lidarCameraController: LidarCameraController
    var body: some View {
        VStack {
            ZStack {
                LidarColorView(lidarCameraController: lidarCameraController)
                LidarDepthView(lidarCameraController: lidarCameraController)
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
        EmptyView()
        //LidarContentView()
        //    .previewInterfaceOrientation(.landscapeLeft)
    }
}
