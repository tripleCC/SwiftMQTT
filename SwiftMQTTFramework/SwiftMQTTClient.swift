//
//  SwiftMQTTClient.swift
//  SwiftMQTT
//
//  Created by tripleCC on 16/5/11.
//  Copyright © 2016年 tripleCC. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
/**
 *  如果使用了SwiftMQTTWill，则willFlag应该为true
 *  所以这里并不提供willFlag字段
 */
public struct SwiftMQTTWill {
    public var willTopic: String
    public var willMessage: String
    public var willRetain: Bool
    public var willQos: SwiftMQTTQosLevel
    public init(willTopic: String, willMessage: String, willRetain: Bool = true, willQos: SwiftMQTTQosLevel = .AtLeastOnce) {
        self.willTopic = willTopic
        self.willMessage = willMessage
        self.willRetain = willRetain
        self.willQos = willQos
    }
}

public struct SwiftMQTTAccount {
    public var username: String?
    public var password: String?
    public var accountFlag: (Bool, Bool) { return (usernameFlag, passwordFlag) }
    public var usernameFlag: Bool { return username != nil }
    public var passwordFlag: Bool { return password != nil }
    public init(username: String?, password: String?) {
        self.username = username
        self.password = password
    }
}

protocol SwiftMQTTClientProtocol {
    var protocolName: String {get}
    var protocolLevel: UInt8 {get}
    var keepalive: UInt16 {get}
    var clientId: String {get}
    var account: SwiftMQTTAccount? {get}
    var will: SwiftMQTTWill? {get}
}

extension SwiftMQTTClientProtocol {
    var protocolName: String { return "MQTT" }
    var protocolLevel: UInt8 { return 0x04 }
    var keepalive: UInt16 { return 60 }
}

public protocol SwiftMQTTClientDelegate: class {
    func mqttClient(client: SwiftMQTTClient, didReceiveMessage message: SwiftMQTTAckMessageProtocol?)
}


typealias SwiftMQTTDidConnectAction = () -> Void
typealias SwiftMQTTDidDisconnectAction = () -> Void
public typealias SwiftMQTTdidReceiveMessageHandler = (SwiftMQTTAckMessageProtocol?) -> Void
public class SwiftMQTTClient : NSObject, SwiftMQTTClientProtocol {
//    var didConnectAction: SwiftMQTTDidConnectAction?
//    var didDisconnectAction: SwiftMQTTDidDisconnectAction?
    public var didReceiveMessageHandler: SwiftMQTTdidReceiveMessageHandler?
    public var timeout = NSTimeInterval(60)
    public var clientId: String
    public var account: SwiftMQTTAccount?
    public var will: SwiftMQTTWill?
    public var cleanSession = Bool(true)
    public var host: String!
    public var port: UInt16!
    public var keepalive: UInt16 {
        didSet { keepaliveTimer.interval = UInt64(keepalive) }
    }
    public var status: SwiftMQTTStatus
    public var delegate: SwiftMQTTClientDelegate?
    
    private var keepaliveTimer = SwiftMQTTTimer(queue: dispatch_get_global_queue(0, 0))
    private lazy var messageDecoder: SwiftMQTTMessageDecoder = {
        var messageDecoder = SwiftMQTTMessageDecoder()
        messageDecoder.delegate = self
        return messageDecoder
    }()
    
    private lazy var socket: GCDAsyncSocket = {
        return GCDAsyncSocket(delegate: self, delegateQueue: self.delegateQueue)
    }()
    
    private var messageId: UInt16 = 1
    
    private var delegateQueue: dispatch_queue_t {
        return dispatch_get_main_queue()
    }
    
    public init(clientId: String!, will: SwiftMQTTWill? = nil, account: SwiftMQTTAccount? = nil, keepalive: UInt16 = UInt16(60)) {
        self.clientId = clientId
        self.will = will
        self.account = account
        self.keepalive = keepalive
        self.keepaliveTimer.interval = UInt64(keepalive)
        status = .Created
    }
    
    private func sendMessage(message: SwiftMQTTMessageProtocol) {
        socket.writeData(message.data, withTimeout: Static.SwiftMQTTClientTimeoutForever, tag: SwiftMQTTMessagePart.Header.rawValue)
    }
    
    private func increaseMessageId() {
        objc_sync_enter(self)
        messageId += 1
        objc_sync_exit(self)
    }
    
    deinit {
        SMPrint("client is released.")
    }
}

typealias SwiftMQTTClientAPI = SwiftMQTTClient
extension SwiftMQTTClientAPI {
    public func connectToHost(host: String!, port: UInt16!, completion: ((SwiftMQTTConnectReturnCode) -> Void)? = nil) {
        self.host = host
        self.port = port
        do {
            try socket.connectToHost(host, onPort: port)
        } catch let error { SMPrint(error) }
    }
    
