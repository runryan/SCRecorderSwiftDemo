//
//  ViewController.swift
//  TouchToRecord
//
//  Created by ryan on 2019/1/23.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit

class ViewController: UIViewController{

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let viewController = ViewCaptureViewController()
        present(viewController, animated: true, completion: nil)
    }
    
}

