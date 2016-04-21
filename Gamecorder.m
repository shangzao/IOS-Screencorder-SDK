//
//  Gamecorder.m
//  Buaa
//
//  Created by 苹果 on 15/3/16.
//  Copyright (c) 2015年 beihanggmj@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Gamecorder.h"
#import <AssetsLibrary/AssetsLibrary.h>

//全都注释表示总的CPU占有率
//#define DELETE_VIDEO_CODER       //测试抓屏部分的CPU占有率

#define FULL_SCREEN_WIDTH   1360
#define FULL_SCREEN_IPHONE6 1334
#define PIXEL_BUFFER_GROUP  2
#define PIXEL_BUFFER_NUMBER 20

@interface Gamecorder ()
{
    CADisplayLink* _frameCaptureLink;
    
    GLuint pboIds[PIXEL_BUFFER_GROUP];
    AVAssetWriter* videoWriter;
    AVAssetWriterInput* writerInput;
    AVAssetWriterInputPixelBufferAdaptor* adaptor;
    
    dispatch_queue_t _dispatchqueue;
    int width;
    int height;
    CFTimeInterval minRecordingtime;
    CFTimeInterval maxRecordingtime;
    
    BOOL isCapture;
    CMTime _presentationTime;
    BOOL isAudio;
    BOOL isAllStart;
    BOOL isVideoStartWritring;
    BOOL isAudioEnabled;
    
    /// 音频部分变量
    CMFormatDescriptionRef _currentAudioSampleBufferFormatDescription;
    AVCaptureDevice* _audioDevice;
    AVCaptureSession* _captureSession;
    AVAssetWriterInput* _assetWriterAudioInput;
    
    UIBackgroundTaskIdentifier _backgroundRecordingID;
    CMTime _timeStamp;
    GLubyte* colorBuffer;
    CFTimeInterval startTime;
    BOOL _isRecording;
    bool isPaused;
    GSVideoQuality videoquailty;
    int frameInterval;
    BOOL firstTime;
    NSString *reason;
    const char *outputfile;
    
    ///
    BOOL isU3d;
    GLuint targetFB;
    NSString*	_DeviceModel;
    int			_DeviceGeneration;
}
- (id) initGamecorder:(UIView *) view:(GLuint) target :(BOOL) isU3D; //私有构造函数
- (void) initPixelBufferobject;
- (void) initFrame;
- (void) captureFrame: (CADisplayLink*) displayLink;
- (void) initAssetWriter;
- (void) startCapture;
- (void) finishCapture;
- (BOOL) existsFile: (NSString*) filename;
- (NSURL* ) outputFileURL;
- (void) abortWriting;
- (void) toggleFrameLink;
- (void) setTargetFB: (GLuint) tartget;   // 设置目标TargetFB
- (void) QueryDeviceModel;
- (void) QueryDeviceGeneration;
@end

static Gamecorder* sharedInstance=nil;  //单例模式，实例变量


///iPhone 所有设备枚举类型;
//////-------------------------------------------///////////////
typedef enum
GuluDeviceGeneration
{
    GuludeviceUnknown = 0,
    GuludeviceiPhone = 1,
    GuludeviceiPhone3G = 2,
    GuludeviceiPhone3GS = 3,
    GuludeviceiPodTouch1Gen = 4,
    GuludeviceiPodTouch2Gen = 5,
    GuludeviceiPodTouch3Gen = 6,
    GuludeviceiPad1Gen = 7,
    GuludeviceiPhone4 = 8,
    GuludeviceiPodTouch4Gen = 9,
    GuludeviceiPad2Gen = 10,
    GuludeviceiPhone4S = 11,
    GuludeviceiPad3Gen = 12,
    GuludeviceiPhone5 = 13,
    GuludeviceiPodTouch5Gen = 14,
    GuludeviceiPadMini1Gen = 15,
    GuludeviceiPad4Gen = 16,
    GuludeviceiPhone5C = 17,
    GuludeviceiPhone5S = 18,
    GuludeviceiPad5Gen = 19,
    GuludeviceiPadMini2Gen = 20,
    GuludeviceiPhone6 = 21,
    GuludeviceiPhone6Plus = 22,
    GuludeviceiPhoneUnknown = 10001,
    GuludeviceiPadUnknown = 10002,
    GuludeviceiPodTouchUnknown = 10003,
}GuluDeviceGeneration;
//////------------------------------------------/////////////////


