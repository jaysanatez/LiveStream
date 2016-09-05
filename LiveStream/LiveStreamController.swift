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
    
    var configuredAssetWriter = false
    
    let framesPerSecond: Int32 = 30
    var frameCount: Int64 = 0
    
    private var _pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
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
        let url = GetRootURL().URLByAppendingPathComponent("video_\(GetDateAbbreviation()).mp4")
        return url
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
        
        guard let assetWriter = try? AVAssetWriter(URL: self.videoUrl, fileType: AVFileTypeMPEG4) else {
            print("Unable to construct asset writer.")
            return nil
        }
        
        print("Asset writer configured properly.")
        return assetWriter
    }()
    
    private lazy var videoOutput: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
        output.alwaysDiscardsLateVideoFrames = true
        return output
    }()
    
    private lazy var audioOutput: AVCaptureAudioDataOutput = {
        let output = AVCaptureAudioDataOutput()
        return output
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
    }
    
    func startRecordingVideo(orientation: UIDeviceOrientation) {
        // add outputs to start capturing the session
        addOutputs(orientation)
        delegate.didBeginRecordingVideo(videoUrl)
    }
    
    func stopRecordingVideo() {
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
        
        addVideoDataOutput(orientation)
        addAudioDataOutput()
        print("Added data outputs.")
        
        _session.commitConfiguration()
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
        
        let outputQueue = dispatch_queue_create("videoOutputQueue", DISPATCH_QUEUE_SERIAL)
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
        
        let outputQueue = dispatch_queue_create("audioOutputQueue", DISPATCH_QUEUE_SERIAL)
        audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }
    
    private func removeOutputs() {
        _session.beginConfiguration()
        
        for output in _session.outputs as! [AVCaptureOutput] {
            _session.removeOutput(output)
        }
        print("Capture outputs removed from session.")
        
        _session.commitConfiguration()
    }
    
    private func configureAssetWriter(size: CGSize) {
        guard let assetWriter = _assetWriter else {
            print("Unable to initialize asset writer.")
            return
        }
        
        let outputSettings: [String: AnyObject] =
            [AVVideoCodecKey: AVVideoCodecH264,
             AVVideoWidthKey: size.width,
             AVVideoHeightKey: size.height]
        
        guard assetWriter.canApplyOutputSettings(outputSettings, forMediaType: AVMediaTypeVideo) else {
            print("Unable to apply the output settings.")
            return
        }
        
        addVideoWriterInput(outputSettings, size: size)
        addAudioWriterInput()
        
        startWritingToAssetWriter()
    }
    
    private func addVideoWriterInput(outputSettings: [String: AnyObject], size: CGSize) {
        _videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
        _videoWriterInput?.expectsMediaDataInRealTime = true
        guard let assetWriterInput = _videoWriterInput else {
            print("Unable to initialize asset writer input.")
            return
        }
        print("Initialized asset writer input.")
        
        let pixelBufferAttributesDictionary: [String: AnyObject] =
            [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
             kCVPixelBufferWidthKey as String: size.width,
             kCVPixelBufferHeightKey as String: size.height]
        _pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: pixelBufferAttributesDictionary)
        print("Created pixel buffer adaptor.")
        
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        if assetWriter.canAddInput(assetWriterInput) {
            assetWriter.addInput(assetWriterInput)
            print("Asset writer input added to asset writer.")
        } else {
            print("Unable to add asset writer input.")
        }
    }
    
    private func addAudioWriterInput() {
        let outputSettings = audioOutput.recommendedAudioSettingsForAssetWriterWithOutputFileType(AVFileTypeMPEG4)
            as! [String: AnyObject]
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
            print("Asset writer audio input added to asset writer.")
        } else {
            print("Unable to add asset writer audio input.")
        }
    }
    
    private func startWritingToAssetWriter() {
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        assetWriter.startWriting()
        assetWriter.startSessionAtSourceTime(kCMTimeZero)
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
    
    private func encodeVideoDataBuffer(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Unable to get image buffer from sample buffer.")
            return
        }
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        // TODO: explore getting the height and width before capture sample buffer
        if !configuredAssetWriter {
            let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
            let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
            print("Configuring with size H: \(height) x W: \(width)")
            configureAssetWriter(CGSizeMake(width, height))
            configuredAssetWriter = true
            print("Asset writer configured.")
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0)
        
        guard let bufferAdaptor = _pixelBufferAdaptor else {
            print("Unable to locate pixel buffer adaptor.")
            return
        }
        
        let time = CMTimeMake(frameCount, framesPerSecond)
        if !bufferAdaptor.appendPixelBuffer(imageBuffer, withPresentationTime: time) {
            print("Unable to append image buffer to pixel buffer adapter.")
            return
        }
        
        frameCount += 1
    }
    
    private func encodeAudioDataBuffer(sampleBuffer: CMSampleBuffer) {
        // TODO: implement
    }
}

extension LiveStreamController: AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        if captureOutput == videoOutput {
            encodeVideoDataBuffer(sampleBuffer)
        } else if captureOutput == audioOutput && configuredAssetWriter {
            encodeAudioDataBuffer(sampleBuffer)
        }
        
        // if the first buffer is audio, don't append it since we need the
        // dimensions of the frame to initialize the asset and that can't
        // happen until we receive a sample buffer from the video output
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