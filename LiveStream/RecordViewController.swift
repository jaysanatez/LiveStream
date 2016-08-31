//
//  ViewController.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/13/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit
import AVFoundation

enum RecordingState {
    case NOT_STARTED
    case RECORDING
    case COMPLETED
}

class RecordViewController: UIViewController {
    
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var overviewView: UIView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var recordButtonView: UIView!
    
    let OVERVIEW_ALPHA: CGFloat = 0.65
    private var recordingState: RecordingState = .NOT_STARTED
    
    // UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overviewView.alpha = OVERVIEW_ALPHA
        showInitialControls(true)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(orientationDidChange),
            name: UIDeviceOrientationDidChangeNotification, object: nil)
        
        initializeAVCaptureSession()
        transformViewsForCurrentOrientation()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if _session.running {
            _session.stopRunning()
        }
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return [.Portrait, .PortraitUpsideDown]
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // IBActions
    
    @IBAction func cancelButtonTapped() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func finishRecordingTapped() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func recordButtonTapped() {
        switch recordingState
        {
        case .NOT_STARTED:
            startRecording()
        case .RECORDING:
            finishRecording()
        case .COMPLETED:
            break // not reached
        }
        
        toggleOverview()
    }
    
    // notifications
    
    func orientationDidChange(notif: NSNotification) {
        transformViewsForCurrentOrientation()
    }
    
    // custom methods
    
    private func showInitialControls(show: Bool) {
        cancelButton.hidden = !show
        finishButton.hidden = show
    }

    let orientationToAngles: [UIDeviceOrientation: Double] =
        [.LandscapeLeft: M_PI_2,
         .LandscapeRight: 3 * M_PI_2,
         .Portrait: 0,
         .PortraitUpsideDown: M_PI]
    
    private func transformViewsForCurrentOrientation() {
        let orientation = UIDevice.currentDevice().orientation
        
        guard let angle = orientationToAngles[orientation] else {
            return
        }
        
        let transform = CGAffineTransformMakeRotation(CGFloat(angle))
        UIView.animateWithDuration(0.25) {
            self.cancelButton.transform = transform
            self.finishButton.transform = transform
            self.infoLabel.transform = transform
        }
    }
    
    private func toggleOverview() {
        let newAlpha = OVERVIEW_ALPHA - overviewView.alpha
        UIView.animateWithDuration(0.15) {
            self.overviewView.alpha = newAlpha
        }
    }
    
    // recording state
    
    private func startRecording() {
        recordingState = .RECORDING
        
        // add output to start capturing the session
        addOutputs()
    }
    
    private func finishRecording() {
        recordingState = .COMPLETED
        
        showInitialControls(false)
        infoLabel.text = "Done! Return home to rewatch your video."
        recordButtonView.hidden = true
        
        // remove output to stop capturing the session
        removeOutputs()
        finishWritingToAssetWriter()
    }
    
    // ****************************************************************************
    //
    //  video methods - everything below this will eventually get scoped out to
    //  the library
    //
    // ****************************************************************************
    
    let FRAMES_PER_SECOND: Int32 = 30
    var frameCount: Int64 = 0
    
    private lazy var _session: AVCaptureSession = {
        let s = AVCaptureSession()
        s.sessionPreset = AVCaptureSessionPresetHigh
        return s
    }()
    
    var configuredAssetWriter = false
    private lazy var _assetWriter: AVAssetWriter? = {
        let url = getRootURL().URLByAppendingPathComponent("output_\(getDateAbbreviation()).mp4")
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
    
    private var _videoWriterInput: AVAssetWriterInput?
    private var _pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var _audioWriterInput: AVAssetWriterInput?
    
    private func initializeAVCaptureSession() {
        addPreviewLayer()
        addSessionInput(AVMediaTypeVideo)
        // TODO: add back in - addSessionInput(AVMediaTypeAudio)
        
        _session.startRunning()
    }
    
    private func addPreviewLayer() {
        let captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: _session)
        captureVideoPreviewLayer.frame = cameraPreviewView.bounds
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        cameraPreviewView.layer.addSublayer(captureVideoPreviewLayer)
    }
    
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
    
    private func addOutputs() {
        _session.beginConfiguration()
        
        addVideoDataOutput()
        addAudioDataOutput()
        
        _session.commitConfiguration()
    }
    
    private func addVideoDataOutput() {
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
            connection.videoOrientation = avcvFromUid(UIDevice.currentDevice().orientation)
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
}

extension RecordViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
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
        
        let time = CMTimeMake(frameCount, FRAMES_PER_SECOND)
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
 }
 */