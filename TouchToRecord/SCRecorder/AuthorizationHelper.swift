//
//  AuthorizationHelper.swift
//  TouchToRecord
//
//  Created by Ryan on 2019/1/24.
//  Copyright © 2019 bechoed. All rights reserved.
//

import Foundation
import Photos
import AVFoundation

class AuthorizationHelper {
    
    static let shared = AuthorizationHelper()
    private init() {}
    
    func requestCaptureAuthorization(forMediaType mediaType: AVMediaType, completeHandler handler: @escaping ((Bool) -> Void)) {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { isAuthorized in
                handler(isAuthorized)
            }
        case .restricted:
            handler(false)
        case .denied:
            handler(false)
        case .authorized:
            handler(false)
        }
    }
    
    func requestImageLibraryAuthorization(completionHander handler: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                self.requestImageLibraryAuthorization(completionHander: handler)
            }
        case .restricted:
            handler(false)
        case .denied:
            handler(false)
        case .authorized:
            handler(true)
        }
    }
    
    func requestAuthorizations(completionHander handler: @escaping (Bool) -> Void) {
        requestCaptureAuthorization(forMediaType: .video) { [weak self] isAuthorized in
            if isAuthorized {
                self?.requestCaptureAuthorization(forMediaType: .audio, completeHandler: { [weak self] isAuthorized in
                    if isAuthorized {
                        self?.requestImageLibraryAuthorization(completionHander: handler)
                        return
                    }
                    handler(false)
                })
                return
            }
            handler(false)
        }
    }
    
}
