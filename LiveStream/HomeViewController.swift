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
    
    var videos: [Video] = []
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        videos = videoCDService.retrieveAllVideos()
        collectionView.reloadData()
    }
    
    /* private func playVideoFromURL(url: NSURL) {
        let player = AVPlayer(URL: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        self.presentViewController(playerViewController, animated: true) {
            if let validPlayer = playerViewController.player {
                validPlayer.play()
            }
        }
    } */
}

extension HomeViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // TODO: launch video
    }
}

extension HomeViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO: change to videos.count
        return 50
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellId, forIndexPath: indexPath)
        // TODO: populate cell content
        return cell
    }
}