    public func publishMessageWithTopicName(topicName: String, message: String, qosLevel: SwiftMQTTQosLevel = .AtLeastOnce, dupFlag: Bool = false, retain: Bool = false) {
        var publishMessage = SwiftMQTTPublishMessage(topicName: topicName, messageId: messageId, message: message)
        publishMessage.qosLevel = qosLevel
        publishMessage.dupFlag = dupFlag
        publishMessage.retain = retain
        sendMessage(publishMessage)
        increaseMessageId()
    }
    
    public func subscribeMessageWithTopics(topics: [String], qosLevels: [SwiftMQTTQosLevel]) {
        guard topics.count == qosLevels.count && topics.count > 0 else { return }
        let subscribeMessage = SwiftMQTTSubscribeMessage(messageId: messageId, filterTopics: topics.mergeValues(qosLevels))
        sendMessage(subscribeMessage)
        increaseMessageId()
    }
    
    public func unsubscribeMessageWithTopics(topics: [String]) {
        guard topics.count > 0 else { return }
        let unsubscribeMessage = SwiftMQTTUnsubscribeMessage(messageId: messageId, topics: topics)
        sendMessage(unsubscribeMessage)
        increaseMessageId()
    }
    
    public func disconnect() {
        sendMessage(SwiftMQTTDisconnectMessage())
        resetClient()
    }
}

extension SwiftMQTTClient: SwiftMQTTMessageDecoderDelegate {
    private func mqttMessageDecoder(decoder: SwiftMQTTMessageDecoder, didUnpackMessage message: SwiftMQTTAckMessageProtocol?) {
        // 报文解析完成，重新监听
        startListening()
        // 发送保活报文
        if let message = message as? SwiftMQTTConnAckMessage {
            if message.connectReturnCode == .Accepted {
                status = .Connected
                keepaliveTimer.start(keepaliveTimerCallBack)
            }
        } else if let message = message as? SwiftMQTTPubRecMessage {
            // 发送二阶回复
            sendMessage(SwiftMQTTPubRelMessage(messageId: message.messageId))
        } else if let message = message as? SwiftMQTTPublishMessage {
            // 收到订阅主题的消息
            if let messageId = message.messageId {
                if message.qosLevel == .AtLeastOnce {
                    sendMessage(SwiftMQTTPubAckMessage(messageId: messageId))
                } else {
                    sendMessage(SwiftMQTTPubRecMessage(messageId: messageId))
                }
            }
        } else if let message = message as? SwiftMQTTPubRelMessage {
            sendMessage(SwiftMQTTPubCompMessage(messageId: message.messageId))
        }
        
        delegate?.mqttClient(self, didReceiveMessage: message)
        didReceiveMessageHandler?(message)
    }
    
    func keepaliveTimerCallBack() {
        if status == .Connected {
            SMPrint(#line, "send ping request")
            sendMessage(SwiftMQTTPingReqMessage())
        } else {
            SMPrint(#line, "close keepalive timer")
            keepaliveTimer.cancel()
        }
    }
}

typealias GCDAsyncSocketDelegateImplement = SwiftMQTTClient
extension GCDAsyncSocketDelegateImplement : GCDAsyncSocketDelegate {
    struct Static {
        static let SwiftMQTTClientTimeoutForever = NSTimeInterval(-1)
    }
    private func resetClient() {
        status = status == .Connecting ? .Disconnect : .Closed
        keepaliveTimer.cancel()
    }
    public func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        // 允许后台连接
        sock.performBlock { sock.enableBackgroundingOnSocket() }
        // 一旦连接socket就发送connect报文
        let connectMessage = SwiftMQTTConnectMessage(clientId: clientId, account: account, will: will, keepalive: keepalive)
        sendMessage(connectMessage)
        // 开始监听服务端返回的数据
        startListening()
        status = .Connecting
    }
    
    public func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        if let part = SwiftMQTTMessagePart(rawValue: tag) where data.length != 0 {
            messageDecoder.unpackData(data, part: part, nextReader: readMessageWithLength)
        }
    }
    
    public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        resetClient()
    }
    
    private func startListening() {
        readMessageWithLength(1, part: .Header, timeout: Static.SwiftMQTTClientTimeoutForever)
    }
    
    private func readMessageWithLength(length: UInt32, part: SwiftMQTTMessagePart) {
        readMessageWithLength(length, part: part, timeout: timeout)
    }
    
    private func readMessageWithLength(length: UInt32, part: SwiftMQTTMessagePart, timeout: NSTimeInterval) {
        // 按照缓存排列依次读取固定字节的数据（如果有一个地方读取错误，那么将会影响到后续的所有数据）
        socket.readDataToLength(UInt(length), withTimeout: timeout, tag: part.rawValue)
    }
}

