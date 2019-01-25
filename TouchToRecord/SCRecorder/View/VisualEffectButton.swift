//
//  VisualEffectButton.swift
//  TouchToRecord
//
//  Created by Ryan on 2019/1/25.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit

class VisualEffectButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
    }
    
    func commonInit() {
        let visualView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        visualView.isUserInteractionEnabled = false
        addSubview(visualView)
        visualView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .clear
        if let imageView = imageView {
            bringSubviewToFront(imageView)
            imageView.isUserInteractionEnabled = false
        }
        if let titleLabel = titleLabel {
            titleLabel.isUserInteractionEnabled = false
            bringSubviewToFront(titleLabel)
        }
        self.isUserInteractionEnabled = true
        layer.cornerRadius = bounds.size.width / 2
        clipsToBounds = true
    }

}
