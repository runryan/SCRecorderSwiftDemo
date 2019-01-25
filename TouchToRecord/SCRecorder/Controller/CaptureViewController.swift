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

class CaptureViewController: UIViewController {
    
    @IBOutlet weak var tipsLabel: UILabel!
    @IBOutlet weak var previewContainer: UIView!
    @IBOutlet weak var recordButton: TouchableView!
    @IBOutlet weak var progressView: CircleProgressView!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var retakenButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var loadingView: UIView!
    
    private weak var playerView: MediaPreview?
    
    private lazy var recorder = SCRecorder.shared()
    private var isRecorderPrepared = false
    private var exportSession: SCAssetExportSession?
    private var imageToSave: UIImage?
    
    private var unAuthorizedAlertController: UIAlertController?
    private var isRequetingAuthorization = false
    
    var completeHandler: ((Bool, PHAsset?, Error?) -> Void)?

    var enableCaptureVideo = true
    var enableCaptureImage = true
    var maxRecordDuration: Double = 15
    
    private var isLoadingViewHidden : Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.loadingView.isHidden = self?.isLoadingViewHidden ?? true
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordButton.isHidden = true
        progressView.isHidden = true
        switchCameraButton.isHidden = true
        retakenButton.isHidden = true
        saveButton.isHidden = true
        tipsLabel.isHidden = true
        requestAuthorization()
        recordButton.enableTap = enableCaptureImage
        recordButton.enableLongPress = enableCaptureVideo
        isLoadingViewHidden = false
        if !enableCaptureVideo {
            tipsLabel.text = "轻点拍照"
        }
        if !enableCaptureImage {
            tipsLabel.text = "按住摄像"
        }
    }
    
    func prepareCaptureView() {
//        if isRecorderPrepared {
//            return
//        }
//        isRecorderPrepared = true
        print("prepareCaptureView...")
        setupRecorder()
        dealWithRecordAction()
        showPlayUI(false)
        tipsLabel.isHidden = false
        recorder.startRunning()
        isLoadingViewHidden = true
    }

    func setupRecorder() {
        recorder.captureSessionPreset = SCRecorderTools.bestCaptureSessionPresetCompatibleWithAllDevices()
        recorder.delegate = self
        recorder.session = SCRecordSession()
        recorder.autoSetVideoOrientation = false
        recorder.previewView = self.previewContainer
        recorder.initializeSessionLazily = false
        recorder.maxRecordDuration = CMTime(seconds: maxRecordDuration, preferredTimescale: CMTimeScale(600))
        do {
            if recorder.isPrepared {
                return
            }
            try recorder.prepare()
        } catch {
            print("出错了\(error)")
        }
    }
    
    func dealWithRecordAction() {
        recordButton.touchActionCallback = { [weak self] action in
            guard let `self` = self else {
                return
            }
            self.tipsLabel.isHidden = true
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
        var progress = duration / maxRecordDuration
        if progress < 0 {
            progress = 0
        }
        if progress > 1 {
            progress = 1
        }
        progressView.progress = progress
    }
    
    func startRecord() {
        cancelButton.isHidden = true
        recorder.captureSessionPreset = AVCaptureSession.Preset.high.rawValue
        recorder.record()
    }
    
    
    func takePhoto() {
        cancelButton.isHidden = true
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
    
    // MARK: 保存图片 / 视频
    func saveAsset(forImage image: UIImage?, orVideo videoUrl: URL?) {
        var localIdentifier: String?
        isLoadingViewHidden = false
        PHPhotoLibrary.shared().performChanges({
            if let image = image {
                localIdentifier = PHAssetChangeRequest.creationRequestForAsset(from: image).placeholderForCreatedAsset?.localIdentifier
            }
            if let videoUrl = videoUrl {
                localIdentifier = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)?.placeholderForCreatedAsset?.localIdentifier
            }
        }, completionHandler: { [weak self] saved, error in
            self?.isLoadingViewHidden = true
            if saved, let localIdentifier = localIdentifier {
                let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
                print("媒体资料保存成功……\(asset?.localIdentifier ?? "")")
                self?.completeHandler?(true, asset, nil)
                return
            }
            self?.completeHandler?(false, nil, error)
            print("媒体资料保存失败\(error!)")
        })
        
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recorder.previewViewFrameChanged()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear...")
        requestAuthorization()
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

// MARK: 权限相关
extension CaptureViewController {
    
    func requestAuthorization() {
        if isRequetingAuthorization {
            return
        }
        isRequetingAuthorization = true
        print("请求权限……")
        AuthorizationHelper.shared.requestAll(completionHandler: {  isAllGranted, mediaType in
            DispatchQueue.main.async { [weak self] in
                if isAllGranted {
                    self?.isRequetingAuthorization = false
                    self?.prepareCaptureView()
                    return
                }
                self?.showUnAuthorizedTips(for: mediaType!)
            }
        })
    }
    
    func showUnAuthorizedTips(for mediaType: MediaType) {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] ?? "APP"
        let message = "请到设置 - 隐私 - \(mediaType.name)为【\(appName)】开启访问权限后再试"
        let unAuthorizedAlertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.unAuthorizedAlertController = unAuthorizedAlertController
        let showSettingAction = UIAlertAction(title: "确认", style: .default) { [weak self] action in
            self?.unAuthorizedAlertController?.dismiss(animated: true, completion: nil)
            self?.unAuthorizedAlertController = nil
            self?.isRequetingAuthorization = false
            self?.completeHandler?(false, nil, nil)
//            let settingsURL = URL(string: UIApplication.openSettingsURLString)!
//            UIApplication.shared.open(settingsURL, options: [UIApplication.OpenExternalURLOptionsKey : Any](), completionHandler: nil)
        }
//        let denyAction = UIAlertAction(title: "拒绝", style: .cancel) { [weak self] action in
//            self?.unAuthorizedAlertController?.dismiss(animated: true, completion: nil)
//            self?.unAuthorizedAlertController = nil
//            self?.completeHandler?(false, nil, nil)
//            self?.isRequetingAuthorization = false
//        }
//        unAuthorizedAlertController.addAction(denyAction)
        unAuthorizedAlertController.addAction(showSettingAction)
        present(unAuthorizedAlertController, animated: true, completion: nil)
    }
    
}

// MARK: 按键相关
extension CaptureViewController {
    
    @IBAction func switchDevicePosition(_ sender: Any) {
        recorder.switchCaptureDevices()
    }
    
    @IBAction func cancelCapture(_ sender: Any) {
        completeHandler?(false, nil, nil)
    }
    
    @IBAction func retake(_ sender: Any) {
        cancelButton.isHidden = false
        showPlayUI(false)
        progressView.progress = 0
        playerView?.stop()
        playerView = nil
        if let session = recorder.session {
            recorder.session = nil
            session.cancel(nil)
        }
        prepareSession()
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
                    self?.completeHandler?(false, nil, nil)
                    return
                }
                self?.saveAsset(forImage: nil, orVideo: videoURL)
                return
            }
            self?.completeHandler?(false, nil, error)
            print("导出出错了\(error)")
        }
    }
}

