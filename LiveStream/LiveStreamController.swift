//
//  LiveStreamPipeline.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit
import AVFoundation

class LiveStreamController: NSObject, LiveStreamProtocol {
    
    // constants and global state variables
    
    let framesPerSecond: Int32 = 30
    var isRecording = false
    var delegate: LiveStreamDelegate
    private var videoDimensions = CGSize(width: 0, height: 0)
    
    // lazy vars
    
    private lazy var session: AVCaptureSession = {
        let s = AVCaptureSession()
        s.sessionPreset = AVCaptureSessionPresetHigh
        return s
    }()
    
    private lazy var videoUrl: NSURL = {
        let u = GetRootURL().URLByAppendingPathComponent("video_\(GetDateAbbreviation()).mp4")
        return u
    }()
    
    private var _lsAssetWriter: LSAssetWriter?
    
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
    
    // constructor / destructor
    
    init(delegate: LiveStreamDelegate) {
        self.delegate = delegate
        print("Initialized controller with delegate.")
    }
    
    deinit {
        deinitialize()
    }
    
    // protocol methods
    
    func initializeWithPreviewLayer(previewView: UIView?) {
        addSessionInput(AVMediaTypeVideo)
        addSessionInput(AVMediaTypeAudio)
        
        if let view = previewView {
            addPreviewLayer(view)
        }
        
        session.startRunning()
        print("Session started running.")
        print("")
    }
    
    func startRecordingVideo(orientation: UIDeviceOrientation) {
        isRecording = true
        
        _lsAssetWriter = LSAssetWriter(url: videoUrl, orientation: orientation, videoDimensions: videoDimensions)
        
        // add outputs to start capturing the session
        addOutputs(orientation)
        
        print("")
        delegate.didBeginRecordingVideo(videoUrl)
    }
    
    func stopRecordingVideo() {
        isRecording = false
        
        // remove output to stop capturing the session
        _lsAssetWriter?.finishWritingWithCompletionHandler {
            print("LVAssetWriter finished writing.")
        }
        
        removeOutputs()
        
        print("")
        delegate.didFinishRecordingVideo()
    }
    
    func deinitialize() {
        if session.running {
            session.stopRunning()
        }
    }
    
    // helper methods
    
    private func addSessionInput(mediaType: String) {
        do {
            let device = AVCaptureDevice.defaultDeviceWithMediaType(mediaType)
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
                print("Added session input with type \(mediaType).")
            } else {
                print("Unable to add the input of type \(mediaType).")
            }
            
            // record video dimensions from video input
            
            if mediaType == AVMediaTypeVideo {
                if let description = device.activeFormat.formatDescription {
                    let dimensions = CMVideoFormatDescriptionGetDimensions(description)
                    videoDimensions = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
                }
            }
            
        } catch let e as NSError {
            print("Unable to access device for type \(mediaType).")
            printError(e)
        }
    }
    
    private func addPreviewLayer(view: UIView) {
        let captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        captureVideoPreviewLayer.frame = view.bounds
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        view.layer.addSublayer(captureVideoPreviewLayer)
        print("Initialized capture video preview layer.")
    }
    
    private func addOutputs(orientation: UIDeviceOrientation) {
        session.beginConfiguration()
        
        addVideoDataOutput(orientation)
        addAudioDataOutput()
        subscribeOutputsToQueue()
        print("Added data outputs.")
        
        session.commitConfiguration()
    }
    
    func subscribeOutputsToQueue() {
        let outputQueue = dispatch_queue_create("outputQueue", DISPATCH_QUEUE_SERIAL)
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
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
        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)
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
    
    // methods when finishing recording
    
    private func removeOutputs() {
        session.beginConfiguration()
        
        for output in session.outputs as! [AVCaptureOutput] {
            session.removeOutput(output)
        }
        print("Capture outputs removed from session.")
        
        session.commitConfiguration()
    }
}

extension LiveStreamController: AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        // initial state checks
        
        if !isRecording {
            print("Not recording. Skipping sample buffer.")
            return
        }
        
        if !CMSampleBufferDataIsReady(sampleBuffer) {
            print("Sample buffer is not ready. Skipping sample buffer.")
            return;
        }
        
        guard let assetWriter = _lsAssetWriter else {
            print("Could not locate asset writer.")
            return
        }
        
        // shift video timeline to begin at first buffer's timestamp
        
        objc_sync_enter(assetWriter)
        
        if assetWriter.status != .Writing {
            assetWriter.startWriting()
            let lastSessionTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSessionAtSourceTime(lastSessionTime)
        }
        
        objc_sync_exit(assetWriter)
        
        // check for a bad status and exit if found
        if assetWriter.status.rawValue > AVAssetWriterStatus.Writing.rawValue {
            print("Writer status is: \(assetWriter.status.rawValue).")
            return
        }
        
        // encode buffer to appropriate asset writer input
        
        if captureOutput == videoOutput {
            _lsAssetWriter?.addVideoBuffer(sampleBuffer)
        } else if captureOutput == audioOutput {
            _lsAssetWriter?.addAudioBuffer(sampleBuffer)
        }
    }
}

// flip camera
/*
 - (IBAction)CameraToggleButtonPressed:(id)sender
 {
	if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1)		//Only do if device has multiple cameras
	{
 NSLog(@"Toggle camera");
 NSError *error;
 //AVCaptureDeviceInput *videoInput = [self videoInput];
 AVCaptureDeviceInput *NewVideoInput;
 AVCaptureDevicePosition position = [[VideoInputDevice device] position];
 if (position == AVCaptureDevicePositionBack)
 {
 NewVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self CameraWithPosition:AVCaptureDevicePositionFront] error:&error];
 }
 else if (position == AVCaptureDevicePositionFront)
 {
 NewVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self CameraWithPosition:AVCaptureDevicePositionBack] error:&error];
 }
 
 if (NewVideoInput != nil)
 {
 [CaptureSession beginConfiguration];		//We can now change the inputs and output configuration.  Use commitConfiguration to end
 [CaptureSession removeInput:VideoInputDevice];
 if ([CaptureSession canAddInput:NewVideoInput])
 {
 [CaptureSession addInput:NewVideoInput];
 VideoInputDevice = NewVideoInput;
 }
 else
 {
 [CaptureSession addInput:VideoInputDevice];
 }
 
 //Set the connection properties again
 [self CameraSetOutputProperties];
 
 
 [CaptureSession commitConfiguration];
 [NewVideoInput release];
 }
	}
 } */