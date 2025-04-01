//
//  DataTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class DataTests: XCTestCase {

    func testLittleEndianDataToUInt8() {
        let data = Data([0x01])
        let value = data[data.startIndex...].to(UInt8.self)
        XCTAssertEqual(value, 1)
    }

    func testLittleEndianDataToUInt16() {
        let data = Data([0x01, 0x02])
        let value = data[data.startIndex...].to(UInt16.self)
        XCTAssertEqual(value, 513)
    }
    
    func testLittleEndianDataToUInt32() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let value = data[data.startIndex...].to(UInt32.self)
        XCTAssertEqual(value, 67305985)
    }
    
    func testBigEndianDataToUInt8() {
        let data = Data([0x01])
        let value = data[data.startIndex...].toBigEndian(UInt8.self)
        XCTAssertEqual(value, 1)
    }

    func testBigEndianDataToUInt16() {
        let data = Data([0x01, 0x02])
        let value = data[data.startIndex...].toBigEndian(UInt16.self)
        XCTAssertEqual(value, 258)
    }
    
    func testBigEndianDataToUInt32() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let value = data[data.startIndex...].toBigEndian(UInt32.self)
        XCTAssertEqual(value, 16909060)
    }
    
    func testLittleEndianAppend() {
        let expectedData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let somethingToAdd: UInt16 = 0x0605
        var data = Data([0x01, 0x02, 0x03, 0x04])
        data.append(somethingToAdd)
        XCTAssertEqual(data, expectedData)
    }
    
    func testBigEndianAppend() {
        let expectedData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let somethingToAdd: UInt16 = 0x0506
        var data = Data([0x01, 0x02, 0x03, 0x04])
        data.appendBigEndian(somethingToAdd)
        XCTAssertEqual(data, expectedData)
    }
    
    func testLittleEndianInitialization() {
        let initialValue: UInt32 = 0x04030201
        let expectedData = Data([0x01, 0x02, 0x03, 0x04])
        XCTAssertEqual(Data(initialValue), expectedData)
    }
    
    func testBigEndianInitialization() {
        let initialValue: UInt32 = 0x01020304
        let expectedData = Data([0x01, 0x02, 0x03, 0x04])
        XCTAssertEqual(Data(bigEndian: initialValue), expectedData)
    }
    
    func testHexidecimalString() {
        let data = Data([0xAB, 0xCD, 0xEF, 0x12])
        XCTAssertEqual(data.hexadecimalString, "abcdef12")
    }
    
    func testCRC16() {
        // test vector from Bluetooth Insulin Delivery Service
        // data = [0x3E, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09]
        // CRC = [0x01, 0x2F]
        
        let data1 = Data(hex:"3e010203040506070809")
        let expectedCRC1: UInt16 = 0x2f01
        let crc1 = data1.crc16
        XCTAssertEqual(crc1, expectedCRC1)
        
        // data with CRC = (0x) 78-22-E4-07-03-15-0E-07-03-00-00-01-AB-41
        // CRC = 16811 = 0x41ab
        let data2 = Data(hex:"7822e40703150e0703000001")
        let expectedCRC2: UInt16 = 0x41ab
        let crc2 = data2.crc16
        XCTAssertEqual(crc2, expectedCRC2)
    }
    
    func testIsCRCValid() {
        // test vector from Bluetooth Insulin Delivery Service
        // data = [0x3E, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09]
        // CRC = [0x01, 0x2F]
        let dataWithCRC1 = Data(hex:"3e010203040506070809012f")
        XCTAssertTrue(dataWithCRC1.isCRCValid)
        
        // data with CRC = (0x) 78-22-E4-07-03-15-0E-07-03-00-00-01-AB-41
        // CRC = 16811 = 0x41ab
        let dataWithCRC2 = Data(hex:"7822e40703150e0703000001ab41")
        XCTAssertTrue(dataWithCRC2.isCRCValid)
    }
    
    func testAppendingCRC() {
        // test vector from Bluetooth Insulin Delivery Service
        // data = [0x3E, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09]
        // CRC = [0x01, 0x2F]
        let data1 = Data(hex:"3e010203040506070809")
        let expectedData1 = Data(hex:"3e010203040506070809012f")
        XCTAssertEqual(data1.appendingCRC(), expectedData1)
        
        // data with CRC = (0x) 78-22-E4-07-03-15-0E-07-03-00-00-01-AB-41
        // CRC = 16811 = 0x41ab
        let data2 = Data(hex:"7822e40703150e0703000001")
        let expectedData2 = Data(hex:"7822e40703150e0703000001ab41")
        XCTAssertEqual(data2.appendingCRC(), expectedData2)
    }
}
