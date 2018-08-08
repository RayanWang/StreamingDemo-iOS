//
//  BroadcastViewController.swift
//  ReplayBroadcastUI
//
//  Created by Rayan on 2017/5/8.
//  Copyright © 2017年 Rayan. All rights reserved.
//

import ReplayKit

class BroadcastViewController: UIViewController {

    @IBOutlet weak var startButton: UIButton!

    @IBOutlet weak var endpointURLField: UITextField!
    
    @IBOutlet weak var streamNameField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startButton.addTarget(self, action: #selector(BroadcastViewController.userDidFinishSetup), for: .touchDown)
    }
    
    // Called when the user has finished interacting with the view controller and a broadcast stream can start
    func userDidFinishSetup() {
        // Broadcast url that will be returned to the application
        let broadcastURL:URL = URL(string: endpointURLField.text!)!
        
        // Service specific broadcast data example which will be supplied to the process extension during broadcast
        let streamName:String = streamNameField.text!
        let endpointURL:String = endpointURLField.text!
        let setupInfo: [String: NSCoding & NSObjectProtocol] =  [
            "endpointURL" : endpointURL as NSString,
            "streamName" : streamName as NSString,
        ]
        
        // Set broadcast settings
        let broadcastConfiguration:RPBroadcastConfiguration = RPBroadcastConfiguration()
        broadcastConfiguration.clipDuration = 2
        broadcastConfiguration.videoCompressionProperties = [
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel as NSSecureCoding & NSObjectProtocol,
        ]
        
        // Tell ReplayKit that the extension is finished setting up and can begin broadcasting
        self.extensionContext?.completeRequest(
            withBroadcast: broadcastURL,
            broadcastConfiguration: broadcastConfiguration,
            setupInfo: setupInfo
        )
    }
    
    func userDidCancelSetup() {
        let error = NSError(domain: "me.soocii.ReplayBroadcast", code: -1, userInfo: nil)
        // Tell ReplayKit that the extension was cancelled by the user
        self.extensionContext?.cancelRequest(withError: error)
    }
}
