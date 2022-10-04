//
//  ImageHelpers.swift
//  Ray
//
//  Created by Samuel Seng on 10/4/22.
//

import Foundation
import CoreMedia
import UIKit

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
}
