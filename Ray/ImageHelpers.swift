//
//  ImageHelpers.swift
//  Ray
//
//  Created by Samuel Seng on 10/4/22.
//

import Foundation
import CoreMedia
import UIKit
import AVFoundation

class ImageHelpers {
    static let context = CIContext()
    static func cvPixelBufferToData(cvPixelBuffer: CVPixelBuffer) -> Data? {
        guard let sampleBuffer = sampleBufferFromPixelBuffer(pixelBuffer: cvPixelBuffer, seconds: 0) else { return nil }
        guard let capture: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return Self.cvImageBufferToData(cvImageBuffer: capture)
    }
    static func cvImageBufferToData(cvImageBuffer: CVImageBuffer) -> Data? {
        let sourceImage = CIImage(cvImageBuffer: cvImageBuffer, options: nil)
        guard let cgImage = Self.context.createCGImage(sourceImage, from: sourceImage.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        guard let data = image.jpegData(compressionQuality: 0) else { return nil }
        return data
    }
    static func convertDepthDataToArray(depthData: AVDepthData) -> Data {
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthDataMap = convertedDepthData.depthDataMap
        return Self.convertDepthDataMapToArray(depthDataMap: depthDataMap)
        
    }
    static func convertDepthDataMapToArray(depthDataMap: CVPixelBuffer) -> Data {
        let width = CVPixelBufferGetWidth(depthDataMap)
        let height = CVPixelBufferGetHeight(depthDataMap)
        
        CVPixelBufferLockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer: UnsafeMutablePointer<Float32> = unsafeBitCast(CVPixelBufferGetBaseAddress(depthDataMap), to: UnsafeMutablePointer<Float32>.self)
        let data = Data(bytes: floatBuffer, count: width * height * 4)
        return data
    }
}
