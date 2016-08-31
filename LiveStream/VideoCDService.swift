//
//  VideoCDService.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import CoreData

let VIDEOS_ENTITY = "Video"
class VideoCDService: BaseCDService {
    
    func retrieveAllVideos() -> [Video] {
        let request = NSFetchRequest(entityName: VIDEOS_ENTITY)
        
        do {
            return try context.executeFetchRequest(request) as! [Video]
        } catch let e as NSError {
            print("Unable to fetch Videos.")
            printError(e)
        }
        
        return []
    }
}