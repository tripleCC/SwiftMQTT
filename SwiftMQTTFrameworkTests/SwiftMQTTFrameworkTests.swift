//
//  SwiftMQTTFrameworkTests.swift
//  SwiftMQTTFrameworkTests
//
//  Created by tripleCC on 16/5/13.
//  Copyright © 2016年 tripleCC. All rights reserved.
//

import XCTest
@testable import SwiftMQTTFramework

extension SwiftMQTTFrameworkTests: SwiftMQTTClientDelegate {
    func mqttClient(client: SwiftMQTTClient, didReceiveMessage message: SwiftMQTTAckMessageProtocol?) {
    }

}

class SwiftMQTTFrameworkTests: XCTestCase {
    var client: SwiftMQTTClient?
    var timeout = NSTimeInterval(10)
    let topicName = "ziroomer/wifi"
    var clientId = 0
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        client = clientWithName("tripleCC", password: "cg")
    }
    
    private func clientWithName(name: String, password: String) -> SwiftMQTTClient {
        let client = SwiftMQTTClient(clientId: String(clientId), account: SwiftMQTTAccount(username: name, password: password), keepalive: 90)
        client.connectToHost("localhost", port: 1883)
        clientId += 1
        return client
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        client?.disconnect()
    }
    
    func testConnect() {
        let connectExpectation = expectationWithDescription("Connect")
        client?.didReceiveMessageHandler = { message in
            XCTAssertEqual(message?.messageType, .ConnAck)
            XCTAssertEqual((message as? SwiftMQTTConnAckMessage)?.connectReturnCode, .Accepted)
            connectExpectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout) { (error) in
            print(error?.description)
        }
    }
    
    func testPublish() {
        let publishExpectation1 = expectationWithDescription("Publish1")
        let publishExpectation2 = expectationWithDescription("Publish2")
        var qosLevel = SwiftMQTTQosLevel.AtLeastOnce
        var messageType: SwiftMQTTMessageType = .PubRec
        client?.didReceiveMessageHandler = { [unowned self] message in
            if message?.messageType == .ConnAck {
                print("test AtLeastOnce")
                self.client?.publishMessageWithTopicName(self.topicName, message: "tripleCC", qosLevel: qosLevel)
            } else {
                if qosLevel == .ExactlyOnce {
                    if messageType == .PubRec {
                        XCTAssertEqual(message?.messageType, .PubRec)
                        messageType = .PubComp
                    } else {
                        XCTAssertEqual(message?.messageType, .PubComp)
                        publishExpectation2.fulfill()
                    }
                } else {
                    XCTAssertEqual(message?.messageType, .PubAck)
                    publishExpectation1.fulfill()
                    qosLevel = .ExactlyOnce
                    self.client?.publishMessageWithTopicName(self.topicName, message: "tripleCC", qosLevel: qosLevel)
                    print("test ExactlyOnce")
                }
            }
        }
        waitForExpectationsWithTimeout(timeout * 3) { (error) in
            print(error?.description)
        }
    }
    
    var publishClient: SwiftMQTTClient?
    func testSubscribe() {
        let subscribeExpectation1 = expectationWithDescription("Subscribe1")
        let subscribeExpectation2 = expectationWithDescription("Subscribe2")
        var messageType: SwiftMQTTMessageType = .SubAck
        client?.didReceiveMessageHandler = { [unowned self] message in
            if message?.messageType == .ConnAck {
                self.client?.subscribeMessageWithTopics([self.topicName], qosLevels: [.AtLeastOnce])
            } else {
                if messageType == .SubAck {
                    XCTAssertEqual(message?.messageType, .SubAck)
                    messageType = .Publish
                    subscribeExpectation1.fulfill()
                    self.publishClient = self.clientWithName("Job", password: "kk")
                    self.publishClient?.didReceiveMessageHandler = { [unowned self] message in
                        if message?.messageType == .ConnAck {
                            self.client?.publishMessageWithTopicName(self.topicName, message: "Job", qosLevel: .AtLeastOnce)
                        }
                    }
                } else {
                    if message?.messageType == .Publish && messageType == .Publish {
                        subscribeExpectation2.fulfill()
                        messageType = .Connect
                    }
                }
            }
        }
        
        waitForExpectationsWithTimeout(timeout) { (error) in
            print(error?.description)
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}


