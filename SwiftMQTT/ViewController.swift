//
//  ViewController.swift
//  SwiftMQTT
//
//  Created by tripleCC on 16/4/26.
//  Copyright © 2016年 tripleCC. All rights reserved.
//

import UIKit
import SwiftMQTTFramework

class ViewController: UIViewController, SwiftMQTTClientDelegate {

    var client: SwiftMQTTClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.client = SwiftMQTTClient(clientId: NSProcessInfo().globallyUniqueString, account: SwiftMQTTAccount(username: "tripleCC", password: "cg"), keepalive: 90)
        self.client?.connectToHost("localhost", port: 1883)
        self.client?.delegate = self
        
        
    }

    @IBAction func subscribe(sender: AnyObject) {
        client?.subscribeMessageWithTopics(["ziroomer/+"], qosLevels: [.AtLeastOnce])
    }
    @IBAction func unsubscribe(sender: AnyObject) {
        client?.unsubscribeMessageWithTopics(["ziroomer/+"])
    }
    @IBAction func send(sender: AnyObject) {
        self.client?.publishMessageWithTopicName("ziroomer/wifi", message: "tripleCC", qosLevel: .ExactlyOnce)
    }
    @IBAction func disconnect(sender: AnyObject) {
        client?.disconnect()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func mqttClient(client: SwiftMQTTClient, didReceiveMessage message: SwiftMQTTAckMessageProtocol?) {
//        print(message?.messageType)
//        if client.status == .Connected && message?.messageType == .ConnAck {
//            
//        }
        
        if let message = message as? SwiftMQTTPublishMessage {
            print(message)
        }
    }

}
