//
//  HomeViewController.swift
//  LiveStream
//
//  Created by Jacob Sanchez on 8/14/16.
//  Copyright © 2016 jacob.sanchez. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class HomeViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    var urls: [String] = []
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        urls = getVideosFromRoot()
        tableView.reloadData()
    }
    
    private func exploreDirectory() {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        
        for url in urls {
            do {
                let contents =  try NSFileManager.defaultManager().contentsOfDirectoryAtPath(url.path!)
                
                print("printing contents of: \(url.path!)")
                for obj in contents {
                    print(obj)
                }
            } catch let e as NSError {
                printError(e)
            }
        }
    }
    
    private func getVideosFromRoot() -> [String] {
        do {
            let path = getRootURL().path!
            return try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path)
        } catch let e as NSError {
            printError(e)
            return []
        }
    }
    
    private func playVideoFromURL(url: NSURL) {
        let player = AVPlayer(URL: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        self.presentViewController(playerViewController, animated: true) {
            if let validPlayer = playerViewController.player {
                validPlayer.play()
            }
        }
    }
}

extension HomeViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return urls.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = urls[indexPath.row]
        return cell
    }
}

extension HomeViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let url = getRootURL().URLByAppendingPathComponent(urls[indexPath.row])
        playVideoFromURL(url)
    }
}
