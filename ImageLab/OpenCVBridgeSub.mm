
#import "OpenCVBridgeSub.h"
#import "AVFoundation/AVFoundation.h"


using namespace cv;

@interface OpenCVBridgeSub()
@property (nonatomic) cv::Mat image;
@property (nonatomic) float* avgR;
@property (nonatomic) int count;
@property (nonatomic) char* text;
@end

@implementation OpenCVBridgeSub
@dynamic image;

-(float*) avgR{
    if(!_avgR){
        _avgR = new float[200];
    }
    return _avgR;
}

-(char*) text{
    if(!_text){
        _text = new char[20];
    }
    return _text;
}

-(void)processImage{
    
    cv::Mat image_copy;
    Scalar avgPixelIntensity;
    cv::Mat image = self.image;
    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
    avgPixelIntensity = cv::mean( image_copy );
    NSLog(@"%f", avgPixelIntensity[0]);
    
    //Set threshhold to detect finger
    if(avgPixelIntensity.val[0]>230 && avgPixelIntensity.val[1]<50 && avgPixelIntensity.val[2]<50){
        if (self.count < 200){
            self.avgR[self.count++] = avgPixelIntensity.val[0];
        } else {
            //Calculate bpm every 200 frames. At 20fps, this is 10 seconds
            //do peak finding and calculating BPM here
            float bpm = [self calculateBPM:self.avgR];
            sprintf(self.text,"BPM: %.0f", bpm);
            self.count = 0;
        }
    }
    cv::putText(image, self.text, cv::Point(50, 50), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);
    self.image = image;
}
             
             
-(int) calculateBPM:(float*)magBuffer {
    NSMutableArray* peaks = [[NSMutableArray alloc] init];
    //Go through each frame and check to see if it  is a peak
    for(int index = 0;index<200;++index){
        int min = 0;
        int max = 199;
        int window = 8;
        float threshhold = 240.0;
        
        //prevent window from going out of bounds
        if(index-window>min){
            min = index-window;
        }
        //prevent window from going out of bounds
        if(index+window<max){
            max = index+window;
        }
        int maxIndex = min;
        float maxValue = magBuffer[maxIndex];
        for(int x = min;x<=max;++x){
            if(magBuffer[x]>=maxValue && magBuffer[x]>threshhold){
                maxIndex = x;
                maxValue = magBuffer[x];
            }
        }
        if(maxIndex==index){
            [peaks addObject:[NSNumber numberWithInt:index]];
        }
    }
    //now we have a list of the maximum peaks
    //get average distance (in indices) between peaks and convert that to a bpm
    int sumDistances = 0;
    for(int i=1;i<[peaks count];++i){
        sumDistances+= [[peaks objectAtIndex:i] intValue] - [[peaks objectAtIndex:i-1] intValue];
    }
    float avgDistance = sumDistances/(float)[peaks count];
    //20fps*60sec/avgdist
    return 20*60/avgDistance;
}

//-(bool) isPeak:(float*)magBuffer index:(int)index{
//    int min = 0;
//    int max = 199;
//    int window = 10;
//    float threshhold = 245.0;
//    if(index-window>min){
//        min = index-window;
//    }
//    if(index+window<max){
//        max = index+window;
//    }
//
//    int maxIndex = min;
//    float maxValue = magBuffer[maxIndex];
//
//    for(int x = min;x<=max;++x){
//        if(magBuffer[x]>=maxValue && magBuffer[x]>threshhold){
//            maxIndex = x;
//            maxValue = magBuffer[x];
//        }
//    }
//    return (maxIndex==index);
//
//}
@end

