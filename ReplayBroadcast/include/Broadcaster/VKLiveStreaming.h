//
//  VKLiveStreaming.h
//  VoiceKit
//
//  Created by Rayan on 2017/5/23.
//  Copyright © 2017年 Rayan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "VKParameter.h"

@interface VKLiveStreaming : NSObject

+ (instancetype) sharedStreaming;

- (void) initWithSettings:(MKAudioSettings *)settings room:(NSString *)room accountId:(NSString *)accountId url:(NSString *)url;

- (void) start;

- (void) stop;

- (void) addMicrophoneDataWithBuffer:(short *)input amount:(NSUInteger)nsamp;

@end
