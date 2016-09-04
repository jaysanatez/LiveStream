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
    
    var coreDataStack: CoreDataStack!
    lazy var videoCDService: VideoCDService = {
        return VideoCDService(coreDataStack: self.coreDataStack, context: self.coreDataStack.mainContext)
    }()
    
    var videos: [String] = []
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        videos = getVideosFromRoot() // videoCDService.retrieveAllVideos()
        collectionView.reloadData()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "recordSegue" {
            guard let recordVC = segue.destinationViewController as? RecordViewController else {
                print("Record segue is not of type RecordViewController")
                return
            }
            
            recordVC.videoCdService = videoCDService
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
    
    private func getVideosFromRoot() -> [String] {
        do {
            let path = getRootURL().path!
            return try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path)
        } catch let e as NSError {
            printError(e)
            return []
        }
    }
}

extension HomeViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        /* let video = videos[indexPath.row]
        guard let _ = video.path else {
            print("Null path in video object.")
            return
        } */
        
        let url = getRootURL().URLByAppendingPathComponent(videos[indexPath.row])
        playVideoFromURL(url)
    }
}

extension HomeViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellId, forIndexPath: indexPath)
        // TODO: populate cell content
        return cell
    }
}