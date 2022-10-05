//
//  AudioHelpers.swift
//  Ray
//
//  Created by Samuel Seng on 10/5/22.
//

import Foundation
import AVFoundation

class AudioCaptureData: Encodable {
    var audioData: Data
    init(audioData: Data) {
        self.audioData = audioData
    }
}

class AudioHelpers {
    static func printAudioFormat(sampleBuffer: CMSampleBuffer) {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            print("Could not get audio format description")
            return
        }
        guard let audioDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format) else {
            print("Could not get audio stream basic description")
            return
        }
        let numChannels = audioDescription.pointee.mChannelsPerFrame
        let audioFormat = audioDescription.pointee.mFormatID
        let bitsPerChannel = audioDescription.pointee.mBitsPerChannel
        if audioFormat == kAudioFormatLinearPCM && numChannels == 1 && bitsPerChannel == 16 {
            print("Audio Format: LinearPCM, 1 channel, 16 bits per channel")
        }
        else {
            print("Unhandled audio format: \(audioFormat), \(numChannels) channels, \(bitsPerChannel) bits per channel")
        }
    }

    static func getAudioData(sampleBuffer: CMSampleBuffer) -> Data {
        var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 0, mDataByteSize: 0, mData: nil))
        var blockBuffer: CMBlockBuffer?

        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)

        let audioBuffer = audioBufferList.mBuffers
        let data : Data = Data.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
        return data
    }
    
}

