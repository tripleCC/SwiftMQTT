//
//  SwiftMQTT.swift
//  SwiftMQTT
//
//  Created by tripleCC on 16/4/26.
//  Copyright © 2016年 tripleCC. All rights reserved.
//

import Foundation

public func SMPrint(items: Any...) {
    #if DEBUG
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "hh:mm:ss"
        print(dateFormatter.stringFromDate(NSDate()), items)
    #endif
}

let kSwiftMQTTMaxRemainingLength = 268435455

public enum SwiftMQTTConnectReturnCode : UInt8 {
    case Accepted                   = 0
    case RefusedProtocolVersion     = 1
    case RefusedIdentiferRejected   = 2
    case RefusedServerUnavailable   = 3
    case RefusedBadUserNamePassword = 4
    case RefusedNotAuthorized       = 5
}

public enum SwiftMQTTMessageType : UInt8 {
    case Connect        = 0x10
    case ConnAck        = 0x20
    case Publish        = 0x30
    case PubAck         = 0x40
    case PubRec         = 0x50
    case PubRel         = 0x60
    case PubComp        = 0x70
    case Subscribe      = 0x80
    case SubAck         = 0x90
    case Unsubscribe    = 0xA0
    case UnsubBack      = 0xB0
    case PingReq        = 0xC0
    case PingResp       = 0xD0
    case Disconnect     = 0xE0
}

public enum SwiftMQTTStatus: UInt8 {
    case Created = 0
    case Connecting
    case Connected
    case Disconnect
    case Closed
}

public enum SwiftMQTTMessagePart : Int {
    case Header     = 0     // 固定报头（除剩余长度）
    case Length     = 1     // 剩余长度（可变报头和有效载荷）
    case Content    = 2     // 包括可变报头和有效载荷
}


func >(level1: SwiftMQTTQosLevel, level2: SwiftMQTTQosLevel) -> Bool {
    return level1.rawValue > level2.rawValue
}

public enum SwiftMQTTQosLevel : UInt8 {
    case AtMostOnce     = 0
    case AtLeastOnce    = 1
    case ExactlyOnce    = 2
}

public protocol SwiftMQTTConnectFlagProtocol {
    var connectFlag: UInt8 {get set}
    var usernameFlag: Bool {get set}
    var passwordFlag: Bool {get set}
    var willRetain: Bool {get set}
    var willQos: SwiftMQTTQosLevel {get set}
    var willFlag: Bool {get set}
    var cleanSession: Bool {get set}
}

extension SwiftMQTTConnectFlagProtocol {
    /**
     * +----------+----------+------------+---------+----------+--------------+----------+
     * |     7    |    6     |      5     |  4  3   |     2    |       1      |     0    |
     * | username | password | willretain | willqos | willflag | cleansession | reserved |
     * +----------+----------+------------+---------+----------+--------------+----------+
     */
    public var usernameFlag: Bool {
        get { return Bool((connectFlag & 0x80) >> 7) }
        set { connectFlag = (UInt8(newValue) << 7) | (connectFlag & 0x7F) }
    }
    public var passwordFlag: Bool {
        get { return Bool((connectFlag & 0x40) >> 6) }
        set { connectFlag = (UInt8(newValue) << 6) | (connectFlag & 0xBF) }
    }
    public var willRetain: Bool {
        get { return Bool((connectFlag & 0x20) >> 5) }
        set { connectFlag = (UInt8(newValue) << 5) | (connectFlag & 0xDF) }
    }
    public var willQos: SwiftMQTTQosLevel {
        get { return SwiftMQTTQosLevel(rawValue: (connectFlag & 0x18) >> 3) ?? .AtMostOnce }
        set { connectFlag = (UInt8(newValue.rawValue) << 3) | (connectFlag & 0xE7) }
    }
    public var willFlag: Bool {
        get { return Bool((connectFlag & 0x08) >> 2) }
        set { connectFlag = (UInt8(newValue) << 2) | (connectFlag & 0xFA) }
    }
    public var cleanSession: Bool {
        get { return Bool((connectFlag & 0x04) >> 1) }
        set { connectFlag = (UInt8(newValue) << 1) | (connectFlag & 0xFD) }
    }
}

