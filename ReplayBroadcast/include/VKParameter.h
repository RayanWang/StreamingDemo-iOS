//
//  VKParameter.h
//  VoiceKit
//
//  Created by Rayan on 2017/5/26.
//  Copyright © 2017年 Rayan. All rights reserved.
//

#ifndef VKParameter_h
#define VKParameter_h

typedef enum _MKCodecFormat {
    MKCodecFormatSpeex,
    MKCodecFormatCELT,
    MKCodecFormatOpus,
} MKCodecFormat;

typedef enum _MKTransmitType {
    MKTransmitTypeVAD,
    MKTransmitTypeToggle,
    MKTransmitTypeContinuous,
} MKTransmitType;

typedef enum _MKVADKind {
    MKVADKindSignalToNoise,
    MKVADKindAmplitude,
} MKVADKind;

typedef struct _MKAudioSettings {
    MKCodecFormat   codec;
    MKTransmitType  transmitType;
    MKVADKind       vadKind;
    float           vadMax;
    float           vadMin;
    int             quality;
    int             audioPerPacket;
    int             noiseSuppression;
    float           amplification;
    int             jitterBufferSize;
    float           volume;
    int             outputDelay;
    float           micBoost;
    BOOL            enablePreprocessor;
    BOOL            enableEchoCancellation;
    
    BOOL            enableComfortNoise;
    float           comfortNoiseLevel;
    BOOL            enableVadGate;
    double          vadGateTimeSeconds;
    
    BOOL            preferReceiverOverSpeaker;
    BOOL            opusForceCELTMode;
    BOOL            audioMixerDebug;
} MKAudioSettings;


MKAudioSettings MakeInitialAudioSettings() {
    MKAudioSettings settings;
    
    settings.transmitType = MKTransmitTypeVAD;
    settings.vadKind = MKVADKindAmplitude;
    
    settings.vadMin = 0.3;
    settings.vadMax = 0.6;
    
    // Audio Quality
    settings.codec = MKCodecFormatOpus;
    settings.quality = 72000;
    settings.audioPerPacket = 1;
    
    settings.noiseSuppression = -42; /* -42 dB */
    settings.amplification = 20.0;
    settings.jitterBufferSize = 0; /* 10 ms */
    settings.volume = 1.0;
    settings.outputDelay = 0; /* 10 ms */
    settings.micBoost = 1.0;
    settings.enablePreprocessor = true;
    settings.enableEchoCancellation = true;
    
    settings.preferReceiverOverSpeaker = true;
    
    settings.opusForceCELTMode = true;
    settings.audioMixerDebug = false;
    
    return settings;
}

#endif /* VKParameter_h */