// MARK: 预览UI相关
extension CaptureViewController {
    
    // MARK: 切换录制和预览视图
    private func showPlayUI(_ show: Bool) {
        retakenButton.isHidden = !show
        saveButton.isHidden = !show
        switchCameraButton.isHidden = show
        recordButton.isHidden = show
        progressView.isHidden = show
        cancelButton.isHidden = show
    }
    
    private func addPreview() {
        if self.playerView != nil {
            return
        }
        let mediaPreview = MediaPreview()
        self.playerView = mediaPreview
        previewContainer.addSubview(mediaPreview)
        mediaPreview.snp.makeConstraints { make in
            make.edges.equalTo(self.previewContainer)
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
            completeHandler?(false, nil, error)
            return
        }
        print("初始化完成")
    }
    
    func recorder(_ recorder: SCRecorder, didBeginSegmentIn session: SCRecordSession, error: Error?) {
        if let error = error {
            print("开始录制时出错了\(error)")
            completeHandler?(false, nil, error)
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
        stopRecord()
    }
}

extension CaptureViewController : SCAssetExportSessionDelegate {
    func assetExportSessionDidProgress(_ assetExportSession: SCAssetExportSession) {
        print("导出进度为progress: \(assetExportSession.progress)")
        isLoadingViewHidden = false
    }
}
