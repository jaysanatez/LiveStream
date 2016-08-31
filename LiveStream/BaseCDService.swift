//
//  BaseCDService.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/31/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import CoreData

class BaseCDService {

    var coreDataStack: CoreDataStack!
    var context: NSManagedObjectContext!
    
    init(coreDataStack: CoreDataStack, context: NSManagedObjectContext) {
        self.coreDataStack = coreDataStack
        self.context = context
    }
    
    func save() {
        coreDataStack.saveContext(context)
    }
}