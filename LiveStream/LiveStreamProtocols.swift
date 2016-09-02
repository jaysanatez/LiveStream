//
//  LiveStreamProtocols.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit

protocol LiveStreamProtocol {
    func initializePreviewLayer(view: UIView)
    func startRecording()
    func stopRecording()
}

protocol LiveStreamDelegate {
    func didBeginRecording(videoUrl: NSURL)
    func didFinishRecording(thumbnail: UIImage, videoDuration: Double)
}