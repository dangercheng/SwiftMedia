//
//  CaptureKit.swift
//  Capture
//
//  Created by dandj on 2019/2/27.
//  Copyright © 2019 com.dandj. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class CaptureKit : NSObject{
    
    let captureSession = AVCaptureSession()
    var videoInput: AVCaptureDeviceInput!
    var videoOutput: AVCaptureVideoDataOutput!
    var audioOutput: AVCaptureAudioDataOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    private let videoQueue = DispatchQueue(label: "videoQueue")
    private var capturing = false
    private var mediaWriter: MediaWriter? = nil
    
    override init() {
        super.init()
        setupSession()
        setupVideo()
        setupAudio()
        setupPreviewLayer()
    }
}

extension CaptureKit {
    func startSession() {
        captureSession.startRunning()
    }
    
    func stopSession() {
        captureSession.stopRunning()
    }
    
    func startCapture() {
        if capturing {
            return
        }
        mediaWriter = MediaWriter(previewLayer.frame.size.width, previewLayer.frame.size.height)
        capturing = true
    }
    
    func endCapture(completion: @escaping ((_ videoUrl: URL?) -> Void)) {
        capturing = false
        mediaWriter?.stopWriting(completion: completion)
    }
    
    func switchCamera() {
        let currentPosition = videoInput.device.position
        var toPosition = AVCaptureDevice.Position.front
        if currentPosition == .unspecified || currentPosition == .front {
            toPosition = .back
        }
        guard let toDivice = getCameraDevice(position: toPosition) else {
            print("切换摄像头获取\(toPosition)失败")
            return
        }
        guard let toVideoInput = try? AVCaptureDeviceInput(device: toDivice) else {
            print("切换摄像头获取toVideoInput失败")
            return
        }
        captureSession.beginConfiguration()
        captureSession.removeInput(videoInput)
        if captureSession.canAddInput(toVideoInput) {
            captureSession.addInput(toVideoInput)
            let connection = videoOutput.connection(with: .video)
            connection?.videoOrientation = .portrait
            videoInput = toVideoInput
        }
        captureSession.commitConfiguration()
    }
}

extension CaptureKit {
    private func setupSession() {
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
    }
    
    private func setupVideo() {
        guard let backDevice = getCameraDevice(position: .back) else {
            print("获取后置摄像头失败")
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: backDevice) else {
            print("创建videoInput失败")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        self.videoInput = videoInput
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        guard let connection = videoOutput.connection(with: .video) else {
            print("获取connection失败")
            return
        }
        connection.videoOrientation = .portrait
    }
    
    private func setupAudio() {
        let device = AVCaptureDevice.default(for: .audio)
        guard let audioInput = try? AVCaptureDeviceInput(device: device!) else {
            print("创建audioInput失败")
            return
        }
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }
    }
    
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspect
    }
    
    private func getCameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let divices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position).devices
        for device in divices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
}

extension CaptureKit : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !capturing {
            return
        }
        
        if connection == videoOutput.connection(with: .video) {
            mediaWriter!.append(sampleBuffer: sampleBuffer, type: .video)
        }
        else if connection == audioOutput.connection(with: .audio) {
            mediaWriter!.append(sampleBuffer: sampleBuffer, type: .audio)
        }
    }
}
