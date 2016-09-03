//
//  VideoCDService.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import CoreData

let videosEntity = "Video"
class VideoCDService: BaseCDService {
    
    func retrieveAllVideos() -> [Video] {
        let request = NSFetchRequest(entityName: videosEntity)
        
        do {
            return try context.executeFetchRequest(request) as! [Video]
        } catch let e as NSError {
            print("Unable to fetch Videos.")
            printError(e)
        }
        
        return []
    }
    
    func createNewVideo(path: String) -> Video? {
        let entity =  NSEntityDescription.entityForName(videosEntity, inManagedObjectContext:context)
        let obj = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: context) as? Video
        
        guard let video = obj else {
            print("Unable to create new video object.")
            return nil
        }
        
        video.path = path
        
        do {
            try context.save()
            return video
        } catch let e as NSError  {
            print("Unable to save video object.")
            printError(e)
        }
        
        return nil
    }
}