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
    
    var isRecording = false
    var delegate: LiveStreamDelegate
    // lazy vars
    
    private lazy var session: LSCaptureSession = {
        return LSCaptureSession()
    }()
    
    private lazy var videoUrl: NSURL = {
        let u = GetRootURL().URLByAppendingPathComponent("video_\(GetDateAbbreviation()).mp4")
        return u
    }()
    
    private var _lsAssetWriter: LSAssetWriter?
    
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
        if let view = previewView {
            addPreviewLayer(view)
        }
        
        session.startRunning()
        print("Session started running.")
        print("")
    }
    
    func startRecordingVideo(orientation: UIDeviceOrientation) {
        isRecording = true
        
        let videoDimensions = session.getVideoDimensions()
        _lsAssetWriter = LSAssetWriter(url: videoUrl, orientation: orientation, videoDimensions: videoDimensions)
        
        // add outputs to start capturing the session
        session.addOutputs(orientation)
        session.subscribeOutputsToQueue(self, delegateAudio: self)
        
        print("")
        delegate.didBeginRecordingVideo(videoUrl)
    }
    
    func stopRecordingVideo() {
        isRecording = false
        
        // remove output to stop capturing the session
        _lsAssetWriter?.finishWritingWithCompletionHandler {
            print("LVAssetWriter finished writing.")
        }
        
        session.removeOutputs()
        
        print("")
        delegate.didFinishRecordingVideo()
    }
    
    func deinitialize() {
        if session.running {
            session.stopRunning()
        }
    }
    
    // helper methods
    
    private func addPreviewLayer(view: UIView) {
        let captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        captureVideoPreviewLayer.frame = view.bounds
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        view.layer.addSublayer(captureVideoPreviewLayer)
        print("Initialized capture video preview layer.")
    }
}

extension LiveStreamController: AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        // initial state checks
        
        if !isRecording {
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
        
        if session.isVideoOutput(captureOutput) {
            _lsAssetWriter?.addVideoBuffer(sampleBuffer)
        } else if session.isAudioOutput(captureOutput) {
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