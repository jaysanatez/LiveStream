//
//  VideoDirectoryHelpers.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import Foundation

let videoDirName = "videos"

func ensureVideosDirectory() {
    let fileManager = NSFileManager.defaultManager()
    let url = GetRootURL()
    
    var isDir : ObjCBool = false
    if !fileManager.fileExistsAtPath(url.path!, isDirectory: &isDir) {
        print("Directory '\(videoDirName)' does not exist.")
        createDirectory(url, fileManager: fileManager)
    } else {
        if isDir {
            print("Directory '\(videoDirName)' already exists.")
        } else {
            createDirectory(url, fileManager: fileManager)
        }
    }
}

func createDirectory(url: NSURL, fileManager: NSFileManager) {
    do {
        try fileManager.createDirectoryAtURL(url, withIntermediateDirectories: false, attributes: nil)
        print("Created directory '\(videoDirName)'.")
    } catch let e as NSError {
        print("Unable to create directory '\(videoDirName)'.")
        printError(e)
    }
}

func GetRootURL() -> NSURL {
    let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
    return urls[0].URLByAppendingPathComponent(videoDirName, isDirectory: true)
}