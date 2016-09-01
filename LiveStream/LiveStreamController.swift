//
//  LiveStreamPipeline.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit

class LiveStreamController: LiveStreamProtocol {

    var delegate: LiveStreamDelegate
    init(delegate: LiveStreamDelegate) {
        self.delegate = delegate
    }
    
    func initializePreviewLayer(view: UIView) {
        
    }
    
    func startRecording(directoryPath: NSURL) {
        
    }
    
    func stopRecording() {
        
    }
}