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
    
    private lazy var _assetWriter: AVAssetWriter? = {
        let url = self.getVideoUrl()
        print("Asset writer configured to path: \(url.path!)")
        if NSFileManager.defaultManager().fileExistsAtPath(url.path!) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(url.path!)
            } catch {
                print("Unable to delete existing .mp4 file")
                return nil
            }
        }
        
        guard let assetWriter = try? AVAssetWriter(URL: url, fileType: AVFileTypeMPEG4) else {
            print("Unable to construct asset writer.")
            return nil
        }
        
        return assetWriter
    }()
    
    // constructor / destructor
    
    var delegate: LiveStreamDelegate
    init(delegate: LiveStreamDelegate) {
        self.delegate = delegate
    }
    
    deinit {
        if _session.running {
            _session.stopRunning()
        }
    }
    
    // protocol methods
    
    func initializeWithPreviewLayer(previewView: UIView?) {
        addSessionInput(AVMediaTypeVideo)
        // TODO: addSessionInput(AVMediaTypeAudio)
        
        if let view = previewView {
            addPreviewLayer(view)
        }
        
        _session.startRunning()
        delegate.didBeginRecordingVideo(getVideoUrl())
    }
    
    func startRecordingVideo(orientation: UIDeviceOrientation) {
        // add outputs to start capturing the session
        addOutputs(orientation)
    }
    
    func stopRecordingVideo() {
        // remove output to stop capturing the session
        removeOutputs()
        finishWritingToAssetWriter()
    }
    
    // helper methods
    
    private func addSessionInput(mediaType: String) {
        do {
            let device = AVCaptureDevice.defaultDeviceWithMediaType(mediaType)
            let input = try AVCaptureDeviceInput(device: device)
            
            if _session.canAddInput(input) {
                _session.addInput(input)
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
    }
    
    private func addOutputs(orientation: UIDeviceOrientation) {
        _session.beginConfiguration()
        
        addVideoDataOutput(orientation)
        addAudioDataOutput()
        
        _session.commitConfiguration()
    }
    
    private func addVideoDataOutput(orientation: UIDeviceOrientation) {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
        output.alwaysDiscardsLateVideoFrames = true
        
        let outputQueue = dispatch_queue_create("videoDataOutputQueue", DISPATCH_QUEUE_SERIAL)
        output.setSampleBufferDelegate(self, queue: outputQueue)
        
        if _session.canAddOutput(output) {
            _session.addOutput(output)
        } else {
            print("Unable to add video data output.")
        }
        
        let connection = output.connectionWithMediaType(AVMediaTypeVideo)
        if connection.supportsVideoOrientation {
            connection.videoOrientation = avcvFromUid(orientation)
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
    
    private func addAudioDataOutput() {
        // TODO: implement
    }
    
    private func removeOutputs() {
        _session.beginConfiguration()
        
        for output in _session.outputs as! [AVCaptureOutput] {
            _session.removeOutput(output)
        }
        
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
        guard let assetWriterInput = _videoWriterInput else {
            print("Unable to initialize asset writer input")
            return
        }
        
        let pixelBufferAttributesDictionary: [String: AnyObject] =
            [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
             kCVPixelBufferWidthKey as String: size.width,
             kCVPixelBufferHeightKey as String: size.height]
        _pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: pixelBufferAttributesDictionary)
        
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        if assetWriter.canAddInput(assetWriterInput) {
            assetWriter.addInput(assetWriterInput)
        }
    }
    
    private func addAudioWriterInput() {
        // TODO: implement
    }
    
    private func startWritingToAssetWriter() {
        guard let assetWriter = _assetWriter else {
            print("Unable to locate asset writer.")
            return
        }
        
        assetWriter.startWriting()
        assetWriter.startSessionAtSourceTime(kCMTimeZero)
        configuredAssetWriter = true
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
    
    private func getVideoUrl() -> NSURL {
        if let url = _videoUrl {
            return url
        }
        
        _videoUrl = getRootURL().URLByAppendingPathComponent("output_\(getDateAbbreviation()).mp4")
        return _videoUrl!
    }
}

extension LiveStreamController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Unable to get image buffer from sample buffer.")
            return
        }
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        if !configuredAssetWriter {
            let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
            let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
            configureAssetWriter(CGSizeMake(width, height))
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