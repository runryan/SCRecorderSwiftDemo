//
//  ViewController.swift
//  TouchToRecord
//
//  Created by ryan on 2019/1/23.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit

class ViewController: UIViewController{
    
    private var captureViewController: CaptureViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("ViewController Touch Begin ... ")
        if captureViewController == nil {
            let viewController = CaptureViewController()
            viewController.didRecordVideo = { [weak self] in
                self?.dismiss(animated: true, completion: nil)
                self?.captureViewController = nil
            }
            present(viewController, animated: true, completion: nil)
            self.captureViewController = viewController
        }
    }
}

