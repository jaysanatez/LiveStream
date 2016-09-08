//
//  LSCaptureSession.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 9/8/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit
import AVFoundation

class LSCaptureSession: AVCaptureSession {
    
    private lazy var videoOutput: AVCaptureVideoDataOutput = {
        let o = AVCaptureVideoDataOutput()
        o.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
        o.alwaysDiscardsLateVideoFrames = false
        return o
    }()
    
    private lazy var audioOutput: AVCaptureAudioDataOutput = {
        let o = AVCaptureAudioDataOutput()
        return o
    }()
    
    // init
    
    override init() {
        super.init()
        sessionPreset = AVCaptureSessionPresetHigh
    }
    
    // public methods
    
    func addInputs() {
        addSessionInput(AVMediaTypeAudio)
        addSessionInput(AVMediaTypeVideo)
    }
    
    func addOutputs(orientation: UIDeviceOrientation) {
        beginConfiguration()
        
        addVideoDataOutput(orientation)
        addAudioDataOutput()
        print("Added data outputs.")
        
        commitConfiguration()
    }
    
    func subscribeOutputsToQueue(delegateVideo: AVCaptureVideoDataOutputSampleBufferDelegate,
                                 delegateAudio: AVCaptureAudioDataOutputSampleBufferDelegate) {
        let outputQueue = dispatch_queue_create("outputQueue", DISPATCH_QUEUE_SERIAL)
        videoOutput.setSampleBufferDelegate(delegateVideo, queue: outputQueue)
        audioOutput.setSampleBufferDelegate(delegateAudio, queue: outputQueue)
    }
    
    func removeOutputs() {
        beginConfiguration()
        
        for output in outputs as! [AVCaptureOutput] {
            removeOutput(output)
        }
        print("Capture outputs removed from session.")
        
        commitConfiguration()
    }
    
    func isVideoOutput(output: AVCaptureOutput) -> Bool {
        return output == videoOutput
    }
    
    func isAudioOutput(output: AVCaptureOutput) -> Bool {
        return output == audioOutput
    }
    
    func getVideoDimensions() -> CGSize {
        let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        if let description = device.activeFormat.formatDescription {
            let dimensions = CMVideoFormatDescriptionGetDimensions(description)
            let videoDimensions = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
            return videoDimensions
        }
        
        return CGSizeMake(0, 0)
    }
    
    // private helpers
    
    private func addSessionInput(mediaType: String) {
        let device = AVCaptureDevice.defaultDeviceWithMediaType(mediaType)
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if canAddInput(input) {
                addInput(input)
                print("Added session input with type \(mediaType).")
            } else {
                print("Unable to add the input of type \(mediaType).")
            }
        } catch let e as NSError {
            print("Unable to access device for type \(mediaType).")
            printError(e)
        }
    }

    private func addVideoDataOutput(orientation: UIDeviceOrientation) {
        addCaptureOutput(videoOutput)
        
        let connection = videoOutput.connectionWithMediaType(AVMediaTypeVideo)
        if connection.supportsVideoOrientation {
            connection.videoOrientation = avcvFromUid(orientation)
            print("Set video orientation to \(orientation)")
        }
    }
    
    private func addAudioDataOutput() {
        addCaptureOutput(audioOutput)
    }
    
    private func addCaptureOutput(captureOutput: AVCaptureOutput) {
        if canAddOutput(captureOutput) {
            addOutput(captureOutput)
            print("Added capture output to session.")
        } else {
            print("Unable to add capture output to session.")
        }
    }
    
    private func avcvFromUid(orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .PortraitUpsideDown:
            return .PortraitUpsideDown
        case .LandscapeLeft:
            return .LandscapeRight
        case .LandscapeRight:
            return .LandscapeLeft
        default:
            return .Portrait
        }
    }
}