@implementation Gamecorder
{
    UIView* _view;
    CFAbsoluteTime firstFrameTime;
    CFTimeInterval startTimestamp;
}

- (void) QueryDeviceModel
{
    if(_DeviceModel == nil)
    {
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        
        char* model = (char*)malloc(size + 1);
        sysctlbyname("hw.machine", model, &size, NULL, 0);
        model[size] = 0;
        
        _DeviceModel = [[NSString stringWithUTF8String:model] retain];
        free(model);
    }
}

- (void) QueryDeviceGeneration
{
    if(_DeviceGeneration == deviceUnknown)
    {
        [self QueryDeviceModel];
        const char* model = [_DeviceModel UTF8String];
        
        NSLog(@"device : %s",model);
        
        if (!strcmp(model, "iPhone2,1"))
            _DeviceGeneration = GuludeviceiPhone3GS;
        else if (!strncmp(model, "iPhone3,",8))
            _DeviceGeneration = GuludeviceiPhone4;
        else if (!strncmp(model, "iPhone4,",8))
            _DeviceGeneration = GuludeviceiPhone4S;
        else if (!strncmp(model, "iPhone6,",8))
            _DeviceGeneration = GuludeviceiPhone5S;
        else if (!strncmp(model, "iPhone7,2",9))
            _DeviceGeneration = GuludeviceiPhone6;
        else if (!strncmp(model, "iPhone7,1",9))
            _DeviceGeneration = GuludeviceiPhone6Plus;
        else if (!strcmp(model, "iPod1,1"))
            _DeviceGeneration = GuludeviceiPodTouch1Gen;
        else if (!strcmp(model, "iPod2,1"))
            _DeviceGeneration = GuludeviceiPodTouch2Gen;
        else if (!strcmp(model, "iPod3,1"))
            _DeviceGeneration = GuludeviceiPodTouch3Gen;
        else if (!strcmp(model, "iPod4,1"))
            _DeviceGeneration = GuludeviceiPodTouch4Gen;
        else if (!strncmp(model, "iPod5,",6))
            _DeviceGeneration = GuludeviceiPodTouch5Gen;
        else if (!strcmp(model, "iPad1,1"))
            _DeviceGeneration = GuludeviceiPad1Gen;
        
        // check iphone5c, ipad2 and ipad3 separately - they are special cases as apple reused major ver for different hws
        if(_DeviceGeneration == GuludeviceUnknown)
        {
            if (!strncmp(model, "iPhone5,",8))
            {
                int rev = atoi(model+8);
                if (rev >= 3) _DeviceGeneration = GuludeviceiPhone5C; // iPhone5,3
                else		  _DeviceGeneration = GuludeviceiPhone5;
            }
            else if (!strncmp(model, "iPad2,", 6))
            {
                int rev = atoi(model+6);
                if(rev >= 5)	_DeviceGeneration = GuludeviceiPadMini1Gen; // iPad2,5
                else			_DeviceGeneration = GuludeviceiPad2Gen;
            }
            else if (!strncmp(model, "iPad3,", 6))
            {
                int rev = atoi(model+6);
                if(rev >= 4)	_DeviceGeneration = GuludeviceiPad4Gen; // iPad3,4
                else			_DeviceGeneration = GuludeviceiPad3Gen;
            }
            else if (!strncmp(model, "iPad4,", 6))
            {
                int rev = atoi(model+6);
                if(rev >= 4)	_DeviceGeneration = GuludeviceiPadMini2Gen; // iPad4,4
                else			_DeviceGeneration = GuludeviceiPad5Gen;
            }
        }
        
        // completely unknown hw - just determine form-factor
        if(_DeviceGeneration == deviceUnknown)
        {
            if (!strncmp(model, "iPhone",6))
                _DeviceGeneration = GuludeviceiPhoneUnknown;
            else if (!strncmp(model, "iPad",4))
                _DeviceGeneration = GuludeviceiPadUnknown;
            else if (!strncmp(model, "iPod",4))
                _DeviceGeneration = GuludeviceiPodTouchUnknown;
            else
                _DeviceGeneration = GuludeviceUnknown;
        }
    }
}




