//
//  ARDataProvider.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//

import Foundation
import ARKit

func handleCMSampleBufferError(status: OSStatus) {
    switch status {
    case kCMSampleBufferError_AllocationFailed:
        print("AllocationFailed")
    case kCMSampleBufferError_AlreadyHasDataBuffer:
        print("AlreadyHasDataBuffer")
    case kCMSampleBufferError_ArrayTooSmall:
        print("ArrayTooSmall")
    case kCMSampleBufferError_BufferHasNoSampleSizes:
        print("BufferHasNoSampleSizes")
    case kCMSampleBufferError_BufferNotReady:
        print("BufferNotReady")
    case kCMSampleBufferError_CannotSubdivide:
        print("CannotSubdivide")
    case kCMSampleBufferError_DataFailed:
        print("DataFailed")
    case kCMSampleBufferError_DataCanceled:
        print("DataCanceled")
    case kCMSampleBufferError_Invalidated:
        print("Invalidated")
    case kCMSampleBufferError_InvalidEntryCount:
        print("InvalidEntryCount")
    case kCMSampleBufferError_InvalidMediaTypeForOperation:
        print("InvalidMediaTypeForOperation")
    case kCMSampleBufferError_InvalidSampleData:
        print("InvalidSampleData")
    case kCMSampleBufferError_InvalidMediaFormat:
        print("InvalidMediaFormat")
    case kCMSampleBufferError_RequiredParameterMissing:
        print("RequiredParameterMissing")
    case kCMSampleBufferError_SampleIndexOutOfRange:
        print("SampleIndexOutOfRange")
    case kCMSampleBufferError_SampleTimingInfoInvalid:
        print("SampleTimingInfoInvalid")
    default:
        if status != 0 {
            print("Unknown status:", status)
        }
    }
}

func sampleBufferFromPixelBuffer(pixelBuffer: CVPixelBuffer, seconds: Double) -> CMSampleBuffer? {
    let scale = CMTimeScale(1_000_000_000)
    let time = CMTime(seconds: seconds, preferredTimescale: scale)
    var timingInfo: CMSampleTimingInfo = CMSampleTimingInfo(duration: CMTime.invalid, presentationTimeStamp: time, decodeTimeStamp: CMTime.invalid)
    var videoInfo: CMVideoFormatDescription? = nil
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
    var sampleBuffer: CMSampleBuffer? = nil
    let status = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoInfo!, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)
    handleCMSampleBufferError(status: status)
    guard let buffer = sampleBuffer else {
        print("Failed to create sample buffer")
        return nil
    }
    return buffer
}

struct ARJSON: Codable {
    var colorImage: Data?
    var depthImage: Data?
}

class ARDataProvider {
    let context = CIContext(options: nil)
    let arReceiver: ARReceiver = ARReceiver()
    let serverStreamer: ServerStreamer = ServerStreamer()
    
    static var instance = ARDataProvider()
    
    private init() {
        self.arReceiver.delegate = self
    }
    
    func start() {
        self.arReceiver.start()
    }
    
    func pause() {
        self.arReceiver.pause()
    }
    
    func cvPixelBufferToData(cvPixelBuffer: CVPixelBuffer) -> Data? {
        guard let sampleBuffer = sampleBufferFromPixelBuffer(pixelBuffer: cvPixelBuffer, seconds: 0) else { return nil }
        guard let capture: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let sourceImage = CIImage(cvImageBuffer: capture, options: nil)
        guard let cgImage = self.context.createCGImage(sourceImage, from: sourceImage.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        guard let data = image.jpegData(compressionQuality: 0) else { return nil }
        return data
    }
    
    func onNewARData(arFrame: ARFrame) {
        guard let depthImage: CVPixelBuffer = arFrame.sceneDepth?.depthMap else { return }
        let colorImage: CVPixelBuffer = arFrame.capturedImage
        guard let colorData = cvPixelBufferToData(cvPixelBuffer: colorImage) else { return }
        guard let depthData = cvPixelBufferToData(cvPixelBuffer: depthImage) else { return }
        let json = ARJSON(colorImage: colorData, depthImage: depthData)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(json)
        self.serverStreamer.streamData(data: data)
    }
    
    func onNewAudioData(sampleBuffer: CMSampleBuffer) {
        // https://stackoverflow.com/questions/63583179/can-you-play-audio-directly-from-a-cmsamplebuffer
    }
}
