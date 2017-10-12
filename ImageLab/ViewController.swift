//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var faceFilters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridgeSub()
    
    //MARK: Outlets in view
    @IBOutlet weak var stageLabel: UILabel!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.bridge.loadHaarCascade(withFilename: "nose")
        
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.front)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these proerties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyHigh,CIDetectorTracking:true, CIDetectorSmile:true, CIDetectorEyeBlink:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        let f = getFaces(img: inputImage)
        var retImage = inputImage
        
        // if no faces on the back camera, try to detect heart rate via the finger method
        if (f.count == 0 && self.videoManager.getCameraPosition()==AVCaptureDevice.Position.back) {
            self.bridge.setTransforms(self.videoManager.transform)
            self.bridge.setImage(retImage,
                                 withBounds: retImage.extent, // the first face bounds
                                 andContext: self.videoManager.getCIContext())
            self.bridge.processImage()
            retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
            return retImage
        }
        retImage = self.applyFiltersToFaces(inputImage: retImage, features: f)
        return retImage
        // if you just want to process on separate queue use this code
        // this is a NON BLOCKING CALL, but any changes to the image in OpenCV cannot be displayed real time
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
//            self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
//            self.bridge.processImage()
//        }
        
        // use this code if you are using OpenCV and want to overwrite the displayed image via OpenCv
        // this is a BLOCKING CALL
//        self.bridge.setTransforms(self.videoManager.transform)
//        self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
//        self.bridge.processImage()
//        retImage = self.bridge.getImage()
        
        //HINT: you can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        //pasted code above
    }
    
    //MARK: Setup filtering
    func setupFilters(){
        filters = []
        
        let filterBump = CIFilter(name:"CIBumpDistortion")!
        filterBump.setValue(0.2, forKey: "inputScale")
        filterBump.setValue(75, forKey: "inputRadius")
        filters.append(filterBump)
        
        
        faceFilters = []
        let filterPinch = CIFilter(name:"CIPinchDistortion")!
        filterPinch.setValue(0.2, forKey: "inputScale")
        filterPinch.setValue(75, forKey: "inputRadius")
        faceFilters.append(filterPinch)
        
        
        
    }
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        var retImage = inputImage
        var filterCenter = CGPoint()
        
        for f in features {
            //set where to apply filter
            filterCenter.x = f.bounds.midX
            filterCenter.y = f.bounds.midY
            
            //do for each filter (assumes all filters have property, "inputCenter")
            for filt in filters{
                filt.setValue(retImage, forKey: kCIInputImageKey)
                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                // could also manipualte the radius of the filter based on face size!
                retImage = filt.outputImage!
            }
            
            
            let filtPinch = CIFilter(name:"CIPinchDistortion")!
            filtPinch.setValue(0.25, forKey: "inputScale")
            filtPinch.setValue(75, forKey: "inputRadius")
            
            if(f.hasLeftEyePosition){
                //put filter over eye
                filtPinch.setValue(retImage, forKey: kCIInputImageKey)
                filtPinch.setValue(CIVector(cgPoint: f.leftEyePosition), forKey: "inputCenter")
                retImage = filtPinch.outputImage!
                //show text if blinking
                if(f.leftEyeClosed){
                    print("Left Eye Blinking")
                }
            }
            if(f.hasRightEyePosition){
                //put filter over eye
                filtPinch.setValue(retImage, forKey: kCIInputImageKey)
                filtPinch.setValue(CIVector(cgPoint: f.rightEyePosition), forKey: "inputCenter")
                retImage = filtPinch.outputImage!
                //show text if blinking
                if(f.rightEyeClosed){
                    print("Right Eye Blinking")
                }
            }
            if(f.hasMouthPosition){
                //put filter over mouth
                filtPinch.setValue(0.4, forKey: "inputScale")
                filtPinch.setValue(retImage, forKey: kCIInputImageKey)
                filtPinch.setValue(CIVector(cgPoint: f.mouthPosition), forKey: "inputCenter")
                retImage = filtPinch.outputImage!
                //show text if smiling
                if(f.hasSmile){
                    print("Smiling")
                }
            }
            
        }
        return retImage
    }
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        //let optsFace = [CIDetectorImageOrientation:self.videoManager.getImageOrientationFromUIOrientation(UIApplication.sharedApplication().statusBarOrientation)]
        let optsDetector = [CIDetectorImageOrientation:self.videoManager.ciOrientation, CIDetectorAccuracy:CIDetectorAccuracyHigh,CIDetectorTracking:true, CIDetectorSmile:true, CIDetectorEyeBlink:true] as [String : Any]
        // get Face Features
        return self.detector.features(in: img, options: optsDetector) as! [CIFaceFeature]
        
    }
    
    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case UISwipeGestureRecognizerDirection.left:
            self.bridge.processType += 1
        case UISwipeGestureRecognizerDirection.right:
            self.bridge.processType -= 1
        default:
            break
            
        }
        
        stageLabel.text = "Stage: \(self.bridge.processType)"

    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        self.videoManager.toggleFlash()
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }
   
}






