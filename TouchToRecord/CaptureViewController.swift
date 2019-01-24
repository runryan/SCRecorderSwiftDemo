//
//  ViewCaptureViewController.swift
//  TouchToRecord
//
//  Created by ryan on 2019/1/23.
//  Copyright © 2019 bechoed. All rights reserved.
//

import UIKit
import NextLevel
import SnapKit
import AVFoundation
import SCRecorder
import CircleProgressView
import Photos

class CaptureViewController: UIViewController {
    
    @IBOutlet weak var preview: UIView!
    @IBOutlet weak var recordButton: TouchableView!
    @IBOutlet weak var progressView: CircleProgressView!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var retakenButton: UIButton!
    
    private weak var playerView: VideoPlayerView?
    private lazy var recorder = SCRecorder.shared()
    private var exportSession: SCAssetExportSession?
    private var imageToSave: UIImage?
    var didRecordVideo: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        dealWithRecordAction()
        showPlayUI(false)
    }
    
    func dealWithRecordAction() {
        recordButton.touchActionCallback = { [weak self] action in
            guard let `self` = self else {
                return
            }
            switch action {
            case .tap:
                self.takePhoto()
            case .longPress:
                self.startRecord()
            case .endLongPress:
                self.recorder.pause { [weak self] in
                    self?.stopRecord()
                }
            }
        }
    }
    
    func takePhoto() {
        recorder.captureSessionPreset = AVCaptureSession.Preset.photo.rawValue
        recorder.capturePhoto { [weak self] (error, image) in
            guard let image = image else {
                self?.imageToSave = nil
                print("照片拍摄失败 \(error!)")
                return
            }
            self?.previewImage(image)
        }
    }
    
    func prepareSession() {
        if recorder.session == nil {
            let session = SCRecordSession()
            session.fileType = AVFileType.mp4.rawValue
            recorder.session = session
        }
    }
    
    func updateTime() {
        var recordTime = CMTime.zero
        if let session = recorder.session {
            recordTime = session.duration
        }
        let duration = recordTime.seconds
        print("录制了\(duration)秒")
        progressView.progress = duration / 15
    }
    
    func startRecord() {
        recorder.captureSessionPreset = AVCaptureSession.Preset.high.rawValue
        recorder.record()
    }
    
    func stopRecord() {
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
        self.exportSession = exportSession
        previewVideo()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recorder.previewViewFrameChanged()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareSession()
        playerView?.viewWillAppear()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        recorder.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        recorder.stopRunning()
        self.playerView?.viewWillDisappear()
    }
    
    @IBAction func switchDevicePosition(_ sender: Any) {
        recorder.switchCaptureDevices()
    }
    
    @IBAction func retake(_ sender: Any) {
        showPlayUI(false)
        progressView.progress = 0
        playerView?.removeFromSuperview()
        if let session = recorder.session {
            recorder.session = nil
            session.cancel(nil)
        }
        prepareSession()
    }
    
    // MARK: 保存图片
    func saveAsset(forImage image: UIImage?, orVideo videoUrl: URL?) {
        var localIdentifier: String?
        PHPhotoLibrary.shared().performChanges({
            if let image = image {
                localIdentifier = PHAssetChangeRequest.creationRequestForAsset(from: image).placeholderForCreatedAsset?.localIdentifier
            }
            if let videoUrl = videoUrl {
                localIdentifier = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)?.placeholderForCreatedAsset?.localIdentifier
            }
        }, completionHandler: { saved, error in
            if saved, let localIdentifier = localIdentifier {
                let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
                print("媒体资料保存成功……\(asset?.localIdentifier ?? "")")
                return
            }
            print("媒体资料保存失败\(error!)")
        })
        
    }
    
    // MARK: 保存视频
    @IBAction func saveVideo(_ sender: Any) {
        if let imageToSave = imageToSave {
            saveAsset(forImage: imageToSave, orVideo: nil)
            return
        }
        exportSession?.exportAsynchronously { [weak self] in
            if self?.exportSession?.cancelled == true {
                print("导出取消了")
                return
            }
            guard let error = self?.exportSession?.error else {
                print("导出成功")
                guard let videoURL = self?.exportSession?.outputUrl else {
                    self?.didRecordVideo?()
                    return
                }
                self?.saveAsset(forImage: nil, orVideo: videoURL)
                return
            }
            self?.didRecordVideo?()
            print("导出出错了\(error)")
        }
    }
    
    // MARK: 切换录制和预览视图
    private func showPlayUI(_ show: Bool) {
        retakenButton.isHidden = !show
        saveButton.isHidden = !show
        switchCameraButton.isHidden = show
        recordButton.isHidden = show
        progressView.isHidden = show
    }
    
    deinit {
        recorder.session?.cancel(nil)
        recorder.session = nil
        recorder.previewView?.removeFromSuperview()
        self.playerView?.removeFromSuperview()
        recorder.previewView = nil
        self.playerView = nil
        recorder.unprepare()
    }
}

extension CaptureViewController {
    
    private func addPreview() {
        let playerView = VideoPlayerView()
        self.playerView = playerView
        preview.addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.edges.equalTo(self.preview)
        }
    }
    
    private func previewImage(_ image: UIImage) {
        imageToSave = image
        addPreview()
        playerView?.previewImage(image)
        showPlayUI(true)
    }
    
    // MARK: 显示预览视图
    private func previewVideo() {
        imageToSave = nil
        addPreview()
        if let asset = recorder.session?.assetRepresentingSegments() {
            let playerItem = AVPlayerItem(asset: asset)
            playerView?.setupPlayerAndPlayerView(withPlayerItem: playerItem)
            playerView?.play()
        } else {
            print("预览失败")
        }
        showPlayUI(true)
    }
}

extension CaptureViewController: SCRecorderDelegate {
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

extension CaptureViewController : SCAssetExportSessionDelegate {
    func assetExportSessionDidProgress(_ assetExportSession: SCAssetExportSession) {
        print("导出进度为progress: \(assetExportSession.progress)")
    }
}
