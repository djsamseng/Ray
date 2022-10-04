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

extension simd_float4x4: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode([SIMD4<Float>].self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode([columns.0,columns.1, columns.2, columns.3])
    }
}

struct ARJSON: Codable {
    var colorImage: Data?
    var depthImage: Data?
    var cameraTranslation: simd_float4x4?
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
    
    func onNewARData(arFrame: ARFrame) {
        // let transform = arFrame.camera.transform
        // let position = transform.columns.3
        // Hold the iPhone in landscape mode
        // [right/left, up/down, back/forward] in directions +/- in meters
        // colums 0,1,2 are for camera rotation. See https://stackoverflow.com/questions/45437037/arkit-what-do-the-different-columns-in-transform-matrix-represent
        // print("Camera position:", position)
        guard let depthImage: CVPixelBuffer = arFrame.sceneDepth?.depthMap else { return }
        let colorImage: CVPixelBuffer = arFrame.capturedImage
        guard let colorData = ImageHelpers.cvPixelBufferToData(cvPixelBuffer: colorImage) else { return }
        guard let depthData = ImageHelpers.cvPixelBufferToData(cvPixelBuffer: depthImage) else { return }
        let json = ARJSON(colorImage: colorData, depthImage: depthData, cameraTranslation: arFrame.camera.transform)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(json)
        self.serverStreamer.streamData(data: data)
    }
    
    func onNewAudioData(sampleBuffer: CMSampleBuffer) {
        // https://stackoverflow.com/questions/63583179/can-you-play-audio-directly-from-a-cmsamplebuffer
    }
}
