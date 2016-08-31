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

    @IBOutlet weak var collectionView: UICollectionView!
    let cellId = "cellId"
    
    var urls: [String] = []
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        urls = getVideosFromRoot()
        collectionView.reloadData()
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

extension HomeViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("tapped \(indexPath.row)")
    }
}

extension HomeViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 50
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellId, forIndexPath: indexPath)
        return cell
    }
}


