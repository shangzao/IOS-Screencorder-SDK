# IOS-Screencorder-SDK

   本SDK需要导入的外部依赖库为AssetsLibrary.framework;
   AudioToolbox.framework;AVFoundation.framework;CoreGraphics.framework;CoreMedia.framework;CoreVideo.framework;Foundation.framework;OpenGLES.framework;QuartCore.framework;
    
    此外录制代码嵌入案例代码可以如下：
    Gamecorder* gamecorder= [Gamecorder getInstance:_unityView];
    //NSLog(@"%d is supported", [gamecorder isSupported]);
    [gamecorder setMinRecordingSeconds:10];
    [gamecorder setMaxRecordingSeconds:30];   
    //[gamecorder setVideoQuality:GSVideoQualityNormal];
    [gamecorder setVideoQuality:GSVideoQualityGood];
    [gamecorder setVideoFrameRate:1];              //每秒60帧
    //[gamecorder setVoiceOverlayEnabled:NO];
    [gamecorder startRecording];

