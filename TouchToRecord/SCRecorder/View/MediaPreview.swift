//
//  MediaPreview.swift
//  TouchToRecord
//
//  Created by ryan on 2019/1/24.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit

class MediaPreview: UIView {

    private var player: SCPlayer?
    private weak var playerView: SCVideoPlayerView?
    
    func previewImage(_ image: UIImage) {
        let imageView = UIImageView()
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        imageView.image = image
    }

    func setupPlayerAndPlayerView(withPlayerItem playerItem: AVPlayerItem) {
        if player == nil {
            let player = SCPlayer()
            self.player = player
            let playerView = SCVideoPlayerView(player: player)
            self.playerView = playerView
            playerView.playerLayer?.videoGravity = .resizeAspectFill
            addSubview(playerView)
            playerView.snp.makeConstraints { make in
                make.edges.equalTo(self)
            }
        }
        player?.loopEnabled = true
        player?.setItem(playerItem)
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        pause()
        self.playerView?.removeFromSuperview()
        player = nil
        removeFromSuperview()
    }
    
    func viewWillAppear() {
        play()
    }
    
    func viewWillDisappear() {
        pause()
    }
    
    deinit {
        pause()
        player = nil
    }
}
