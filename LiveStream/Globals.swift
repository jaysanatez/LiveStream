//
//  Globals.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/14/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import Foundation

func printError(e: NSError) {
    print("ERROR: \(e.localizedDescription) - \(e.userInfo)")
}

func GetDateAbbreviation() -> String {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy.MM.dd_HH.mm.SSS"
    return formatter.stringFromDate(NSDate())
}