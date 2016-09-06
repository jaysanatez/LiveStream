//
//  ViewController.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/13/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit
import AVFoundation

class RecordViewController: UIViewController {
    
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var overviewView: UIView!
    @IBOutlet weak var recordButtonView: UIView!
    
    @IBOutlet weak var exitButton: UIButton!
    @IBOutlet weak var durationLabel: UILabel!
    
    let overviewAlpha: CGFloat = 0.65
    var isRecording = false
    
    lazy var controller: LiveStreamController = {
        return LiveStreamController(delegate: self)
    }()
    
    var videoCdService: VideoCDService!
    var activeVideo: Video?
    
    var timeStart = NSDate()
    var timer = NSTimer()
    
    // UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overviewView.alpha = overviewAlpha
        durationLabel.hidden = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(orientationDidChange),
            name: UIDeviceOrientationDidChangeNotification, object: nil)
        
        controller.initializeWithPreviewLayer(cameraPreviewView)
        transformViewsForCurrentOrientation()
        
        timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(timerCallback), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        controller.deinitialize()
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
    
    @IBAction func exitButtonTapped() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func recordButtonTapped() {
        if isRecording {
            recordButtonView.hidden = true
            
            timer.invalidate()
            controller.stopRecordingVideo()
        } else {
            isRecording = true
            durationLabel.hidden = false
            
            controller.startRecordingVideo(UIDevice.currentDevice().orientation)
            
            timeStart = NSDate()
            NSRunLoop.currentRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
        }
        
        toggleOverview()
    }
    
    // notifications
    
    func orientationDidChange(notif: NSNotification) {
        transformViewsForCurrentOrientation()
    }
    
    // timer callback
    
    func timerCallback() {
        let ti = NSDate().timeIntervalSinceDate(timeStart)
        durationLabel.text = GetClockFormattedString(Int(ti))
    }
    
    // custom methods

    let orientationToAngles: [UIDeviceOrientation: Double] =
        [.LandscapeLeft: M_PI_2,
         .LandscapeRight: 3 * M_PI_2,
         .Portrait: 0,
         .PortraitUpsideDown: M_PI]
    
    private func transformViewsForCurrentOrientation() {
        let orientation = UIDevice.currentDevice().orientation
        
        guard let angle = orientationToAngles[orientation] else {
            // it is expected to get orientations not in the dictionary, so don't log error
            return
        }
        
        let transform = CGAffineTransformMakeRotation(CGFloat(angle))
        UIView.animateWithDuration(0.25) {
            self.exitButton.transform = transform
            self.durationLabel.transform = transform
        }
    }
    
    private func toggleOverview() {
        let newAlpha = overviewAlpha - overviewView.alpha
        UIView.animateWithDuration(0.15) {
            self.overviewView.alpha = newAlpha
        }
    }
    
    // inscribe image into 200x200 square
    private func scaleDownImage(image: UIImage) -> UIImage {
        let height = image.size.height
        let width = image.size.width
        
        if height <= 200 && width <= 200 {
            return image
        }
        
        let hwRatio = Double(height / width)
        var newHeight = 200.0
        var newWidth = 200.0
        
        // if height > width, make width smaller to match aspect ratio
        if hwRatio > 1 {
            newWidth = newHeight / hwRatio
        } else if hwRatio < 1 {
            newHeight = newWidth * hwRatio
        }
        
        print("Scaling down image")
        print("Old size: \(height) x \(width)")
        print("New size: \(newHeight) x \(newWidth)")
        
        let rect = CGRectMake(0.0, 0.0, CGFloat(newWidth), CGFloat(newHeight))
        UIGraphicsBeginImageContext(rect.size);
        
        image.drawInRect(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext();
        let imageData = UIImagePNGRepresentation(newImage)
        
        UIGraphicsEndImageContext();
        
        guard let data = imageData, let img = UIImage(data: data) else {
            print("Unable to scale down image.")
            return image
        }
        
        return img
    }
}

extension RecordViewController: LiveStreamDelegate {
    
    func didBeginRecordingVideo(videoUrl: NSURL) {
        let string = videoUrl.absoluteString
        let urlParts = string.componentsSeparatedByString("/")
        let fileName = urlParts.last!
        
        if let v = videoCdService.createNewVideo(fileName) {
            activeVideo = v
            print("Video was created with name \(fileName)")
        } else {
            print("Unable to create video with name \(fileName)")
        }
    }
    
    func didFinishRecordingVideo() {
        guard let video = activeVideo else {
            print("No active video exists.")
            return
        }
        
        let asset = AVAsset(URL: video.getAbsoluteURL())
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // set video duration
        let time = asset.duration
        video.durationSec = CMTimeGetSeconds(time)
        
        do {
            let newTime = CMTime(value: time.value / 2, timescale: time.timescale)
            let imageRef = try imageGenerator.copyCGImageAtTime(newTime, actualTime: nil)
            let image = scaleDownImage(UIImage(CGImage: imageRef))
            
            video.tileImageData = UIImagePNGRepresentation(image)
            video.save()
            print("Created thumbnail for video.")
        } catch let e as NSError {
            print("Unable to create thumbnail for video.")
            printError(e)
        }
    }
}