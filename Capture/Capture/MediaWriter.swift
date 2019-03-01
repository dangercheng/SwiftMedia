//
//  MediaWriter.swift
//  Capture
//
//  Created by dandj on 2019/2/28.
//  Copyright © 2019 com.dandj. All rights reserved.
//

import Foundation
import AVFoundation

class MediaWriter {
    var videoUrl: URL?
    var videoExportUrl: URL?
    var videoWidth: CGFloat = 0.0
    var videoHeight: CGFloat = 0.0
    
    private var writer: AVAssetWriter?
    private var writerVideoInput: AVAssetWriterInput?
    private var writerAudioInput: AVAssetWriterInput?
    private var videoFolderUrl: URL?
    private var canStartWrite = false
    lazy private var writerQueue = DispatchQueue(label: "videoWriter")
}

extension MediaWriter {
    convenience init(_ videoWidth:CGFloat, _ videoHeight:CGFloat ) {
        self.init()
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        setupVideoFolder()
        setupWritter()
    }
    
    func append(sampleBuffer: CMSampleBuffer, type: AVMediaType) {
        writerQueue.async {
            guard
                let _writer = self.writer,
                let _writerVideoInput = self.writerVideoInput,
                let _writerAudioInput = self.writerAudioInput
            else {
                return
            }
            autoreleasepool {
                if(self.canStartWrite && _writer.status != AVAssetWriter.Status.writing) {
                    _writer.startWriting()
                    _writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                    self.canStartWrite = false
                }
                
                if type == .video && self.writerVideoInput!.isReadyForMoreMediaData {
                    if !_writerVideoInput.append(sampleBuffer) {
                        self.stopWriting(completion: {_ in
                        })
                    }
                }
                else if type == .audio && self.writerAudioInput!.isReadyForMoreMediaData {
                    if !_writerAudioInput.append(sampleBuffer) {
                        self.stopWriting(completion: {_ in
                        })
                    }
                }
            }
        }
    }
    
    func stopWriting(completion: @escaping ((_ videoUrl:URL?)->Void)) {
        writerQueue.async {
            if self.writer != nil && self.writer!.status == AVAssetWriter.Status.writing {
                self.writer?.finishWriting(completionHandler: { [weak self] in
                    self!.canStartWrite = true
                    self!.writer = nil
                    self!.writerVideoInput = nil
                    self!.writerAudioInput = nil
                    
                    self!.cropVideo(completion: { [weak self] (success) in
                        DispatchQueue.main.async(execute: {
                            if success {
                                completion(self!.videoExportUrl)
                            } else {
                                completion(nil)
                            }
                        })
                    })
                })
            }
        }
    }
}

extension MediaWriter {
    private func setupVideoFolder() {
        let fileManager = FileManager.default
        let cacheUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        let videoFolderUrl = cacheUrl?.appendingPathComponent("Video")
        do {
            try fileManager.createDirectory(at: videoFolderUrl!, withIntermediateDirectories: true, attributes: nil)
            self.videoFolderUrl = videoFolderUrl
        } catch {
            print("初始化缓存目录错误：\(error)")
        }
    }
    
    private func generateVideoUrl() {
        guard let _videoFolderUrl = videoFolderUrl else {
            return
        }
        let videoFileName = generateVideoNamePrefix() + ".mp4"
        videoUrl = _videoFolderUrl.appendingPathComponent(videoFileName)
    }
    
    private func generateVideoNamePrefix() -> String! {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-hh-mm-ss-zzz"
        let dateStr = dateFormatter.string(from: Date())
        return dateStr
    }
    
    private func generateVideoExpportUrl() {
        guard let _videoUrl = videoUrl else {
            return
        }
        let videoExportPath = _videoUrl.path.replacingOccurrences(of: ".mp4", with: "export.mp4")
        videoExportUrl = URL(fileURLWithPath:videoExportPath)
    }
    
