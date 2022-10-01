//
//  ContentView.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//

import SwiftUI
import RealityKit

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
        
        // TODO: Change to postProcess to allow ARView to show the box
        // arView.renderCallbacks.postProcess = self.arViewPostProcess(context:)
        arDataProvider.arReceiver.setArSession(arSession: arView.session)
        
        // Load the "Box" scene from the "Experience" Reality File
        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor)
        
        return arView
        
    }
    /*
    func image(from texture: MTLTexture) -> UIImage? {
        let bytesPerPixel = 4

        // The total number of bytes of the texture
        let imageByteCount = texture.width * texture.height * bytesPerPixel

        // The number of bytes for each image row
        let bytesPerRow = texture.width * bytesPerPixel

        // An empty buffer that will contain the image
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))

        // Gets the bytes from the texture
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        // Creates an image context
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &src, width: texture.width, height: texture.height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)

        // Creates the image from the graphics context
        guard let dstImage = context?.makeImage() else { return nil }

        // Creates the final UIImage
        return UIImage(cgImage: dstImage, scale: 0.0, orientation: .up)
    }
    
    func arViewPostProcess(context: ARView.PostProcessContext) {
        let blitEncoder = context.commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
        blitEncoder?.endEncoding()
        
        guard let pixelBuffer = self.image(from: context.sourceColorTexture) else {
            print("Failed to get color texture")
            return
        }
        self.arDataProvider.streamPixelBuffer(image: pixelBuffer)
    }*/
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
