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
    //we'll be using the BridgeSub to handle the heart rate stuff (Module B), and this ViewController to handle the face stuff (Module A)
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
        
        // Dynamically switch to Module B if there are no faces and the bacl=k camera is active
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
        //Go to Module A of we detect faces on either the front or back camera
        retImage = self.applyFiltersToFaces(inputImage: retImage, features: f)
        return retImage
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
            filterCenter.x = f.bounds.midX
            filterCenter.y = f.bounds.midY
            
            //do for each filter (assumes all filters have property, "inputCenter")
            for filt in filters{
                filt.setValue(retImage, forKey: kCIInputImageKey)
                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                // could also manipualte the radius of the filter based on face size!
                retImage = filt.outputImage!
            }
            
            //After the face is bumped, we need to highlight eyes and mouth by "pinching them"
            let filtPinch = CIFilter(name:"CIPinchDistortion")!
            filtPinch.setValue(0.25, forKey: "inputScale")
            filtPinch.setValue(75, forKey: "inputRadius")
            
            if(f.hasLeftEyePosition){
                //put filter over eye
                filtPinch.setValue(retImage, forKey: kCIInputImageKey)
                filtPinch.setValue(CIVector(cgPoint: f.leftEyePosition), forKey: "inputCenter")
                retImage = filtPinch.outputImage!
                //display if Left eye blinking
                if(f.leftEyeClosed){
                    print("Left Eye Blinking")
                }
            }
            if(f.hasRightEyePosition){
                //put filter over eye
                filtPinch.setValue(retImage, forKey: kCIInputImageKey)
                filtPinch.setValue(CIVector(cgPoint: f.rightEyePosition), forKey: "inputCenter")
                retImage = filtPinch.outputImage!
                //display if Right eye blinking
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
                //display if Smiling
                if(f.hasSmile){
                    print("Smiling")
                }
            }
        }
        return retImage
    }
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        let optsDetector = [CIDetectorImageOrientation:self.videoManager.ciOrientation, CIDetectorAccuracy:CIDetectorAccuracyHigh,CIDetectorTracking:true, CIDetectorSmile:true, CIDetectorEyeBlink:true] as [String : Any]
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
