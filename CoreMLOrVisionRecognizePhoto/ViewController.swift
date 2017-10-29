//
//  ViewController.swift
//  CoreMLOrVisionRecognizePhoto
//
//  Created by 新闻 on 2017/10/19.
//  Copyright © 2017年 Lvmama. All rights reserved.
//

import UIKit
import Vision
import CoreML

class ViewController: UIViewController,UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var modelFile = GoogLeNetPlaces()
    @IBOutlet var topBtn: UIButton!
    @IBOutlet var resultLabel: UILabel!
    @IBOutlet var switchBtn: UISwitch!   // true:纯CoreML false:CoreMl+Vision
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.resultLabel.adjustsFontSizeToFitWidth = true
        self.switchBtn.setOn(true, animated: true)
    }
    
    // 切换分析模式 纯CoreML or CoreML+Vision
    @IBAction func switchBtnClick(_ sender: Any) {
        self.switchBtn.isOn = !self.switchBtn.isOn
    }
    
    // 选择图片
    @IBAction func btnClicked(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .savedPhotosAlbum
        present(picker, animated: true)
    }
    
    // UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("没选中图片")
        }
        DispatchQueue.main.async {
            self.topBtn.setBackgroundImage(image, for: .normal)
        }
        self.resultLabel.text = "图片处理中..."
        if self.switchBtn.isOn {
            DispatchQueue.global().async {
                self.coreMLprocessImage(image: image)
            }
        } else {
            DispatchQueue.global().async {
                self.coreMLAndVisionProcessImage(image: image)
            }
        }
    }
    
    // CoreML+Vision处理图片
    func coreMLprocessImage(image:UIImage) {
        let hander = VNImageRequestHandler(cgImage:image.cgImage!)
        // 把模型拿来做视觉处理
        let model = try! VNCoreMLModel(for:modelFile.model)
        let request = VNCoreMLRequest(model:model,completionHandler:completionHandler)
        try? hander.perform([request])
    }
    
    // 处理结果
    func completionHandler(request:VNRequest,error:Error?) {
        // 判断结果是否存在
        guard let results = request.results as? [VNClassificationObservation] else {
            fatalError("没有结果")
        }
        
        // 分析结果
        var bestPredication = ""
        // 百分比
        var bestConfidence:VNConfidence = 0
        
        for classIdentifier in results {
            if classIdentifier.confidence > bestConfidence {
                bestPredication = classIdentifier.identifier
                bestConfidence = classIdentifier.confidence
            }
        }
        DispatchQueue.main.async {
            self.resultLabel.text = "预测结果:\(bestPredication) 可信度:\(lroundf(bestConfidence * 100))%"
        }
    }
    
    // CoreML处理图片
    func coreMLAndVisionProcessImage(image:UIImage) {
        // 裁剪图片
        let imageWidth:CGFloat = 224.0
        let imageHeight:CGFloat = 224.0
        UIGraphicsBeginImageContext(CGSize(width:imageWidth, height:imageHeight))
        image.draw(in:CGRect(x:0, y:0, width:imageHeight, height:imageHeight))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard resizedImage != nil else {
            fatalError("resized Image fail")
        }
        
        // 转成CVPixelBuffer
        guard let pixelBuffer = imageCovertToPixelBuffer(from: resizedImage!) else {
            fatalError("UIImage->CVPixelBuffer失败")
        }
        
        guard let outPut = try? modelFile.prediction(sceneImage: pixelBuffer) else {
            fatalError("处理失败")
        }
        
        DispatchQueue.main.async {
            self.resultLabel.text = "预测结果:\(outPut.sceneLabel) 可信度:\(lroundf(Float(outPut.sceneLabelProbs[outPut.sceneLabel]! * 100)))%"
        }
    }
}

 extension ViewController {
    // UIImage -> CVPixelBuffer
    func imageCovertToPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}