- (void) setTargetFB: (GLuint) tartget
{
    targetFB = tartget;
}

//当前接入SDK时，系统是否支持录制视频
- (bool) isSupported
{
    if(_view!=nil)
    {
        //_view.pixelformat_;
        CAEAGLLayer* layer= (CAEAGLLayer*)_view.layer;
        if(layer!=nil)
        {
            NSDictionary* dic=layer.drawableProperties;
            if([dic objectForKey:kEAGLDrawablePropertyColorFormat] == kEAGLColorFormatRGBA8)
            {
                return  YES;
            }else{
                reason=@"CAEAGLLayer kEAGLDrawablePropertyColorFormat is not kEAGLColorFormatRGBA8";
                return NO;
            }
            
        }
    }
    return NO;
}
- (const char*) getDisableReason
{
    return reason.UTF8String;
}
- (bool) voiceOverlayEnabled
{
    return isAudioEnabled;
    
}
- (void) setVoiceOverlayEnabled: (BOOL) flag
{
     isAudioEnabled= flag;
}

- (void) setVideoQuality: (GSVideoQuality) quality
{
    videoquailty=quality;
}
// 1,2,3,4,5
- (void) setVideoFrameRate:(int)interval
{
    frameInterval = interval;
}
- (void) startRecording
{
    [self startCapture];
}
- (void) stopRecording
{
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    CFTimeInterval elapsedTime = currentTime - firstFrameTime;
    
    if(elapsedTime<minRecordingtime)
        return;
    
    [self finishCapture];
}
- (const char*) getLastRecordingFile
{
    return outputfile;
}

- (void) abortWriting  //错误中断
{
    if(!videoWriter)
        return;
    
    [videoWriter cancelWriting];
    
    if(_captureSession!=nil && _captureSession.isRunning)
        [_captureSession stopRunning];
    
    //timer
    if(_frameCaptureLink!=nil)
       [self toggleFrameLink];
    
    writerInput = nil;
    
    _assetWriterAudioInput = nil;
    
    videoWriter = nil;
    
    _captureSession = nil;
    
}
- (void) pauseRecording
{
    _isRecording = NO;
    isAllStart = NO;
    isCapture = NO;
    
    if(_captureSession!=nil && _captureSession.isRunning)
       [_captureSession stopRunning];
    
    if(_frameCaptureLink !=nil)
       [self toggleFrameLink];
    
    CFRetain(_captureSession);
    CFRetain(videoWriter);
    CFRetain(writerInput);
    CFRetain(adaptor);
    CFRetain(_assetWriterAudioInput);
    isPaused= YES;
}

- (void) resumeRecording
{
    _isRecording = YES;
    isAllStart = YES;
    isCapture = YES;
    
    if(_captureSession!=nil && !_captureSession.isRunning)
        [_captureSession startRunning];
    if(_frameCaptureLink == nil)
        [self toggleFrameLink];
    
    isPaused= NO;
}
- (bool) isPaused
{
    return isPaused;
}

- (bool) isRecording
{
    return isAllStart && isCapture && _isRecording;
}


- (void) setMinRecordingSeconds: (CFTimeInterval) min //设置最小录制时长
{
    minRecordingtime=min;
}
- (void) setMaxRecordingSeconds: (CFTimeInterval) max//设置最大录制时长
{
    maxRecordingtime=max;
}

