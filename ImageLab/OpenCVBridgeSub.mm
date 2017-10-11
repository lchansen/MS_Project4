
#import "OpenCVBridgeSub.h"

#import "AVFoundation/AVFoundation.h"


using namespace cv;

@interface OpenCVBridgeSub()
@property (nonatomic) cv::Mat image;
@property (nonatomic) float* avgR;
@property (nonatomic) float* avgG;
@property (nonatomic) float* avgB;
@property (nonatomic) int count;
@end

@implementation OpenCVBridgeSub
@dynamic image;

-(float*) avgR{
    if(!_avgR){
        _avgR = new float[100];
    }
    return _avgR;
}
-(float*) avgG{
    if(!_avgG){
        _avgG = new float[100];
    }
    return _avgG;
}
-(float*) avgB{
    if(!_avgB){
        _avgB = new float[100];
    }
    return _avgB;
}

//@dynamic just tells the compiler that the getter and setter methods are implemented not by the class itself but somewhere else (like the superclass or will be provided at runtime).

-(void)processImage{
    
    cv::Mat image_copy;
    char text[35];
    Scalar avgPixelIntensity;
    cv::Mat image = self.image;
    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
    avgPixelIntensity = cv::mean( image_copy );
    sprintf(text,"Avg. R: %.0f, G: %.0f, B: %.0f", avgPixelIntensity.val[0],avgPixelIntensity.val[1],avgPixelIntensity.val[2]);
    cv::putText(image, text, cv::Point(50, 50), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);

    //Set threshhold to detect finger
    char text2[16] = "Finger Detected";
    if(avgPixelIntensity.val[0]>235 && avgPixelIntensity.val[1]<45 && avgPixelIntensity.val[2]<45){
        cv::putText(image, text2, cv::Point(50, 200), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);
        if (self.count < 100){
            self.avgR[self.count] = avgPixelIntensity.val[0];
            self.avgG[self.count] = avgPixelIntensity.val[1];
            self.avgB[self.count++] = avgPixelIntensity.val[2];
        } else {
            NSLog(@"Pixel Array is Full!");
            self.count = 0;
        }
        
        
    }
    
    
    
    self.image = image;
    
}

@end
