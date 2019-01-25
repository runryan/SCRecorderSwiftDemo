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
            viewController.maxRecordDuration = 3
            viewController.completeHandler = { [weak self] success, asset, error in
                self?.dismiss(animated: true, completion: nil)
                self?.captureViewController = nil
                if success {
                    print("拍摄成功\(asset!.localIdentifier)")
                    return
                }
                print("拍摄失败")
            }
            show(viewController, sender: nil)
            self.captureViewController = viewController
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("---- viewWillAppear --- ")
    }
}