//传入UIView实例，设置被截屏的View对象
- (id) initGamecorder:(UIView *)view : (GLuint) target :(BOOL) isU3D
{
    isU3d=isU3D;
    _DeviceModel =nil;
    _DeviceGeneration =GuludeviceUnknown;
    _view = view;
    reason=@"";
    [self QueryDeviceGeneration];
    [self setTargetFB:target];
    if(_view)
    {
        [self initFrame];
        [self initPixelBufferobject];
        _dispatchqueue = dispatch_queue_create("dis_queue", NULL);
        colorBuffer= malloc(sizeof(GLubyte)*width*height*4);
    }else{
        //NSLog(@"view is nil");
        reason = @"View is nil";
    }
    return  self;
}
+ (id) getInstance: (UIView*) view: (GLuint) target :(BOOL) isU3D
{
    @synchronized(self)
    {
        if(sharedInstance ==nil)
        {
            sharedInstance=[[Gamecorder alloc] initGamecorder:view: target : isU3D];
        }
    }
    return sharedInstance;
}

+ (id) shareInstance  //获取单例实例
{
    return sharedInstance;
}

- (void) initFrame
{
    if(_view!=nil)
    {
        int inter_width= _view.frame.size.width * _view.layer.contentsScale;
        int inter_height = _view.frame.size.height* _view.layer.contentsScale;
        
        
        width = inter_width+(inter_width)%4;       // 设置视频宽度分辨率
        height= inter_height;                      // 设置视频高度分辨率
        
        if(_DeviceGeneration==GuludeviceiPhone6 && width>=FULL_SCREEN_IPHONE6)
        {
            width=FULL_SCREEN_WIDTH;
        }
        minRecordingtime = MIN_RECORDING_TIME;
        maxRecordingtime = MAX_RECORDING_TIME;
        
        //NSLog(@"frame width: %d; frame height: %d",inter_width,inter_height);
        NSLog(@"w %d; h %d",width,height);
    }
    else{
        //NSLog(@"The UIView object is NULL");
        reason = @"View is nil";
    }
    isAudioEnabled = YES;
    firstTime = YES;
    isAllStart = NO;
    isAudio = NO;
    isVideoStartWritring = NO;
    _isRecording = NO;
    isPaused=NO;
    videoquailty = GSVideoQualityNormal;
    frameInterval = DEFAULT_FRAME_INTERVAL;
}

- (void) startCapture
{
    startTime = CFAbsoluteTimeGetCurrent();
    [self toggleFrameLink];
    [self initAssetWriter];
    isAllStart = YES;
    _isRecording = YES;
}

- (BOOL)existsFile:(NSString *)filename
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:filename];
    NSFileManager* fileManager = [[NSFileManager alloc] init];
    BOOL isDirectory;
    return [fileManager fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory;
}
- (NSURL* ) outputFileURL
{
    NSString* filename = @"output.mov";
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:filename];
    if([self existsFile: filename])
    {
        [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:path] error:NULL];
    }
    return [NSURL fileURLWithPath:path];
}
- (void) finishCapture
{
    _isRecording = NO;
    
    isCapture=NO;
    
    isAllStart=NO;
    
    dispatch_async(_dispatchqueue, ^(void){
        
    if(self->videoWriter.status!= AVAssetWriterStatusCompleted && self->videoWriter.status != AVAssetWriterStatusUnknown)
    {
        [self->videoWriter finishWritingWithCompletionHandler:^(void){
                if(self->videoWriter.status == AVAssetWriterStatusCompleted)
                {
                        if (_captureSession!=nil && _captureSession.isRunning)
                        {
                            _captureSession = nil;
                            [_captureSession stopRunning];
                        }
                    
                        [self toggleFrameLink];
                    
                        NSURL* fileURL = [videoWriter outputURL];
                        ALAssetsLibrary * library = [[ALAssetsLibrary alloc] init];
                        [library writeVideoAtPathToSavedPhotosAlbum:fileURL completionBlock:^(NSURL * assetURL, NSError * error){
                            outputfile = fileURL.fileSystemRepresentation;
                            NSLog(@"path %s",outputfile);
                            //[[NSFileManager defaultManager] removeItemAtURL:fileURL error: NULL];
                        
                        }];
                    
                }
        }];
    }
    NSLog(@"stopRecording");
    });
}

