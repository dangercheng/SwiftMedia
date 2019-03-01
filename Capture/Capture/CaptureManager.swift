//
//  CaptureManager.swift
//  Capture
//
//  Created by dandj on 2019/2/27.
//  Copyright © 2019 com.dandj. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class CapatureManager {
    var contentView: UIView
    private let captureKit: CaptureKit!
    
    init(contentView: UIView) {
        self.contentView = contentView
        captureKit = CaptureKit()
    }
    
    func startPreview() {
        guard let layer = captureKit.previewLayer else {
            print("初始化previewLayer失败")
            return
        }
        layer.frame = contentView.bounds
        contentView.layer.addSublayer(layer)
        captureKit.startSession()
    }
    
    func endPreview() {
        captureKit.stopSession()
    }
    
    func startCapture() {
        captureKit.startCapture()
    }
    
    func endCapture(completion: @escaping ((_ videoUrl: URL?) -> Void)) {
        captureKit.stopSession()
        captureKit.endCapture(completion: completion)
    }
    
    func switchCamera() {
        captureKit.switchCamera()
    }
    
}
