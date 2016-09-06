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
    
    let framesPerSecond: Int32 = 30
    var isRecording = false
    
    private var _videoWriterInput: AVAssetWriterInput?
    private var _audioWriterInput: AVAssetWriterInput?
    
    private var _videoUrl: NSURL?
    
    // lazy vars
    
    private lazy var _session: AVCaptureSession = {
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
            } catch {
                print("Unable to delete existing .mp4 file.")
                return nil
            }
        }
        
        guard let a = try? AVAssetWriter(URL: self.videoUrl, fileType: AVFileTypeQuickTimeMovie) else {
            print("Unable to construct asset writer.")
            return nil
        }
        
        print("Asset writer configured properly.")
        print("Asset writer status: \(a.status)") // TODO: remove
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
    
    // constructor / destructor
    
    var delegate: LiveStreamDelegate
    init(delegate: LiveStreamDelegate) {
        self.delegate = delegate
        print("Initialized controller with delegate.")
    }
    
    deinit {
        if _session.running {
            _session.stopRunning()
            print("Session stopped running.")
        }
    }
    
    // protocol methods
    
    func initializeWithPreviewLayer(previewView: UIView?) {
        addSessionInput(AVMediaTypeVideo)
        addSessionInput(AVMediaTypeAudio)
        
        if let view = previewView {
            addPreviewLayer(view)
        }
        
        _session.startRunning()
        print("Session started running.")
        print("")
    }
    
    func startRecordingVideo(orientation: UIDeviceOrientation) {
        isRecording = true
        
        // add outputs to start capturing the session
        addOutputs(orientation)
        delegate.didBeginRecordingVideo(videoUrl)
        print("")
    }
    
    func stopRecordingVideo() {
        isRecording = false
        
        // remove output to stop capturing the session
        finishWritingToAssetWriter()
        removeOutputs()
        delegate.didFinishRecordingVideo()
    }
    
    // helper methods
    
    private func addSessionInput(mediaType: String) {
        do {
            let device = AVCaptureDevice.defaultDeviceWithMediaType(mediaType)
            let input = try AVCaptureDeviceInput(device: device)
            
            if _session.canAddInput(input) {
                _session.addInput(input)
                print("Added session input with type \(mediaType).")
            } else {
                print("Unable to add the input of type \(mediaType).")
            }
        } catch let e as NSError {
            print("Unable to access device for type \(mediaType).")
            printError(e)
        }
    }
    
    private func addPreviewLayer(view: UIView) {
        let captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: _session)
        captureVideoPreviewLayer.frame = view.bounds
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        view.layer.addSublayer(captureVideoPreviewLayer)
        print("Initialized capture video preview layer.")
    }
    
    private func addOutputs(orientation: UIDeviceOrientation) {
        _session.beginConfiguration()
        
        addAssetWriterInputs(CGSizeMake(1080.0, 1920.0))
        print("Asset writer status: \(_assetWriter!.status)") // TODO: remove
        print("Configured asset writer.")
        
        addVideoDataOutput(orientation)
        addAudioDataOutput()
        print("Added data outputs.")
        
        _session.commitConfiguration()
    }
    
    private func addAssetWriterInputs(size: CGSize) {
        let videoCompProps: [String: AnyObject] =
            [AVVideoAverageBitRateKey: 128.0 * 1024.0]
        
        let videoOutputSettings: [String: AnyObject] =
            [AVVideoCodecKey: AVVideoCodecH264,
             AVVideoWidthKey: size.width,
             AVVideoHeightKey: size.height,
             AVVideoCompressionPropertiesKey: videoCompProps]
        
        addVideoWriterInput(videoOutputSettings, size: size)
        
        var acl = AudioChannelLayout()
        memset(&acl, 0, sizeof(AudioChannelLayout));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        
        let audioOutputSettings: [String: AnyObject] =
            [AVFormatIDKey: Int(kAudioFormatAppleLossless),
             AVNumberOfChannelsKey: 1,
             AVSampleRateKey: 44100.0,
             AVEncoderBitDepthHintKey: 16,
             AVChannelLayoutKey: NSData(bytes: &acl, length: sizeof(AudioChannelLayout)) ]
        
        addAudioWriterInput(audioOutputSettings)
    }
    
    private func addVideoWriterInput(outputSettings: [String: AnyObject], size: CGSize) {
        _videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
        _videoWriterInput?.expectsMediaDataInRealTime = true
        guard let assetWriterInput = _videoWriterInput else {
            print("Unable to initialize asset writer input.")
            return
        }
        print("Initialized asset writer video input.")
        
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        if assetWriter.canAddInput(assetWriterInput) {
            assetWriter.addInput(assetWriterInput)
            print("Asset writer status: \(assetWriter.status)") // TODO: remove
            print("Asset writer input added to asset writer.")
        } else {
            print("Unable to add asset writer video input.")
        }
    }
    
    private func addAudioWriterInput(outputSettings: [String: AnyObject]) {
        _audioWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: outputSettings)
        _audioWriterInput?.expectsMediaDataInRealTime = true
        guard let assetWriterInput = _audioWriterInput else {
            print("Unable to initialize asset writer audio input.")
            return
        }
        print("Initialized asset writer audio input.")
        
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        if assetWriter.canAddInput(assetWriterInput) {
            assetWriter.addInput(assetWriterInput)
            print("Asset writer status: \(assetWriter.status)") // TODO: remove
            print("Asset writer audio input added to asset writer.")
        } else {
            print("Unable to add asset writer audio input.")
        }
    }
    
    private func addVideoDataOutput(orientation: UIDeviceOrientation) {
        if _session.canAddOutput(videoOutput) {
            _session.addOutput(videoOutput)
            print("Added session video data output.")
        } else {
            print("Unable to add video data output.")
        }
        
        let connection = videoOutput.connectionWithMediaType(AVMediaTypeVideo)
        if connection.supportsVideoOrientation {
            connection.videoOrientation = avcvFromUid(orientation)
            print("Set video orientation to \(orientation)")
        }
        
        let outputQueue = dispatch_queue_create("videoOutputQueue", DISPATCH_QUEUE_CONCURRENT)
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
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
    
    private func addAudioDataOutput() {
        if _session.canAddOutput(audioOutput) {
            _session.addOutput(audioOutput)
            print("Added session audio data output.")
        } else {
            print("Unable to add audio data output.")
        }
        
        let outputQueue = dispatch_queue_create("audioOutputQueue", DISPATCH_QUEUE_CONCURRENT)
        audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }
    
    private func finishWritingToAssetWriter() {
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        _videoWriterInput?.markAsFinished()
        _audioWriterInput?.markAsFinished()
        
        assetWriter.finishWritingWithCompletionHandler {
            print("Video written to \(assetWriter.outputURL.path!)")
        }
    }
    
    private func removeOutputs() {
        _session.beginConfiguration()
        
        for output in _session.outputs as! [AVCaptureOutput] {
            _session.removeOutput(output)
        }
        print("Capture outputs removed from session.")
        
        _session.commitConfiguration()
    }
    
    private func encodeVideoDataBuffer(sampleBuffer: CMSampleBuffer) {
        guard let videoWriterInput = _videoWriterInput else {
            print("Unable to locate video writer input")
            return
        }
        
        if !videoWriterInput.appendSampleBuffer(sampleBuffer) {
            print("Unable to appen sample buffer to video writer input")
        }
    }
    
    private func encodeAudioDataBuffer(sampleBuffer: CMSampleBuffer) {
        guard let audioWriterInput = _audioWriterInput else {
            print("Unable to locate audio writer input.")
            return
        }
        
        if !audioWriterInput.appendSampleBuffer(sampleBuffer) {
            print("Unable to append sample buffer to audio writer input.")
        }
    }
}

extension LiveStreamController: AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
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
        
        print("Asset writer status: \(assetWriter.status)") // TODO: remove
        let lastSessionTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if assetWriter.status != .Writing {
            assetWriter.startWriting()
            assetWriter.startSessionAtSourceTime(lastSessionTime)
        }
        
        if assetWriter.status.rawValue > AVAssetWriterStatus.Writing.rawValue {
            print("Writer status is: \(assetWriter.status.rawValue).")
            return
        }
        
        if captureOutput == videoOutput {
            encodeVideoDataBuffer(sampleBuffer)
        } else if captureOutput == audioOutput {
            encodeAudioDataBuffer(sampleBuffer)
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