public protocol SwiftMQTTCommandProtocol {
    var command: UInt8 {get set}
    var messageType: SwiftMQTTMessageType {get set}
    var dupFlag: Bool {get set}
    var qosLevel: SwiftMQTTQosLevel {get set}
    var retain: Bool {get set}
}

extension SwiftMQTTCommandProtocol {
    /**
     * +---------------+----------+-----------+--------+
     * |    7 6 5 4    |     3    |    2 1    |   0    |
     * |  Message Type | DUP flag | QoS level | RETAIN |
     * +---------------+----------+-----------+--------+
     */
    public var messageType: SwiftMQTTMessageType {
        get { return SwiftMQTTMessageType(rawValue: command & 0xF0) ?? .Connect }
        set { command = newValue.rawValue | (command & 0x0F) }
    }
    public var dupFlag: Bool {
        get { return Bool((command >> 3) & 0x01) }
        set { command = (UInt8(newValue) << 3) | (command & 0xF7) }
    }
    public var qosLevel: SwiftMQTTQosLevel {
        get { return SwiftMQTTQosLevel(rawValue: (command >> 1) & 0x03) ?? .AtMostOnce }
        set { command = newValue.rawValue << 1 | (command & 0xF9 ) }
    }
    public var retain: Bool {
        get { return Bool(command & 0x01) }
        set { command = UInt8(newValue) | (command & 0xFE) }
    }
}

public protocol SwiftMQTTVariableHeaderProtocol {
     var variableHeader: NSData {get}
}

extension SwiftMQTTVariableHeaderProtocol {
    public var variableHeader: NSData { return NSData() }
}

public protocol SwiftMQTTPayloadProtocol {
    var payload: NSData {get}
}

extension SwiftMQTTPayloadProtocol {
    public var payload: NSData { return NSData() }
}

public protocol SwiftMQTTMessageProtocol : SwiftMQTTFixedHeaderProtocol {
    var data: NSData {get}
}

extension SwiftMQTTMessageProtocol {
    public var data: NSData {
        let data = NSMutableData()
        data.appendByte(command)
        data.appendData(remainingLength.data)
        data.appendData(variableHeader)
        data.appendData(payload)
        return data
    }
}

public protocol SwiftMQTTFixedHeaderProtocol : SwiftMQTTCommandProtocol, SwiftMQTTVariableHeaderProtocol, SwiftMQTTPayloadProtocol {
    var remainingLength: UInt32 {get}
}

extension SwiftMQTTFixedHeaderProtocol {
    public var remainingLength: UInt32 {
        let remainingLength = variableHeader.length + payload.length
        guard remainingLength <= kSwiftMQTTMaxRemainingLength else {
            SMPrint("the size of remaining length field should be below \(kSwiftMQTTMaxRemainingLength).")
            return UInt32(kSwiftMQTTMaxRemainingLength)
        }
        return UInt32(remainingLength)
    }
}

public struct SwiftMQTTConnectMessage : SwiftMQTTMessageProtocol, SwiftMQTTClientProtocol, SwiftMQTTConnectFlagProtocol {
    public var command = UInt8(0x00)
    public var connectFlag = UInt8(0x00)
    var clientId: String
    var will: SwiftMQTTWill?
    var account: SwiftMQTTAccount?
    var keepalive = UInt16(60)
    public var variableHeader: NSData {
        let variableHeader = NSMutableData()
        variableHeader.appendMQTTString(protocolName)
        variableHeader.appendByte(protocolLevel)
        variableHeader.appendByte(connectFlag)
        variableHeader.appendUInt16(keepalive)
        return variableHeader
    }
    public var payload: NSData {
        let payload = NSMutableData()
        // 客户端标识符->遗嘱主题->遗嘱消息->用户名->密码
        payload.appendMQTTString(clientId)
        if let willTopic = will?.willTopic {
            payload.appendMQTTString(willTopic)
        }
        if let willMessage = will?.willMessage {
            payload.appendMQTTString(willMessage)
        }
        if let username = account?.username {
            payload.appendMQTTString(username)
        }
        if let password = account?.password {
            payload.appendMQTTString(password)
        }
        return payload
    }
    init(clientId: String, account: SwiftMQTTAccount?, will: SwiftMQTTWill?, keepalive: UInt16, cleanSession: Bool = true) {
        self.clientId = clientId
        self.account = account
        self.will = will
        self.cleanSession = cleanSession
        self.keepalive = keepalive
        messageType = .Connect
        
        // 设置连接标志
        if let will = will {
            willFlag = true
            willRetain = will.willRetain
            willQos = will.willQos
        }
        if let account = account { (usernameFlag, passwordFlag) = account.accountFlag }
    }
}