    private func setupWritter() {
        generateVideoUrl()
        guard let _videoUrl = videoUrl else {
            print("获取videoUrl失败")
            return
        }
        writer = try? AVAssetWriter(url: _videoUrl, fileType: .mp4)
        
        guard let _writer = writer else {
            print("获取writer失败")
            return
        }
        let bitsPerSecond = Float(videoWidth * videoHeight * 12.0)
        let compressionPreperties = [AVVideoAverageBitRateKey : NSNumber(value: bitsPerSecond),
                                     AVVideoExpectedSourceFrameRateKey : NSNumber(value: 15),
                                     AVVideoMaxKeyFrameIntervalKey : NSNumber(value: 15),
                                     AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel] as [String : Any]
        let videoCompressionSettings = [AVVideoCodecKey : AVVideoCodecType.h264,
                                        AVVideoWidthKey : Float(videoWidth * 2),
                                        AVVideoHeightKey : Float(videoHeight * 2),
                                        AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                        AVVideoCompressionPropertiesKey : compressionPreperties] as [String : Any]
        writerVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoCompressionSettings)
        writerVideoInput?.expectsMediaDataInRealTime = true
        
        let audioCompressionSettings = [AVEncoderBitRatePerChannelKey : 28000,
                                        AVFormatIDKey : kAudioFormatMPEG4AAC,
                                        AVNumberOfChannelsKey : 1,
                                        AVSampleRateKey : 22050] as [String : Any]
        writerAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioCompressionSettings)
        writerAudioInput?.expectsMediaDataInRealTime = true
        
        guard let _writerVideoInput = writerVideoInput else {
            print("获取writerVideoInput失败")
            return
        }
        guard let _writerAudioInput = writerAudioInput else {
            print("获取writerVideoInput失败")
            return
        }
        if _writer.canAdd(_writerVideoInput) {
            _writer.add(_writerVideoInput)
        }
        
        if(_writer.canAdd(_writerAudioInput)) {
            _writer.add(_writerAudioInput)
        }
        canStartWrite = true
    }
    
    
    /// 剪裁视频10s
    ///
    /// - Parameter completion:
    private func cropVideo(completion: ((_ success: Bool) -> Void)?) {
        generateVideoExpportUrl();
        
        guard
            let _videoUrl = videoUrl,
            let _videoExportUrl = videoExportUrl
        else { return }
        
        let videoAsset = AVURLAsset(url: _videoUrl)
        var endTime = CMTimeGetSeconds(videoAsset.duration)
        if(endTime > 10.0) {
            endTime = 10.0
        }
        let startTime: Float64 = 0
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)
        if compatiblePresets.contains(AVAssetExportPresetMediumQuality) {
            guard let exportSession = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPresetPassthrough) else {
                print("创建exportSession失败")
                return
            }
            exportSession.outputURL = _videoExportUrl
            exportSession.outputFileType = AVFileType.mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            let start = CMTimeMakeWithSeconds(startTime, preferredTimescale: videoAsset.duration.timescale)
            let duration = CMTimeMakeWithSeconds(endTime - startTime, preferredTimescale: videoAsset.duration.timescale)
            exportSession.timeRange = CMTimeRangeMake(start: start, duration: duration)
            exportSession.exportAsynchronously(completionHandler: { [weak self] in
                switch exportSession.status {
                    case AVAssetExportSession.Status.failed:
                        print("合成失败\(exportSession.error!.localizedDescription)")
                        if let _ = completion {
                            completion!(false)
                        }
                        break
                    case AVAssetExportSession.Status.cancelled:
                        print("合成被取消")
                        if let _ = completion {
                            completion!(false)
                        }
                        break
                    case AVAssetExportSession.Status.completed:
                        print("合成成功")
                        if let _ = completion {
                            completion!(true)
                        }
                        break
                    default:
                        completion!(false)
                        break
                }
                //删除老的
                try? FileManager.default.removeItem(at: self!.videoUrl!)
            })
        }
    }
}
