//
//  Gamecorder.h
//  Buaa
//
//  Created by 苹果 on 15/3/16.
//  Copyright (c) 2015年 beihanggmj@gmail.com. All rights reserved.
//

#ifndef Buaa_Gamecorder_h
#define Buaa_Gamecorder_h


#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>
#import <AVFoundation/AVFoundation.h>

typedef enum {
    GSVideoQualityNormal = 0,
    GSVideoQualityGood   = 1
}GSVideoQuality;


#define DEFAULT_FRAME_INTERVAL 1  // 默认每秒 60/DEFAULT_FRAME_INTERVAL的抓屏帧率
#define MIN_RECORDING_TIME 10     // 默认10秒，以秒为单位
#define MAX_RECORDING_TIME 20     // 默认20秒，以秒为单位
//#define  IOS8_AND_PREVISOUS     //IOS8.0以上且OpenGL ES3.0环境, 默认为OpenGL2.0，将该宏定义注释掉


@interface Gamecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>
{
}
////////////////////////////////////////////////
///              对外接口
////////////////////////////////////////////////
+ (id) getInstance:(UIView*)view :(GLuint) target :(BOOL) isU3D; //第一次实例化

+ (id) shareInstance;     //获取单例实例

- (void) startRecording;  //开始录制视频

- (void) stopRecording;  //停止录制视频

- (void) pauseRecording; //暂停录制视频

- (void) resumeRecording; //恢复录制视频

- (bool) isRecording;          //当前录制行为是否开启

- (bool) isPaused; //当前录制已经开始时，是否处在暂停状态(StartRecording 方法已经调用，但是用户调用了PauseRecording（）导致framework流暂停)

- (bool) isSupported; //当前接入SDK时，系统是否支持录制视频

- (bool) voiceOverlayEnabled; //当前录制时，声音采集功能是否已经由用户打开（如果返回true，那么录制时将加入游戏声音，反之则视频文件中只有视频没有声音）

- (void) setMinRecordingSeconds: (CFTimeInterval) min; //设置最小录制时长

- (void) setMaxRecordingSeconds: (CFTimeInterval) max;//设置最大录制时长

- (void) setVideoFrameRate:(int)interval; // 设置录制的视频帧率

- (void) setVoiceOverlayEnabled : (BOOL) flag; //设置当前录制视频时是否支持声音

- (const char*) getLastRecordingFile; //获取最后一次用户录制成功的视频的绝对路径

- (const char*) getDisableReason; //获取当前SDK接入后，不支持录制的原因

- (void) setVideoQuality :(GSVideoQuality) quality; //设置视频质量

///////////////////////////////////////////////////
@end


#endif