- (void) initAssetWriter
{
    NSError* error=nil;
    
    
    videoWriter=[[AVAssetWriter alloc] initWithURL:[self outputFileURL] fileType:AVFileTypeQuickTimeMovie error:
                 &error];
    
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoCompressionSettings = nil;
    
    int w = width;
    int h=  height;
    
    if(videoquailty == GSVideoQualityNormal)
    {
        videoCompressionSettings= [NSDictionary dictionaryWithObjectsAndKeys:
                                              AVVideoCodecH264, AVVideoCodecKey,
                                              [NSNumber numberWithInteger: w/2], AVVideoWidthKey,
                                              [NSNumber numberWithInteger: h/2], AVVideoHeightKey,
                                              nil];
    }else
    {
        if(_DeviceGeneration == GuludeviceiPhone6Plus)
        {
            w=w/2;
            h=h/2;
        }
        videoCompressionSettings= [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInteger: w], AVVideoWidthKey,
                                   [NSNumber numberWithInteger: h], AVVideoHeightKey,
                                   nil];
    }
    
    writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
    writerInput.expectsMediaDataInRealTime = YES;
    
    //视频放射变换
    CGAffineTransform t1 = CGAffineTransformMake(-1, 0, 0, 1, 0, 0);
    CGAffineTransform t2 = CGAffineTransformMakeRotation(M_PI);
    CGAffineTransform t3 = CGAffineTransformMakeRotation(-M_PI_2);
    if(width>height)
    {
        writerInput.transform = CGAffineTransformConcat(t3, CGAffineTransformConcat(t1, t2));
    }else{
        writerInput.transform = CGAffineTransformConcat(t1, t2);
    }
    adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:
               [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInteger:kCVPixelFormatType_32BGRA], (id)kCVPixelBufferPixelFormatTypeKey,
                [NSNumber numberWithUnsignedInteger: width], (id)kCVPixelBufferWidthKey,
                [NSNumber numberWithUnsignedInteger:height], (id)kCVPixelBufferHeightKey,
                (id)kCFBooleanTrue, (id)kCVPixelFormatOpenGLESCompatibility,
                nil]];
    
    
    CFRetain(adaptor);
    //assert(adaptor != nil);
    
    
    
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    [videoWriter addInput:writerInput];
    
    //音频部分
    if([[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] count] >0)
    {
        NSArray* audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
        if([audioDevices count])
            _audioDevice = [audioDevices objectAtIndex:0];
    }
    
    AVCaptureDeviceInput* audioDeviceInput = nil;
    if(_audioDevice){
        audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_audioDevice error:&error];
        if(!audioDeviceInput)
        {
            //NSLog(@"error audioDeviceInput");
            reason = @"audioDecieInput error";
            [self abortWriting];
            return;
        }
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    AVCaptureAudioDataOutput* audioDataOutput = nil;
    if(_audioDevice)
    {
        audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
        [audioDataOutput setSampleBufferDelegate:self queue:_dispatchqueue];
    }
    
    [_captureSession beginConfiguration];
    
    if(audioDataOutput)
    {
        if(![_captureSession canAddOutput:audioDataOutput])
        {
            //NSLog(@"addAudioOutput error");
            reason = @"addAudioOutput error";
            [self abortWriting];
            _captureSession  = nil;
            return;
        }
    }
    if(_audioDevice)
    {
        [_captureSession addInput:audioDeviceInput];
        [_captureSession addOutput:audioDataOutput];
    }
    else{
        //NSLog(@"_audioDevice is nil");
        reason = @"audioDevice is nil";
        [self abortWriting];
    }
    [_captureSession commitConfiguration];
    
    
    [_captureSession startRunning];

    
    //end
    isCapture=NO;
}
- (void) initPixelBufferobject
{
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    
    glEnable(GL_TEXTURE_2D);
    
    
    int channel_count =4;
    int DATA_SIZE=width*height*channel_count;
    
    
    
    glGenBuffers(PIXEL_BUFFER_GROUP, pboIds);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, pboIds[0]);
    glBufferData(GL_PIXEL_PACK_BUFFER, DATA_SIZE, 0, GL_STREAM_READ);
    
    
    glBindBuffer(GL_PIXEL_PACK_BUFFER, pboIds[1]);
    glBufferData(GL_PIXEL_PACK_BUFFER, DATA_SIZE, 0, GL_STREAM_READ);
    
    
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    
}

