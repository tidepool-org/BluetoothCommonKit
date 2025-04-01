//
//  Data.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public extension Data {
    private func toDefaultEndian<T: FixedWidthInteger>(_: T.Type) -> T {
        return self.withUnsafeBytes({ (rawBufferPointer: UnsafeRawBufferPointer) -> T in
            let bufferPointer = rawBufferPointer.bindMemory(to: T.self)
            guard let pointer = bufferPointer.baseAddress else {
                return 0
            }
            return T(pointer.pointee)
        })
    }

    func to<T: FixedWidthInteger>(_ type: T.Type) -> T {
        return T(littleEndian: toDefaultEndian(type))
    }

    func toInt<T: FixedWidthInteger>() -> T {
        return to(T.self)
    }

    func toBigEndian<T: FixedWidthInteger>(_ type: T.Type) -> T {
        return T(bigEndian: toDefaultEndian(type))
    }

    mutating func append<T: FixedWidthInteger>(_ newElement: T) {
        let element = newElement.littleEndian
        withUnsafePointer(to: element) { (ptr: UnsafePointer<T>) in
            append(UnsafeBufferPointer(start: ptr, count: 1))
        }
    }

    mutating func appendBigEndian<T: FixedWidthInteger>(_ newElement: T) {
        let element = newElement.bigEndian
        withUnsafePointer(to: element) { (ptr: UnsafePointer<T>) in
            append(UnsafeBufferPointer(start: ptr, count: 1))
        }
    }

    init<T: FixedWidthInteger>(_ value: T) {
        let value = value.littleEndian
        self = withUnsafePointer(to: value) { (ptr: UnsafePointer<T>) -> Data in
            return Data(buffer: UnsafeBufferPointer(start: ptr, count: 1))
        }
    }

    init<T: FixedWidthInteger>(bigEndian value: T) {
        let value = value.bigEndian
        self = withUnsafePointer(to: value) { (ptr: UnsafePointer<T>) -> Data in
            return Data(buffer: UnsafeBufferPointer(start: ptr, count: 1))
        }
    }
}


// String conversion methods, adapted from https://stackoverflow.com/questions/40276322/hex-binary-string-conversion-in-swift/40278391#40278391
public extension Data {
    init?(hexadecimalString: String) {
        self.init(capacity: hexadecimalString.utf16.count / 2)

        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch u {
            case 0x30 ... 0x39:  // '0'-'9'
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:  // 'A'-'F'
                return UInt8(u - 0x41 + 10)  // 10 since 'A' is 10, not 0
            case 0x61 ... 0x66:  // 'a'-'f'
                return UInt8(u - 0x61 + 10)  // 10 since 'a' is 10, not 0
            default:
                return nil
            }
        }

        var even = true
        var byte: UInt8 = 0
        for c in hexadecimalString.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                self.append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }

    var hexadecimalString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

/**
 CRC-CCITT
 
 [http://www.lammertbies.nl/comm/info/crc-calculation.html]()
 
 [http://web.mit.edu/6.115/www/amulet/xmodem.htm]()
 
 [Update] Added seed, polynomial, and final XOR to match the defintion in the Bluetooth Insulin Delivery Service
 https://www.bluetooth.com/xml-viewer/?src=https://www.bluetooth.com/wp-content/uploads/Sitecore-Media-Library/Gatt/Xml/Services/org.bluetooth.service.insulin_delivery.xml
 
 */
public extension Collection where Element == UInt8 {
    private var crcCCITT: UInt16 {
        let seed: UInt16 = 0xffff
        let polynomial: UInt16 = 0x8408
        let finalXOR: UInt16 = 0

        var crc: UInt16 = seed

        for byte in self {
            var tempByte = UInt16(byte)

            for _ in 0 ..< 8 {
                let temp1 = crc & 0x0001
                crc = crc >> 1
                let temp2 = tempByte & 0x0001
                tempByte = tempByte >> 1

                if (temp1 ^ temp2) == 1 {
                    crc = crc ^ polynomial
                }
            }
        }

        return crc ^ finalXOR
    }

    var crc16: UInt16 {
        return crcCCITT
    }
}

public extension UInt8 {
    var crc16: UInt16 {
        return [self].crc16
    }
}

public extension Data {
    var isCRCValid: Bool {
        return dropLast(2).crc16 == suffix(2).toInt()
    }

    var isCRCPrefixValid: Bool {
        return dropFirst(2).crc16 == prefix(2).toInt()
    }

    func appendingCRC() -> Data {
        var data = self
        data.append(crc16)
        return data
    }

    func appendingCRCPrefix() -> Data {
        var data = self
        data.insert(contentsOf: Data(crc16), at: 0)
        return data
    }
}
