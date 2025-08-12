//
//  E2EProtectionTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class E2EProtectionTests: XCTestCase {

    private var testE2EProtection = TestE2EProtection()

    override func setUp() {
        testE2EProtection.resetE2ECounter()
    }
    
    func testAppendingE2ECounter() {
        let someNumber: UInt32 = 0x01020304
        let data = Data(someNumber)
        let e2eCounter: UInt8 = 6
        let dataWithE2ECounter = data.appendingE2ECounter(e2eCounter)
        XCTAssertEqual(dataWithE2ECounter.count, 5)
        XCTAssertEqual(dataWithE2ECounter[dataWithE2ECounter.startIndex...].to(UInt32.self), someNumber)
        XCTAssertEqual(dataWithE2ECounter[dataWithE2ECounter.startIndex.advanced(by: 4)...].to(UInt8.self), e2eCounter)
    }

    func testAppendingE2EProtection() {
        let someNumber: UInt32 = 0x01020304
        let request = Data(someNumber)
        let requestWithE2EProtection = testE2EProtection.appendingE2EProtection(request)
        XCTAssertEqual(requestWithE2EProtection.count, 7)
        XCTAssertEqual(requestWithE2EProtection[requestWithE2EProtection.startIndex...].to(UInt32.self), someNumber)
        XCTAssertEqual(requestWithE2EProtection[requestWithE2EProtection.startIndex.advanced(by: 4)...].to(UInt8.self), testE2EProtection.e2eCounter)
        XCTAssertTrue(requestWithE2EProtection.isCRCValid)
    }
    
    func testE2ECounterIncrement() {
        testE2EProtection.incrementE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 2)
        
        testE2EProtection.incrementE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 3)
        
        testE2EProtection.e2eCounter = 254
        testE2EProtection.incrementE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 255)
        
        testE2EProtection.incrementE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 1)
    }
    
    func testE2ECounterReset() {
        testE2EProtection.incrementE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 2)
        testE2EProtection.resetE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 1)
        
        testE2EProtection.e2eCounter = 254
        testE2EProtection.incrementE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 255)
        testE2EProtection.resetE2ECounter()
        XCTAssertEqual(testE2EProtection.e2eCounter, 1)
    }
}

class TestE2EProtection: E2EProtection {
    var e2eDelegate: E2EProtectionDelegate?
    
    var e2eCounter: UInt8 = 1
}
