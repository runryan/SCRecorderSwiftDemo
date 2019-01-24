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

class ViewCaptureViewController: UIViewController {
    
    @IBOutlet weak var preview: UIView!
    @IBOutlet weak var recordView: TouchableView!
    @IBOutlet weak var progressView: CircleProgressView!
    
    lazy var recorder = SCRecorder.shared()
    var exportSession: SCAssetExportSession?
    
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
        recordView.touchCallback = { [weak self] isTouching in
            if isTouching {
                self?.startRecord()
            } else {
                self?.recorder.pause { [weak self] in
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
        progressView.progress = duration / 15
    }
    
    func startRecord() {
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
        exportSession.exportAsynchronously { [weak self] in
            guard let `self` = self else {
                return
            }
            if self.exportSession?.cancelled == true {
                print("导出取消了")
                return
            }
            guard let error = self.exportSession?.error else {
                print("导出成功")
                SCSaveToCameraRollOperation().saveVideoURL(exportSession.outputUrl!, completion: { (url, error) in
                    guard let error = error else {
                        print("保存到了相册\(url ?? "")")
                        self.exportSession = nil
                        return
                    }
                    print("保存到相册失败\(error)")
                })
                return
            }
            print("导出出错了\(error)")
        }
        self.exportSession = exportSession
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recorder.previewViewFrameChanged()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

//extension ViewCaptureViewController : NextLevelDelegate {
//
//    func requestAuthorization() {
//        if NextLevel.shared.authorizationStatus(forMediaType: .video) == .authorized
//            && NextLevel.shared.authorizationStatus(forMediaType: .audio) == .authorized{
//            setupNextlevel()
//            return
//        }
//        NextLevel.shared.requestAuthorization(forMediaType: .video)
//        NextLevel.shared.requestAuthorization(forMediaType: .audio)
//    }
//
//    private func setupNextlevel() {
////        nextLevel.delegate = self
////        nextLevel.deviceDelegate = self
////        nextLevel.videoDelegate = self
////        nextLevel.photoDelegate = self
////        nextLevel.captureMode = .video
////        nextLevel.devicePosition = .back
////        nextLevel.videoConfiguration.preset = .low
//
//        setupPreview()
//        setupRecordButton()
//        startNextLevel()
//    }
//
//    private func setupPreview() {
//        let preview = UIView()
//        view.addSubview(preview)
//        preview.snp.makeConstraints { make in
//            make.edges.equalTo(self.view)
//        }
//        preview.layoutIfNeeded()
//        let previewLayer = NextLevel.shared.previewLayer
//        previewLayer.frame = preview.bounds
//        preview.layer.addSublayer(previewLayer)
//        self.preview = preview
//    }
//
//    private func startNextLevel() {
//        do {
//            try NextLevel.shared.start()
//        } catch {
//            print("启动失败……\(error)")
//        }
//    }
//
//    private func setupRecordButton() {
//        let recordButton = UIButton()
//        recordButton.backgroundColor = .red
//        self.recordButton = recordButton
//        recordButton.addTarget(self, action: #selector(controlRecord), for: .touchUpInside)
//        recordButton.setTitle("开始录制", for: .normal)
//        view.addSubview(recordButton)
//        recordButton.snp.makeConstraints { make in
//            make.centerX.equalTo(self.view)
//            make.bottom.equalTo(self.view).offset(-44)
//            make.width.equalTo(self.view)
//        }
//    }
//
//    @objc private func controlRecord() {
//        if NextLevel.shared.isRecording {
//            NextLevel.shared.pause()
//            nextLevel.session?.mergeClips(usingPreset: AVAssetExportPreset640x480, completionHandler: { (url, error) in
//                if let url = url {
//                    print("视频保存的位置为\(url)")
//                    return
//                }
//                print("导出出错了\(error!)")
//            })
//            NextLevel.shared.stop()
//            return
//        }
//        nextLevel.record()
//    }
//
//
//    func nextLevel(_ nextLevel: NextLevel, didUpdateAuthorizationStatus status: NextLevelAuthorizationStatus, forMediaType mediaType: AVMediaType) {
//        switch status {
//        case .notDetermined:
//            requestAuthorization()
//        case .notAuthorized:
//            print("相机被禁用")
//        case .authorized:
//            setupNextlevel()
//        }
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didUpdateVideoConfiguration videoConfiguration: NextLevelVideoConfiguration) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didUpdateAudioConfiguration audioConfiguration: NextLevelAudioConfiguration) {
//    }
//
//    func nextLevelSessionWillStart(_ nextLevel: NextLevel) {
//    }
//
//    func nextLevelSessionDidStart(_ nextLevel: NextLevel) {
//    }
//
//    func nextLevelSessionDidStop(_ nextLevel: NextLevel) {
//    }
//
//    func nextLevelSessionWasInterrupted(_ nextLevel: NextLevel) {
//    }
//
//    func nextLevelSessionInterruptionEnded(_ nextLevel: NextLevel) {
//    }
//
//    func nextLevelCaptureModeWillChange(_ nextLevel: NextLevel) {
//    }
//
//    func nextLevelCaptureModeDidChange(_ nextLevel: NextLevel) {
//    }
//
//}
//
//extension ViewCaptureViewController : NextLevelVideoDelegate, NextLevelDeviceDelegate  {
//    func nextLevel(_ nextLevel: NextLevel, didUpdateVideoZoomFactor videoZoomFactor: Float) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didChangeLensPosition lensPosition: Float) {
//    }
//
//
//    func nextLevelDevicePositionWillChange(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevelDevicePositionDidChange(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didChangeDeviceOrientation deviceOrientation: NextLevelDeviceOrientation) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didChangeDeviceFormat deviceFormat: AVCaptureDevice.Format) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didChangeCleanAperture cleanAperture: CGRect) {
//
//    }
//
//    func nextLevelWillStartFocus(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevelDidStopFocus(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevelWillChangeExposure(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevelDidChangeExposure(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevelWillChangeWhiteBalance(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevelDidChangeWhiteBalance(_ nextLevel: NextLevel) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, willProcessRawVideoSampleBuffer sampleBuffer: CMSampleBuffer, onQueue queue: DispatchQueue) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, renderToCustomContextWithImageBuffer imageBuffer: CVPixelBuffer, onQueue queue: DispatchQueue) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, willProcessFrame frame: AnyObject, pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, onQueue queue: DispatchQueue) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didSetupVideoInSession session: NextLevelSession) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didSetupAudioInSession session: NextLevelSession) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didStartClipInSession session: NextLevelSession) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didCompleteClip clip: NextLevelClip, inSession session: NextLevelSession) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didAppendVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didSkipVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didAppendVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didSkipVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didAppendAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didSkipAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didCompleteSession session: NextLevelSession) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didCompletePhotoCaptureFromVideoFrame photoDict: [String : Any]?) {
//
//    }
//
//
//}
//
//extension ViewCaptureViewController : NextLevelPhotoDelegate {
//    func nextLevel(_ nextLevel: NextLevel, willCapturePhotoWithConfiguration photoConfiguration: NextLevelPhotoConfiguration) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didCapturePhotoWithConfiguration photoConfiguration: NextLevelPhotoConfiguration) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didProcessPhotoCaptureWith photoDict: [String : Any]?, photoConfiguration: NextLevelPhotoConfiguration) {
//
//    }
//
//    func nextLevel(_ nextLevel: NextLevel, didProcessRawPhotoCaptureWith photoDict: [String : Any]?, photoConfiguration: NextLevelPhotoConfiguration) {
//
//    }
//
//    func nextLevelDidCompletePhotoCapture(_ nextLevel: NextLevel) {
//
//    }
//
//
//    @available(iOS 11.0, *)
//    func nextLevel(_ nextLevel: NextLevel, didFinishProcessingPhoto photo: AVCapturePhoto) {
//
//    }
//
//
//}