public protocol SwiftMQTTAckMessageProtocol: SwiftMQTTCommandProtocol {
    init?(_ bytes: [UInt8], command: UInt8)
}

public struct SwiftMQTTConnAckMessage : SwiftMQTTAckMessageProtocol {
    public var command = UInt8(0x00)
    public var sessionPresent: Bool
    public var connectReturnCode: SwiftMQTTConnectReturnCode
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count == 2 else { return nil }
        sessionPresent = Bool(bytes[0])
        connectReturnCode = SwiftMQTTConnectReturnCode(rawValue: bytes[1]) ?? .Accepted
        self.command = command
    }
}

public struct SwiftMQTTPublishMessage : SwiftMQTTAckMessageProtocol, SwiftMQTTMessageProtocol {
    public var command = UInt8(0x00)
    public var topicName: String
    public var messageId: UInt16?
    public var message: String?
    
    public var variableHeader: NSData {
        let variableHeader = NSMutableData()
        variableHeader.appendMQTTString(topicName)
        if let messageId = messageId where qosLevel > .AtMostOnce {
            variableHeader.appendUInt16(messageId)
        }
        return variableHeader
    }
    public var payload: NSData {
        let payload = NSMutableData()
        if let message = message?.dataUsingEncoding(NSUTF8StringEncoding) {
            payload.appendData(message)
        }
        return payload
    }
    public init(topicName: String, messageId: UInt16?, message: String) {
        self.topicName = topicName
        self.messageId = messageId
        self.message = message
        messageType = .Publish
    }
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count >= 2 else { return nil }
        var offset = 0
        
        let topicLength = Int(bytes[offset]) << 8 + Int(bytes[offset + 1])
        guard bytes.count >= 2 + topicLength else { return nil }
        
        offset = topicLength + 2
        guard let topicName = String(bytes: bytes[2..<offset], encoding: NSUTF8StringEncoding) else { return nil }
        self.topicName = topicName
        
        self.command = command
        if qosLevel > .AtMostOnce {
            let messageId = UInt16(bytes[offset]) << 8 + UInt16(bytes[offset + 1])
            offset += 2
            self.messageId = messageId
        }
        
        guard let message = String(bytes: bytes[offset..<bytes.endIndex], encoding: NSUTF8StringEncoding) else { return nil }
        self.message = message
    }
}

public protocol SwiftMQTTMessageMessageIdProtocol {
    var messageId: UInt16 {get set}
}

extension SwiftMQTTMessageProtocol where Self: SwiftMQTTMessageMessageIdProtocol {
    public var variableHeader: NSData {
        return NSMutableData().appendUInt16(messageId)
    }
}

public struct SwiftMQTTPubAckMessage : SwiftMQTTAckMessageProtocol, SwiftMQTTMessageProtocol, SwiftMQTTMessageMessageIdProtocol {
    public var command = UInt8(0x00)
    public var messageId: UInt16
    
    init(messageId: UInt16) {
        self.messageId = messageId
        messageType = .PubAck
        qosLevel = .AtLeastOnce
    }
    
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count == 2 else { return nil }
        messageId = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
        self.command = command
    }
}

public struct SwiftMQTTPubRelMessage : SwiftMQTTAckMessageProtocol, SwiftMQTTMessageProtocol, SwiftMQTTMessageMessageIdProtocol {
    public var command = UInt8(0x00)
    public var messageId: UInt16
    