private protocol SwiftMQTTMessageDecoderDelegate: class {
    func mqttMessageDecoder(decoder: SwiftMQTTMessageDecoder,
                            didUnpackMessage message: SwiftMQTTAckMessageProtocol?)
}

private struct SwiftMQTTMessageDecoder {
    typealias SwiftMQTTMessageDecoderNextReader = (length: UInt32, part: SwiftMQTTMessagePart) -> Void
    weak var delegate: SwiftMQTTMessageDecoderDelegate?
    
    private struct SwiftMQTTCommand : SwiftMQTTCommandProtocol {
        var command: UInt8
    }
    private var messageHeader = SwiftMQTTCommand(command: 0x00)
    private var messageLengthBytes = [UInt8]()
    
    mutating func unpackData(data: NSData, part: SwiftMQTTMessagePart, nextReader:SwiftMQTTMessageDecoderNextReader) {
        let bytes = data.bytesArray
        switch part {
        case .Header:
            messageHeader = unpackHeader(bytes)
            // 读取一个字节的剩余长度
            nextReader(length: 1, part: .Length)
        case .Length:
            messageLengthBytes.appendContentsOf(bytes)
            // 如果最高位为0，则剩余长度已确定
            if Bool(bytes[0] & 0x80) {
                // 继续读取一个字节的剩余长度
                nextReader(length: 1, part: .Length)
            } else {
                // 获取剩余长度
                let messageLength = unpackLength(messageLengthBytes)
                if messageLength > 0 {
                    // 读取可变报头和payload
                    nextReader(length: messageLength, part: .Content)
                } else {
                    // 没有可变报头和payload，不需要再进行读取操作，直接解包
                    unpackContent()
                }
                SMPrint(#line, "剩余长度:\(messageLength)")
                // 重置长度缓存
                messageLengthBytes.removeAll()
            }
        case .Content:
            // 解析可变报头和payload
            unpackContent(bytes)
        }
    }
    
    func unpackHeader(bytes: [UInt8]) -> SwiftMQTTCommand  {
        return SwiftMQTTCommand(command: bytes[0])
    }
    
    func unpackLength(bytes: [UInt8]) -> UInt32 {
        var remainingLength = UInt32(0)
        var digit: UInt8
        var multiplier = UInt32(1)
        var offset = 0
        repeat {
            guard offset < 4 && offset < bytes.count else { break }
            digit = bytes[offset]
            remainingLength += UInt32((digit & 0x7F)) * multiplier
            multiplier *= 128
            offset += 1
        } while (digit & 0x80) != 0
        return remainingLength
    }
    
    func unpackContent(bytes: [UInt8] = [0]) {
        var messageStructType: SwiftMQTTAckMessageProtocol.Type?
        switch messageHeader.messageType {
        case .ConnAck:
            messageStructType = SwiftMQTTConnAckMessage.self
        case .Publish:
            messageStructType = SwiftMQTTPublishMessage.self
        case .PubAck:
            messageStructType = SwiftMQTTPubAckMessage.self
        case .PubRec:
            messageStructType = SwiftMQTTPubRecMessage.self
        case .PubRel:
            messageStructType = SwiftMQTTPubRelMessage.self
        case .PubComp:
            messageStructType = SwiftMQTTPubCompMessage.self
        case .SubAck:
            messageStructType = SwiftMQTTSubAckMessage.self
        case .UnsubBack:
            messageStructType = SwiftMQTTUnsubBackMessage.self
        case .PingResp:
            messageStructType = SwiftMQTTPingRespMessage.self
        default:
            SMPrint("Receiveing message command \(messageHeader.command) is not formal")
        }
        SMPrint(#line, messageStructType)
        guard let messageType = messageStructType else { return }
        delegate?.mqttMessageDecoder(self, didUnpackMessage: messageType.init(bytes, command: messageHeader.command))
    }
}

struct SwiftMQTTTimer {
    var interval: UInt64
    private var timer: dispatch_source_t?
    private var queue: dispatch_queue_t!
    init(queue: dispatch_queue_t! = dispatch_get_main_queue(), interval: UInt64 = NSEC_PER_SEC) {
        self.queue = queue
        self.interval = interval
    }
    
    mutating func start(hander: dispatch_block_t!) {
        if timer == nil {
            SMPrint(#line, "保活时间：\(interval)")
            let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
            dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC * interval)), interval * NSEC_PER_SEC, 0)
            dispatch_source_set_event_handler(timer, hander)
            dispatch_resume(timer)
            self.timer = timer
        }
    }
    
    mutating func cancel() {
        if let timer = timer {
            dispatch_source_cancel(timer)
            self.timer = nil
        }
    }
}

