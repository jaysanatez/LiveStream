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
    
    // not lazy-loaded since configuration is dynamic
    
    private var videoDimensions = CGSize(width: 0, height: 0)
    private var _videoWriterInput: AVAssetWriterInput?
    private var _audioWriterInput: AVAssetWriterInput?
    
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
    
    private lazy var _assetWriter: AVAssetWriter? = {
        if NSFileManager.defaultManager().fileExistsAtPath(self.videoUrl.path!) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(self.videoUrl.path!)
            } catch let e as NSError {
                printError(e)
                print("Unable to delete existing .mp4 file.")
                return nil
            }
        }
        
        guard let a = try? AVAssetWriter(URL: self.videoUrl, fileType: AVFileTypeMPEG4) else {
            print("Unable to construct asset writer.")
            return nil
        }
        
        print("Asset writer configured properly.")
        return a
    }()
    
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
    
    private lazy var audioChannelLayout: AudioChannelLayout = {
        var a = AudioChannelLayout()
        memset(&a, 0, sizeof(AudioChannelLayout));
        a.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        return a
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
        
        // add outputs to start capturing the session
        addOutputs(orientation)
        
        print("")
        delegate.didBeginRecordingVideo(videoUrl)
    }
    
    func stopRecordingVideo() {
        isRecording = false
        
        // remove output to stop capturing the session
        finishWritingToAssetWriter()
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
        
        addAssetWriterInputs(orientation)
        subscribeInputsToQueue()
        print("Configured asset writer.")
        
        addVideoDataOutput(orientation)
        addAudioDataOutput()
        print("Added data outputs.")
        
        session.commitConfiguration()
    }
    
    private func addAssetWriterInputs(orientation: UIDeviceOrientation) {
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
    
    func subscribeInputsToQueue() {
        let outputQueue = dispatch_queue_create("outputQueue", DISPATCH_QUEUE_SERIAL)
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }
    
    private func addVideoWriterInput(outputSettings: [String: AnyObject]) {
        _videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
        _videoWriterInput?.expectsMediaDataInRealTime = true
        print("Initialized asset writer video input.")
        
        addWriterInput(_videoWriterInput)
    }
    
    private func addAudioWriterInput(outputSettings: [String: AnyObject]) {
        _audioWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: outputSettings)
        _audioWriterInput?.expectsMediaDataInRealTime = true
        print("Initialized asset writer audio input.")
        
        addWriterInput(_audioWriterInput)
    }
    
    private func addWriterInput(assetWriterInput: AVAssetWriterInput?) {
        guard let input = assetWriterInput else {
            print("Unable to initialize asset writer input.")
            return
        }
        
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        if assetWriter.canAddInput(input) {
            assetWriter.addInput(input)
            print("Asset writer audio input added to asset writer.")
        } else {
            print("Unable to add asset writer audio input.")
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
    
    private func finishWritingToAssetWriter() {
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        _videoWriterInput?.markAsFinished()
        _audioWriterInput?.markAsFinished()
        print("Writer inputs marked as finished.")
        
        assetWriter.finishWritingWithCompletionHandler {
            print("Video written to \(assetWriter.outputURL.path!)")
        }
    }
    
    private func removeOutputs() {
        session.beginConfiguration()
        
        for output in session.outputs as! [AVCaptureOutput] {
            session.removeOutput(output)
        }
        print("Capture outputs removed from session.")
        
        session.commitConfiguration()
    }
    
    // methods used in capture data output delegate
    
    private func appendDataBufferToWriterInput(sampleBuffer: CMSampleBuffer, assetWriterInput: AVAssetWriterInput?) {
        guard let writerInput = assetWriterInput else {
            print("Unable to locate audio writer input.")
            return
        }
        
        if !writerInput.readyForMoreMediaData {
            print("Asset writer is not ready for media data.")
            return
        }
        
        if !writerInput.appendSampleBuffer(sampleBuffer) {
            print("Unable to append sample buffer to writer input.")
        }
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
        
        guard let assetWriter = _assetWriter else {
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
            appendDataBufferToWriterInput(sampleBuffer, assetWriterInput: _videoWriterInput)
        } else if captureOutput == audioOutput {
            appendDataBufferToWriterInput(sampleBuffer, assetWriterInput: _audioWriterInput)
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