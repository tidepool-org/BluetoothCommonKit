//
//  SegmentationHeaderTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class SegmentationHeaderTests: XCTestCase {

    func testInitialization() {
        let headerWithFirstLastPartsCount5: UInt8 = 0b00010111
        let headerWithFirstPartCount10: UInt8 = 0b00101001
        let headerWithLastPartCount63: UInt8 = 0b11111110
        
        var segmentationHeader = SegmentationHeader(rawValue: headerWithFirstLastPartsCount5)
        XCTAssertTrue(segmentationHeader.contains(.firstPart))
        XCTAssertTrue(segmentationHeader.contains(.lastPart))
        XCTAssertEqual(segmentationHeader.counter, 5)
        
        segmentationHeader = SegmentationHeader(rawValue: headerWithFirstPartCount10)
        XCTAssertTrue(segmentationHeader.contains(.firstPart))
        XCTAssertFalse(segmentationHeader.contains(.lastPart))
        XCTAssertEqual(segmentationHeader.counter, 10)
        
        segmentationHeader = SegmentationHeader(rawValue: headerWithLastPartCount63)
        XCTAssertFalse(segmentationHeader.contains(.firstPart))
        XCTAssertTrue(segmentationHeader.contains(.lastPart))
        XCTAssertEqual(segmentationHeader.counter, 63)
    }
    
}