//func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
//    var retImage = inputImage
//    
//    var maskImage:CIImage? = CIImage()
//    let bwFilter = CIFilter(name:"CIPhotoEffectNoir")
//    bwFilter?.setValue(inputImage, forKey: kCIInputImageKey)
//
//    for f in features {
//        let extent = CIVector(x:retImage.extent.origin.x, y:retImage.extent.origin.y, z:retImage.extent.size.width, w:retImage.extent.size.height)
//
//        
//
//        let radius = 10.0 //CGFloat(min(f.bounds.size.width, f.bounds.size.height) / 2.0);
//        var filterCenter = CGPoint()
//        //set where to apply filter
//        filterCenter.x = f.bounds.midX
//        filterCenter.y = f.bounds.midY
//        
//        let gradient = CIFilter(name:"CIRadialGradient", withInputParameters:["inputRadius0":radius, "inputRadius1":radius+1.0, "inputColor0":CIColor.green, "inputColor1":CIColor.clear, kCIInputCenterKey:filterCenter])
//
//        //            gradient?.setValue(radius, forKey: "inputRadius0")
//        //            gradient?.setValue(radius+1.0, forKey: "inputRadius1")
//        //            gradient?.setValue(CIColor.green, forKey: "inputColor0")
//        //            gradient?.setValue(CIColor.red, forKey: "inputColor1")
//        //            gradient?.setValue(filterCenter, forKey: kCIInputCenterKey)
//
//        let circleImage:CIImage = gradient?.value(forKey: kCIOutputImageKey) as! CIImage
//
//        if (nil==maskImage){
//            maskImage = circleImage
//        } else {
//            let maskFilt = CIFilter(name:"CISourceOverCompositing")
//            maskFilt?.setValue(circleImage, forKey: kCIInputImageKey)
//            maskFilt?.setValue(maskImage, forKey: kCIInputBackgroundImageKey)
//            maskImage = (maskFilt?.value(forKey: kCIOutputImageKey) as! CIImage)
//        }
//
//        //do for each filter (assumes all filters have property, "inputCenter")
//        //            for filt in filters{
//        //                filt.setValue(retImage, forKey: kCIInputImageKey)
//        //                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
//        //                filt.setValue(CIColor.white, forKey: kCIInputColorKey)
//        //                // could also manipualte the radius of the filter based on face size!
//        //                retImage = filt.outputImage!
//        //            }
//    }
//    let blendFilter = CIFilter(name:"CIBlendWithMask")
//    blendFilter?.setValue(bwFilter?.value(forKey: kCIOutputImageKey) as! CIImage, forKey: kCIInputImageKey)
//    blendFilter?.setValue(retImage, forKey: kCIInputBackgroundImageKey)
//    blendFilter?.setValue(maskImage, forKey: kCIInputMaskImageKey)
//
//    return blendFilter?.value(forKey: kCIOutputImageKey) as! CIImage
//}

