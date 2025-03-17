//
//  FloatingPointTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class FloatingPointTests: XCTestCase {

    func testRoundedToTenths() {
        // average number (round down)
        var number = 12.34958
        XCTAssertEqual(number.roundedToTenths, 12.3)
        
        // average number (round up)
        number = 12.35958
        XCTAssertEqual(number.roundedToTenths, 12.4)
        
        // small number
        number = 0.1235958
        XCTAssertEqual(number.roundedToTenths, 0.1)
        
        // smaller number
        number = 0.0001235958
        XCTAssertEqual(number.roundedToTenths, 0)
        
        // larger number
        number = 12034
        XCTAssertEqual(number.roundedToTenths, 12034)
    }
    
    func testRoundedToHundredths() {
        // average number (round down)
        var number = 12.34458
        XCTAssertEqual(number.roundedToHundredths, 12.34)
        
        // average number (round up)
        number = 12.35958
        XCTAssertEqual(number.roundedToHundredths, 12.36)
        
        // small number
        number = 0.1235958
        XCTAssertEqual(number.roundedToHundredths, 0.12)
        
        // smaller number
        number = 0.0001235958
        XCTAssertEqual(number.roundedToHundredths, 0)
        
        // larger number
        number = 12034
        XCTAssertEqual(number.roundedToHundredths, 12034)
    }

}
