//
//  TouchableView.swift
//  TouchToRecord
//
//  Created by ryan on 2019/1/23.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit

class TouchableView: UIView {
    
    var touchCallback: ((Bool) -> Void)?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchCallback?(true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchCallback?(false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchCallback?(false)
    }
    
}
