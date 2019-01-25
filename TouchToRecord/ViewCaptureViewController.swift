//
//  ViewCaptureViewController.swift
//  TouchToRecord
//
//  Created by ryan on 2019/1/23.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit
import SnapKit
import AVFoundation
import SCRecorder
import CircleProgressView
import Photos

class ViewCaptureViewController: UIViewController {
    
    @IBOutlet weak var preview: UIView!
    @IBOutlet weak var recordView: TouchableView!
    @IBOutlet weak var progressView: CircleProgressView!
    
    private var unauthorizedDialog: UIAlertController?
    private var isAuthorized = false
    
    lazy var recorder = SCRecorder.shared()

    override func viewDidLoad() {
        super.viewDidLoad()
        requestAuthorizations()
    }
    
    // MARK: 获取所有的权限
    private func requestAuthorizations() {
        AuthorizationHelper.shared.requestAuthorizations { isAuthorized in
            DispatchQueue.main.async { [weak self] in
                self?.isAuthorized = isAuthorized
                if isAuthorized {
                    self?.setupRecorderAnControl()
                    return
                }
                self?.showUnAuthorizedDialog()
            }
        }
    }
    
    // MARK: 显示未授权弹窗
    private func showUnAuthorizedDialog() {
        let unauthorizedDialog  = UIAlertController(title: "权限获取失败", message: "APP需要访问您的相机、麦克风以及照片才能继续下面的操作，请APP开启权限后再试", preferredStyle: .alert)
        self.unauthorizedDialog = unauthorizedDialog
        let permitAction = UIAlertAction(title: "开启权限", style: .default) { _ in
            UIApplication.shared.open(URL(string: "prefs:root=Privacy")!)
        }
        let denyAction = UIAlertAction(title: "拒绝", style: .default) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        unauthorizedDialog.addAction(permitAction)
        unauthorizedDialog.addAction(denyAction)
        present(unauthorizedDialog, animated: true, completion: nil)
    }
    
    private func setupRecorderAnControl() {
        setupRecorder()
        dealWithRecordControl()
    }
    
    // MARK: 创建VideoRecorder
    private func setupRecorder() {
        recorder.captureSessionPreset = SCRecorderTools.bestCaptureSessionPresetCompatibleWithAllDevices()
        recorder.delegate = self
        recorder.session = SCRecordSession()
        recorder.autoSetVideoOrientation = false
        recorder.previewView = self.preview
        recorder.initializeSessionLazily = false
        recorder.maxRecordDuration = CMTime(seconds: 15, preferredTimescale: CMTimeScale(600))
        do {
            try recorder.prepare()
        } catch {
            print("出错了\(error)")
        }
    }
    
    // MARK: 开始和停止录制
    private func dealWithRecordControl() {
        recordView.touchCallback = { [weak self] isTouching in
            if isTouching {
                self?.startRecord()
                return
            }
            self?.recorder.pause { [weak self] in
                self?.stopRecord()
            }
        }
    }
    
    func prepareSession() {
        if recorder.session == nil {
            let session = SCRecordSession()
            session.fileType = AVFileType.mp4.rawValue
            recorder.session = session
        }
    }
    
    // MARK: 更新进度
    func updateTime() {
        var recordTime = CMTime.zero
        if let session = recorder.session {
            recordTime = session.duration
        }
        let duration = recordTime.seconds
        print("录制了\(duration)秒")
        progressView.progress = duration / 15
    }
    
    private func startRecord() {
        recorder.record()
    }
    
    private func stopRecord() {
        SCRecordSessionManager.sharedInstance()?.save(recorder.session)
        let exportSession = SCAssetExportSession(asset: recorder.session!.assetRepresentingSegments())
        exportSession.videoConfiguration.preset = SCPresetLowQuality
        exportSession.videoConfiguration.maxFrameRate = 25
        exportSession.audioConfiguration.preset = SCPresetLowQuality
        exportSession.outputUrl = recorder.session?.outputUrl
        print("导出的路径为: \(recorder.session!.outputUrl)")
        exportSession.outputFileType = AVFileType.mp4.rawValue
        exportSession.delegate = self
        exportSession.contextType = SCContextType.auto
        exportSession.exportAsynchronously { [weak self] in
            guard let `self` = self else {
                return
            }
            if exportSession.cancelled == true {
                print("导出取消了")
                return
            }
            guard let error = exportSession.error else {
                print("导出成功")
                SCSaveToCameraRollOperation().saveVideoURL(exportSession.outputUrl!, completion: { (url, error) in
                    guard let error = error else {
                        if let videoURL = URL(string: url ?? "") {
                            print("获取视频的PHAsset")
                            self.generateVideoAsset(videoURL: videoURL)
                        } else {
                            print("保存到了相册路径为空？？？")
                        }
                        return
                    }
                    print("保存到相册失败\(error)")
                })
                return
            }
            print("导出出错了\(error)")
        }
    }
    
    private func generateVideoAsset(videoURL: URL) {
        var identifier: String?
        PHPhotoLibrary.shared().performChanges({
           let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            identifier = request?.placeholderForCreatedAsset?.localIdentifier
        }, completionHandler: { saved, error in
            if !saved {
                print("资源保存失败…… \(error!)")
                return
            }
            guard let identifier = identifier else {
                 print("资源保存失败…… identifier为空")
                return
            }
            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject {
                print("资源获取成功……")
            } else {
                print("资源获取失败……")
            }
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recorder.previewViewFrameChanged()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestAuthorizations()
        prepareSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        recorder.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        recorder.stopRunning()
    }
    
    @IBAction func switchDevicePosition(_ sender: Any) {
        recorder.switchCaptureDevices()
    }
    
    @IBAction func retake(_ sender: Any) {
        if let session = recorder.session {
            session.cancel(nil)
        }
        prepareSession()
    }
    
}

extension ViewCaptureViewController: SCRecorderDelegate {
    func recorder(_ recorder: SCRecorder, didAppendVideoSampleBufferIn session: SCRecordSession) {
        updateTime()
    }
    
    func recorder(_ recorder: SCRecorder, didInitializeVideoIn session: SCRecordSession, error: Error?) {
        if let error = error {
            print("初始化失败： \(error)")
            return
        }
        print("初始化完成")
    }
    
    func recorder(_ recorder: SCRecorder, didBeginSegmentIn session: SCRecordSession, error: Error?) {
        if let error = error {
            print("开始录制时出错了\(error)")
            return
        }
        print("开始录制")
    }
    
    func recorder(_ recorder: SCRecorder, didComplete segment: SCRecordSessionSegment?, in session: SCRecordSession, error: Error?) {
        if let segment = segment {
            print("录制完成: \(segment.url)")
        }
        if let error = error {
            print("录制出错了： \(error)")
        }
    }
    
    func recorder(_ recorder: SCRecorder, didComplete session: SCRecordSession) {
        print("didComplete session")
    }
}

extension ViewCaptureViewController : SCAssetExportSessionDelegate {
    
}