    public init(messageId: UInt16, qosLevel: SwiftMQTTQosLevel = .AtLeastOnce) {
        self.messageId = messageId
        self.qosLevel = qosLevel
        messageType = .PubRel
    }
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count == 2 else { return nil }
        messageId = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
        self.command = command
    }
}

public struct SwiftMQTTPubRecMessage : SwiftMQTTAckMessageProtocol, SwiftMQTTMessageProtocol, SwiftMQTTMessageMessageIdProtocol {
    public var command = UInt8(0x00)
    public var messageId: UInt16
    
    public init(messageId: UInt16) {
        self.messageId = messageId
        messageType = .PubRec
        qosLevel = .ExactlyOnce
    }
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count == 2 else { return nil }
        messageId = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
        self.command = command
    }
}

public struct SwiftMQTTPubCompMessage : SwiftMQTTAckMessageProtocol, SwiftMQTTMessageProtocol, SwiftMQTTMessageMessageIdProtocol {
    public var command = UInt8(0x00)
    public var messageId: UInt16
    
    public init(messageId: UInt16) {
        self.messageId = messageId
        messageType = .PubComp
        qosLevel = .ExactlyOnce
    }
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count == 2 else { return nil }
        messageId = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
        self.command = command
    }
}

public struct SwiftMQTTSubscribeMessage : SwiftMQTTMessageProtocol, SwiftMQTTMessageMessageIdProtocol {
    public var command = UInt8(0x02)
    public var messageId: UInt16
    public var filterTopics: [String : SwiftMQTTQosLevel]

    public var payload: NSData {
        return filterTopics.reduce(NSMutableData()) { $0.appendMQTTString($1.0).appendByte($1.1.rawValue) }
    }
    
    public init(messageId: UInt16, filterTopics topics: [String : SwiftMQTTQosLevel]) {
        self.filterTopics = topics
        self.messageId = messageId
        messageType = .Subscribe
    }
}

public struct SwiftMQTTSubAckMessage : SwiftMQTTAckMessageProtocol {
    public var command = UInt8(0x00)
    public var messageId: UInt16
    public var qosLevels: [SwiftMQTTQosLevel]
    
    public init?(_ bytes: [UInt8], command: UInt8) {
        messageId = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
        qosLevels = bytes[2..<bytes.count].flatMap{ SwiftMQTTQosLevel(rawValue: $0) }
        self.command = command
    }

    public init(messageId: UInt16, qosLevels: [SwiftMQTTQosLevel]) {
        self.qosLevels = qosLevels
        self.messageId = messageId
    }
}

public struct SwiftMQTTUnsubscribeMessage : SwiftMQTTMessageProtocol, SwiftMQTTMessageMessageIdProtocol {
    public var command = UInt8(0x02)
    public var messageId: UInt16
    public var topics: [String]

    public var payload: NSData {
        return topics.reduce(NSMutableData()) { $0.appendMQTTString($1) }
    }
    
    public init(messageId: UInt16, topics: [String]) {
        self.topics = topics
        self.messageId = messageId
        messageType = .Unsubscribe
    }
}

public struct SwiftMQTTUnsubBackMessage : SwiftMQTTAckMessageProtocol {
    public var command = UInt8(0x00)
    public var messageId: UInt16
    
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count == 2 else { return nil }
        messageId = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
        self.command = command
    }
}

public struct SwiftMQTTPingReqMessage : SwiftMQTTMessageProtocol {
    public var command = UInt8(0x00)
    public init() {
        messageType = .PingReq
    }
}

public struct SwiftMQTTPingRespMessage : SwiftMQTTAckMessageProtocol {
    public var command = UInt8(0x00)
    public init?(_ bytes: [UInt8], command: UInt8) {
        self.command = command
    }
}

public struct SwiftMQTTDisconnectMessage : SwiftMQTTMessageProtocol {
    public var command = UInt8(0x00)
    public init() {
        messageType = .Disconnect
    }
}