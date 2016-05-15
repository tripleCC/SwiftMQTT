//
//  SwiftMQTTExtension.swift
//  SwiftMQTT
//
//  Created by tripleCC on 16/5/11.
//  Copyright © 2016年 tripleCC. All rights reserved.
//

import Foundation
extension UInt32 {
    var data: NSData {
        let data = NSMutableData()
        var length = self
        repeat {
            var digit = UInt8(length % 128)
            length /= 128
            if length > 0 {
                digit |= 0x80
            }
            data.appendByte(digit)
        } while length > 0
        return data
    }
}

extension UInt8 : BooleanType {
    public var boolValue: Bool {
        return self & 0x01 != 0
    }
    
    init(_ bool: Bool) {
        // http://stackoverflow.com/questions/29048002/getting-bit-pattern-of-bool-in-swift
        self.init(bool ? 1 : 0)
    }
}

extension NSData {
    var bytesArray: [UInt8] {
        var bytes = Array<UInt8>(count: length, repeatedValue: 0)
        getBytes(&bytes, length: length)
        return bytes
    }
}

extension NSMutableData {
    func appendUInt16(uint16: UInt16) -> Self {
        var uint16Temp = uint16.bigEndian
        appendBytes(&uint16Temp, length: sizeof(UInt16))
        return self
    }
    func appendByte(byte: UInt8) -> Self {
        var byteTemp = byte
        appendBytes(&byteTemp, length: sizeof(UInt8))
        return self
    }
    
    func appendMQTTString(string: String) -> Self {
        guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else { return self }
        var dataLength = UInt16(data.length).bigEndian
        appendBytes(&dataLength, length: sizeof(UInt16))
        appendData(data)
        return self
    }
}

extension Array where Element: Hashable {
    func mergeValues<T>(array: [T]) -> [Element : T] {
        var result = [Element : T]()
        for (idx, obj) in enumerate() {
            result[obj] = array[idx]
        }
        return result
    }
}
