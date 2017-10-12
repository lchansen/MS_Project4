
#import "OpenCVBridgeSub.h"
#import "CircularBuffer.h"
#import "PeakFinder.h"
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

//- (NSArray *)butterworthBandpassFilter:(float *)inputData
//{
//    const int NZEROS = 8;
//    const int NPOLES = 8;
//    static float xv[NZEROS+1], yv[NPOLES+1];
//
//    // http://www-users.cs.york.ac.uk/~fisher/cgi-bin/mkfscript
//    // Butterworth Bandpass filter
//    // 4th order
//    // sample rate - varies between possible camera frequencies. Either 30, 60, 120, or 240 FPS
//    // corner1 freq. = 0.667 Hz (assuming a minimum heart rate of 40 bpm, 40 beats/60 seconds = 0.667 Hz)
//    // corner2 freq. = 4.167 Hz (assuming a maximum heart rate of 250 bpm, 250 beats/60 secods = 4.167 Hz)
//    // Bandpass filter was chosen because it removes frequency noise outside of our target range (both higher and lower)
//    double dGain = 1.232232910e+02;
//
//    NSMutableArray *outputData = [[NSMutableArray alloc] init];
//    for (int i = 0; i < 100; i++)
//    {
//        double input = inputData[i];
//
//        xv[0] = xv[1]; xv[1] = xv[2]; xv[2] = xv[3]; xv[3] = xv[4]; xv[4] = xv[5]; xv[5] = xv[6]; xv[6] = xv[7]; xv[7] = xv[8];
//        xv[8] = input / dGain;
//        yv[0] = yv[1]; yv[1] = yv[2]; yv[2] = yv[3]; yv[3] = yv[4]; yv[4] = yv[5]; yv[5] = yv[6]; yv[6] = yv[7]; yv[7] = yv[8];
//        yv[8] =   (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4]
//        + ( -0.1397436053 * yv[0]) + (  1.2948188815 * yv[1])
//        + ( -5.4070037946 * yv[2]) + ( 13.2683981280 * yv[3])
//        + (-20.9442560520 * yv[4]) + ( 21.7932169160 * yv[5])
//        + (-14.5817197500 * yv[6]) + (  5.7161939252 * yv[7]);
//
//        [outputData addObject:@(yv[8])];
//    }
//
//    return outputData;
//}
@end

