//
//  ViewController.swift
//  Capture
//
//  Created by dandj on 2019/2/27.
//  Copyright © 2019 com.dandj. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var actionBtn: UIButton!
    @IBOutlet weak var cameraBtn: UIButton!
    @IBOutlet weak var contentView: UIView!
    var player: AVPlayer?
    var playerView: UIView?
    
    private var captureManager: CapatureManager?
    private var capturing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureManager = CapatureManager(contentView: contentView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureManager?.startPreview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureManager?.endPreview()
    }

    @IBAction func didClickActionBtn(_ sender: UIButton) {
        if !capturing {
            capturing = true
            sender.setTitle("End", for: .normal)
            captureManager?.startCapture()
        }
        else {
            capturing = false
            sender.setTitle("Start", for: .normal)
            captureManager?.endCapture(completion: { (videoUrl) in
                if let _videoUrl = videoUrl {
                    print("录制完成:\(_videoUrl)")
                    self.playVideo(url: _videoUrl)
                }
                else {
                    print("录制失败")
                }
            })
        }
    }
    
    @IBAction func didClickCameraBtn(_ sender: UIButton) {
        captureManager?.switchCamera()
        let currentTitle = sender.title(for: .normal)!
        sender.setTitle(currentTitle == "front" ? "back" : "front", for: .normal)
    }
}

extension ViewController {
    func playVideo(url: URL) {
        let asset = AVAsset(url: url)
        let playerView = UIView(frame: contentView.bounds)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = contentView.bounds
        playerView.layer.addSublayer(playerLayer)
        view.addSubview(playerView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(videoPlayFinish(nofi:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        player?.play()
        self.playerView = playerView
        
        let closeBtn = UIButton(frame: CGRect(x: 0, y: 20, width: 60.0, height: 30.0))
        closeBtn.setTitle("Close", for: .normal)
        closeBtn.backgroundColor = UIColor.gray
        closeBtn.setTitleColor(UIColor.white, for: .normal)
        closeBtn.addTarget(self, action: #selector(closePlayer), for: .touchUpInside)
        playerView.addSubview(closeBtn)
    }
    
    @objc func videoPlayFinish(nofi : Notification) {
        player?.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
        player?.play()
    }
    
    @objc func closePlayer() {
        player?.pause()
        UIView.animate(withDuration: 1.0, animations: {
            self.playerView?.alpha = 0.0
        }) { (complete) in
            if complete {
                self.player = nil
                self.playerView?.removeFromSuperview()
                self.playerView = nil
                self.captureManager?.startPreview()
            }
        }
    }
}
