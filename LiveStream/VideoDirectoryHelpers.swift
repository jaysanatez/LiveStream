//
//  VideoDirectoryHelpers.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import Foundation

let VIDEOS_DIRECTORY = "videos"

func ensureVideosDirectory() {
    let fileManager = NSFileManager.defaultManager()
    let url = getRootURL()
    
    var isDir : ObjCBool = false
    if !fileManager.fileExistsAtPath(url.path!, isDirectory: &isDir) {
        print("Directory '\(VIDEOS_DIRECTORY)' does not exist.")
        createDirectory(url, fileManager: fileManager)
    } else {
        if isDir {
            print("Directory '\(VIDEOS_DIRECTORY)' already exists.")
        } else {
            createDirectory(url, fileManager: fileManager)
        }
    }
}

func createDirectory(url: NSURL, fileManager: NSFileManager) {
    do {
        try fileManager.createDirectoryAtURL(url, withIntermediateDirectories: false, attributes: nil)
        print("Created directory '\(VIDEOS_DIRECTORY)'.")
    } catch let e as NSError {
        print("Unable to create directory '\(VIDEOS_DIRECTORY)'.")
        printError(e)
    }
}

func getRootURL() -> NSURL {
    let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
    return urls[0].URLByAppendingPathComponent(VIDEOS_DIRECTORY, isDirectory: true)
}