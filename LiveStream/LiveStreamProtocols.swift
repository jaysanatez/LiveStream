//
//  LiveStreamProtocols.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit

protocol LiveStreamProtocol {
    func initializeWithPreviewLayer(view: UIView?)
    func startRecordingVideo(orientation: UIDeviceOrientation)
    func stopRecordingVideo()
}

protocol LiveStreamDelegate {
    func didBeginRecordingVideo(videoUrl: NSURL)
    func didFinishRecordingVideo(thumbnail: UIImage, videoDuration: Double)
}