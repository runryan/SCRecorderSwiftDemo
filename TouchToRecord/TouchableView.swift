//
//  TouchableView.swift
//  TouchToRecord
//
//  Created by ryan on 2019/1/23.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit

enum TouchAction {
    case tap
    case longPress
    case endLongPress
}

class TouchableView: UIView {
    
    var touchCallback: ((Bool) -> Void)?
    var touchActionCallback : ((TouchAction) -> Void)?
    
    var islongPressAction = false
    var isTouchEnded = true
    
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
    
    private func commonInit() {
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        addSubview(visualEffectView)
        visualEffectView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
    
    @objc private func tap() {
        touchActionCallback?(.tap)
    }
    
    @objc private func longPress() {
        touchActionCallback?(.longPress)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouchEnded = false
        islongPressAction = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.isTouchEnded == true {
                self?.islongPressAction = false
                self?.tap()
                return
            }
            self?.islongPressAction = true
            self?.longPress()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouchEnded = true
        if islongPressAction {
            touchActionCallback?(.endLongPress)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouchEnded = true
        if islongPressAction {
            touchActionCallback?(.endLongPress)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        clipsToBounds = true
        layer.cornerRadius = bounds.size.width / 2
    }
}
