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
}

extension HomeViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let video = videos[indexPath.row]
        playVideoFromURL(video.getAbsoluteURL())
    }
}

extension HomeViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellId, forIndexPath: indexPath) as! VideoCollectionViewCell
        let video = videos[indexPath.row]
        
        if let data = video.tileImageData {
            cell.tileImageView.image = UIImage(data: data)
        } else {
            cell.tileImageView.image = nil
        }
        
        if let duration = video.durationSec {
            cell.durationLabel.text = GetClockFormattedString(Int(duration))
        } else {
            cell.durationLabel.text = "--:--"
        }
        
        return cell
    }
}