- (void) toggleFrameLink
{

    if(_frameCaptureLink == nil)
    {
        _frameCaptureLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(captureFrame:)];
        _frameCaptureLink.frameInterval=frameInterval;
        [_frameCaptureLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
    }else
    {
        [_frameCaptureLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_frameCaptureLink invalidate];
        _frameCaptureLink = nil;
    }

    
}

- (void) captureFrame:(CADisplayLink *)displayLink
{
    static int index = 0;
    int nextIndex = 0;
    
    index = (index +1)%2;
    nextIndex = (index+1)%2;

    
    if(isCapture)
    {
#ifdef IOS8_AND_PREVISOUS
    
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pboIds[index]);
        
        if(_DeviceGeneration == GuludeviceiPhone6Plus && isU3d)
        {
            glBindFramebuffer(GL_READ_FRAMEBUFFER, targetFB);
        }
        glReadPixels(0,0, width,height, GL_BGRA, GL_UNSIGNED_BYTE,0);
    
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pboIds[nextIndex]);
    
        GLubyte* src=(GLubyte*)glMapBufferRange(GL_PIXEL_PACK_BUFFER,0,width*(height)*4, GL_MAP_READ_BIT);
    
        if(src == nil)
        {
            //NSLog(@"glMapBufferRange is nil");
            reason = @"glMapBufferRange is nil";
            [self abortWriting];
            return;
        }
#endif
    

    
        if(self->writerInput.readyForMoreMediaData)
        {
            CVPixelBufferRef buffer = NULL;
            CVReturn sta = kCVReturnSuccess;
            
            if(adaptor!=nil)
                 sta= CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool, &buffer);
            else
            {
                //NSLog(@"adaptor is nil");
                reason = @"adaptor is nil";
                [self abortWriting];
            }
            
            if((buffer == NULL) || (sta!= kCVReturnSuccess))
            {
                //NSLog(@"Create PixelBuffer Error");
                reason = @"create pixelbuffer error";
                [self abortWriting];
                return;
            }
            
            CVPixelBufferLockBaseAddress(buffer, 0);
            GLubyte* pixelBufferData =(GLubyte* ) CVPixelBufferGetBaseAddress(buffer);
            
    #ifdef IOS8_AND_PREVISOUS
            
            memcpy(pixelBufferData, src, width*height*4);
    #else
            if(_DeviceGeneration == GuludeviceiPhone6Plus && isU3d)
            {
                glBindFramebuffer(GL_READ_FRAMEBUFFER, targetFB);
            }
            glReadPixels(0, 0, width, height, GL_BGRA, GL_UNSIGNED_BYTE, pixelBufferData);
    #endif
            //NSLog(@"pixel Data : %d %d %d %d",pixelBufferData[0],pixelBufferData[1],pixelBufferData[2],pixelBufferData[3]);
            if(_isRecording && buffer){
                CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                CFTimeInterval elapsedTime = currentTime - firstFrameTime;
                
                CMTime presentTime = CMTimeMake(elapsedTime * 1000000000+_timeStamp.value,1000000000);
    #ifndef DELETE_VIDEO_CODER
                if(elapsedTime > maxRecordingtime)
                {
                    [self finishCapture];
                    
                }else{
                        if(![adaptor appendPixelBuffer:buffer withPresentationTime:presentTime])
                        {
                            [self finishCapture];
                        }
                    
                }
     #else
     #endif
                CVPixelBufferUnlockBaseAddress(buffer, 0);
                CVPixelBufferRelease(buffer);
                
            }
        }

    }

    glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
}



