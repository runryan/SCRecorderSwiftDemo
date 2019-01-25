//
//  Permissin.swift
//  TouchToRecord
//
//  Created by Ryan on 2019/1/24.
//  Copyright © 2019 bechoed. All rights reserved.
//

import Foundation
import AVFoundation
import Photos

enum MediaType {
    case video
    case audio
    case photoLibrary
    var name: String {
        switch self {
        case .video:
            return "相机"
        case .audio:
            return "麦克风"
        case .photoLibrary:
            return "照片"
        }
    }
}

class AuthorizationHelper {
    
    public static let shared = AuthorizationHelper()
    private init() {}
    
    /// 获取访问相机和麦克风的权限
    ///
    /// - Parameter handler: 相机或者麦克风权限获取失败时参数为(false, 对应的mediaType),都获取成功时（true, nil）
    func requestCaptureDeviceAccess(completionHandler handler: @escaping (Bool, MediaType?) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { isAuthorized in
            if isAuthorized {
                AVCaptureDevice.requestAccess(for: .audio, completionHandler: { isAuthorized in
                    if isAuthorized {
                        handler(true, nil)
                        return
                    }
                    handler(false, .audio)
                })
                return
            }
            handler(false, .video)
        }
    }
    
    
    /// 获取访问相册权限
    ///
    /// - Parameter handler: 成功true否则false
    func requestPhotoLibraryAccess(completionHandler handler: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                self?.requestPhotoLibraryAccess(completionHandler: handler)
            }
        case .restricted:
            handler(false)
        case .denied:
            handler(false)
        case .authorized:
            handler(true)
        }
    }
    
    
    /// 获取相机、麦克风、相册权限
    ///
    /// - Parameter handler: 任意权限获取失败参数为(false, 相应的媒体资源)，否则(true, nil)
    func requestAll(completionHandler handler: @escaping (Bool, MediaType?) -> Void) {
        requestCaptureDeviceAccess { [weak self] isAuthorized, mediaType in
            if isAuthorized {
                self?.requestPhotoLibraryAccess(completionHandler: { isAuthorized in
                    if isAuthorized {
                        handler(true, nil)
                        print("获取到了所有权限")
                        return
                    }
                    print("相册权限获取失败")
                    handler(false, .photoLibrary)
                })
                return
            }
            print("\(mediaType!.name) 权限获取失败")
            handler(false, mediaType)
        }
    }
    
}
