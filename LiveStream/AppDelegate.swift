//
//  AppDelegate.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/13/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let coreDataStack = CoreDataStack()

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        ensureVideosDirectory()
        
        guard window != nil else {
            print("Unable to locate window.")
            return true
        }
        
        let navCtlr = window!.rootViewController as? UINavigationController
        guard navCtlr != nil else {
            print("Unable to locate UINavigationController.")
            return true
        }
        
        let vcs = navCtlr?.viewControllers
        guard vcs != nil else {
            print("Unable to locate child UIViewControllers.")
            return true
        }
        
        guard vcs!.count > 0 else {
            print("No child UIViewControllers found.")
            return true
        }
        
        let homeVC = vcs![0] as? HomeViewController
        guard homeVC != nil else {
            print("Unable to locate HomeViewController.")
            return true
        }
        
        homeVC!.coreDataStack = coreDataStack
        
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        coreDataStack.saveMainContext()
    }
}