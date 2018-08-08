//
//  SampleHandler.swift
//  ReplayBroadcast
//
//  Created by Rayan on 2017/5/8.
//  Copyright © 2017年 Rayan. All rights reserved.
//

import ReplayKit
import VideoToolbox

//  To handle samples with a subclass of RPBroadcastSampleHandler set the following in the extension's Info.plist file:
//  - RPBroadcastProcessMode should be set to RPBroadcastProcessModeSampleBuffer
//  - NSExtensionPrincipalClass should be set to this class

class SampleHandler: RPBroadcastSampleHandler {
    
    private var broadcaster:RTMPBroadcaster = RTMPBroadcaster()
    
    private let liveStreaming: VKLiveStreaming = VKLiveStreaming.shared()
    
    private var settings: MKAudioSettings = MakeInitialAudioSettings()
    
    public override init() {
        super.init()
        print(self)
    }
    
    deinit {
        print(self)
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension will be supplied.
        print("broadcastStarted")
        super.broadcastStarted(withSetupInfo: setupInfo)
        guard
            let endpointURL:String = setupInfo?["endpointURL"] as? String,
            let streamName:String = setupInfo?["streamName"] as? String else {
                return
        }
        broadcaster.streamName = streamName
        broadcaster.connect(endpointURL, arguments: nil)
        
        liveStreaming.initWith(&settings, room: "", accountId: "", url: "")
        
        liveStreaming.start()
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        liveStreaming.stop()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
            case RPSampleBufferType.video:
                // Handle video sample buffer
                if let description:CMVideoFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                    let dimensions:CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(description)
                    broadcaster.stream.videoSettings = [
                        "width": dimensions.width,
                        "height": dimensions.height ,
                        "profileLevel": kVTProfileLevel_H264_Baseline_AutoLevel,
                    ]
                }
                broadcaster.appendSampleBuffer(sampleBuffer, withType: .video)
            case RPSampleBufferType.audioApp:
                // Handle audio sample buffer for app audio
                broadcaster.appendSampleBuffer(sampleBuffer, withType: .audio)
            case RPSampleBufferType.audioMic:
                // Handle audio sample buffer for mic audio
                // pure audio streaming, no VoIP, e.g. Twitch mode
             
                var audioBufferList = AudioBufferList()
                var blockBuffer: CMBlockBuffer?
                
                CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
                
                let buffers = UnsafeBufferPointer<AudioBuffer>(start: &audioBufferList.mBuffers, count: Int(audioBufferList.mNumberBuffers))
                
                for audioBuffer in buffers {
                    let frame = audioBuffer.mData?.assumingMemoryBound(to: CShort.self)
                    liveStreaming.addMicrophoneData(withBuffer: frame, amount: UInt(audioBuffer.mDataByteSize) / 2)
                }
                break
        }
    }
}
