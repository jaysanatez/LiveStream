//
//  Video.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import Foundation
import CoreData

class Video: NSManagedObject {

    func getAbsoluteURL() -> NSURL {
        return GetRootURL().URLByAppendingPathComponent(videoFileName!)
    }
    
    func save() {
        do {
            try self.managedObjectContext?.save()
        } catch let e as NSError {
            print("Unable to save video context.")
            printError(e)
        }
    }
}