#pragma mark - Delegate methods
- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDesc);
    
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    _currentAudioSampleBufferFormatDescription = formatDesc;
    
    
    if(!isAudio && _audioDevice)
    {
        size_t layoutSize = 0;
        const AudioChannelLayout* channelLayout = CMAudioFormatDescriptionGetChannelLayout(_currentAudioSampleBufferFormatDescription, &layoutSize);
        const AudioStreamBasicDescription* basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(_currentAudioSampleBufferFormatDescription);
        
        NSData* channelLayoutData = [NSData dataWithBytes:channelLayout length:layoutSize];
        
        NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                                  [NSNumber numberWithInteger:basicDescription->mChannelsPerFrame], AVNumberOfChannelsKey,
                                                  [NSNumber numberWithFloat:basicDescription->mSampleRate], AVSampleRateKey,
                                                  [NSNumber numberWithInteger:64000], AVEncoderBitRateKey,
                                                  channelLayoutData, AVChannelLayoutKey,
                                                  nil];
        
        if([videoWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio])
        {
            _assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
            _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
            
            if([videoWriter canAddInput:_assetWriterAudioInput])
            {
                [videoWriter addInput:_assetWriterAudioInput];
                isAudio=YES;
            }
            else
            {
                //NSLog(@"asset writer audio error");
                reason = @"add audioinput into asset writer error";
                [self abortWriting];
            }
        }else
        {
            //NSLog(@"apply audio output setting error");
            reason = @"apply audio output setting error";
            [self abortWriting];
        }
        
    }
    if(firstTime)
    {
        
        ////////////////////////////////////////////////////////
        firstFrameTime = CFAbsoluteTimeGetCurrent();
        
        
        [videoWriter startWriting];
        
        [videoWriter startSessionAtSourceTime:timestamp];
        
        //NSLog(@"timestamp scale :%d. value %lld ", timestamp.timescale, timestamp.value);
        
        isCapture = YES;
        
        _timeStamp = timestamp;
        /////////////////////////////////////////////////////////
        firstTime = NO;
    }
    
    if(!isAllStart)
    {
        return;
    }
    
    if(!isAudioEnabled)
    {
        if(_captureSession!=nil && _captureSession.isRunning)
        {
            [_captureSession stopRunning];
            _captureSession = nil;
        }
        return;
    }
    
    
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    CFTimeInterval elapsedTime = currentTime - firstFrameTime;
    
#ifndef DELETE_VIDEO_CODER
    
    if(elapsedTime >maxRecordingtime)
    {
        [self finishCapture];
    }
    else
    {
        if (_isRecording && mediaType == kCMMediaType_Audio)
        {
            
            
            if (videoWriter &&
                _assetWriterAudioInput.readyForMoreMediaData &&
                ![_assetWriterAudioInput appendSampleBuffer:sampleBuffer])
            {
                //[self _showAlertViewWithMessage:@"Cannot write audio data, recording aborted"];
                //[self _abortWriting];
                //NSLog(@"audio error");
                reason = @"audio error, cannot write audio data";
                [self abortWriting];
            }
            
        }
    }
#else
#endif
    //NSLog(@"timestamp scale :%d. value %lld ", timestamp.timescale, timestamp.value);
    
    
}

@end





