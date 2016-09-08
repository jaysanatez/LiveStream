//
//  LSAssetWriterFactory.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 9/8/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit
import AVFoundation

class LSAssetWriter: AVAssetWriter {
    
    private lazy var audioChannelLayout: AudioChannelLayout = {
        var a = AudioChannelLayout()
        memset(&a, 0, sizeof(AudioChannelLayout));
        a.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        return a
    }()
    
    private var _videoWriterInput: AVAssetWriterInput?
    private var _audioWriterInput: AVAssetWriterInput?
    
    init?(url: NSURL, orientation: UIDeviceOrientation, videoDimensions: CGSize) {
        guard let path = url.path else {
            print("Path of video url is empty. Aborting LSAssetWriter construction.")
            return nil
        }
        
        if NSFileManager.defaultManager().fileExistsAtPath(path) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch let e as NSError {
                printError(e)
                print("Unable to delete existing .mp4 file. Aborting LSAssetWriter construction.")
                return nil
            }
        }
        
        do {
            try super.init(URL: url, fileType: AVFileTypeMPEG4)
        } catch let e as NSError {
            print("Unable to init AVAssetWriter.")
            printError(e)
        }
        print("LSAssetWriter configured.")
        
        addAssetWriterInputs(orientation, videoDimensions: videoDimensions)
    }
    
    private func addAssetWriterInputs(orientation: UIDeviceOrientation, videoDimensions: CGSize) {
        let isPortrait = orientation == .Portrait || orientation == .PortraitUpsideDown
        
        let videoOutputSettings: [String: AnyObject] =
            [AVVideoCodecKey: AVVideoCodecH264,
             AVVideoWidthKey: isPortrait ? videoDimensions.height : videoDimensions.width,
             AVVideoHeightKey: isPortrait ? videoDimensions.width : videoDimensions.height]
        
        let audioOutputSettings: [String: AnyObject] =
            [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
             AVNumberOfChannelsKey: 1,
             AVSampleRateKey: 44100.0,
             AVChannelLayoutKey: NSData(bytes: &audioChannelLayout,
                length: sizeof(AudioChannelLayout))]
        
        addVideoWriterInput(videoOutputSettings)
        addAudioWriterInput(audioOutputSettings)
    }
    
    private func addVideoWriterInput(outputSettings: [String: AnyObject]) {
        let vwi = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
        vwi.expectsMediaDataInRealTime = true
        print("Initialized asset writer video input.")
        
        _videoWriterInput = vwi
        addWriterInput(vwi)
    }
    
    private func addAudioWriterInput(outputSettings: [String: AnyObject]) {
        let awi = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: outputSettings)
        awi.expectsMediaDataInRealTime = true
        print("Initialized asset writer audio input.")
        
        _audioWriterInput = awi
        addWriterInput(awi)
    }
    
    private func addWriterInput(assetWriterInput: AVAssetWriterInput) {
        if canAddInput(assetWriterInput) {
            addInput(assetWriterInput)
            print("Asset writer audio input added to asset writer.")
        } else {
            print("Unable to add asset writer audio input.")
        }
    }
    
    private func appendDataBufferToWriterInput(sampleBuffer: CMSampleBuffer, assetWriterInput: AVAssetWriterInput?) {
        guard let writerInput = assetWriterInput else {
            print("Unable to locate audio writer input.")
            return
        }
        
        if !writerInput.readyForMoreMediaData {
            return
        }
        
        if !writerInput.appendSampleBuffer(sampleBuffer) {
            print("Unable to append sample buffer to writer input.")
        }
    }
    
    // public methods
    
    override func finishWritingWithCompletionHandler(handler: () -> Void) {
        _videoWriterInput?.markAsFinished()
        _audioWriterInput?.markAsFinished()
        print("Writer inputs marked as finished.")
        
        super.finishWritingWithCompletionHandler {
            handler()
        }
    }
    
    func addVideoBuffer(sampleBuffer: CMSampleBuffer) {
        appendDataBufferToWriterInput(sampleBuffer, assetWriterInput: _videoWriterInput)
    }
    
    func addAudioBuffer(sampleBuffer: CMSampleBuffer) {
        appendDataBufferToWriterInput(sampleBuffer, assetWriterInput: _audioWriterInput)
    }
}
