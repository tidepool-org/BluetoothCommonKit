//
//  FloatTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class FloatTests: XCTestCase {
    func testFloatToDouble() {
        // iterate over a sample set of values
        for float: FLOAT in 0x007ff000...0x00800fff {
            switch float {
            case let value where value == FloatSpecialValue.rfu.rawValue:
                XCTAssertTrue(Data(value).floatToDouble().isNaN)
            case let value where value == FloatSpecialValue.nan.rawValue:
                XCTAssertTrue(Data(value).floatToDouble().isNaN)
            case let value where value == FloatSpecialValue.nRes.rawValue:
                XCTAssertTrue(Data(value).floatToDouble().isNaN)
            case let value where value == FloatSpecialValue.infinityPostive.rawValue:
                XCTAssertEqual(Data(value).floatToDouble(), Double.infinity)
            case let value where value == FloatSpecialValue.infinityNegative.rawValue:
                XCTAssertEqual(Data(value).floatToDouble(), -Double.infinity)
            default:
                // exponent 0
                XCTAssertEqual(Data(float).floatToDouble(), Double(extractMantissa(float)))
            }
        }
          
        for float: FLOAT in 0x01000000...0x01000fff {
            // exponent 1
            XCTAssertEqual(Data(float).floatToDouble(), Double(extractMantissa(float)*10))
        }

        for float: FLOAT in 0x02000000...0x02000fff {
            // exponent 2
            XCTAssertEqual(Data(float).floatToDouble(), Double(extractMantissa(float)*100))
        }
        
        for float: FLOAT in 0xfe000000...0xfe000fff {
            // exponent -2
            XCTAssertEqual(Data(float).floatToDouble(), Double(extractMantissa(float))/100)
        }
        
        for float: FLOAT in 0xff000000...0xff000fff {
            // exponent -1
            XCTAssertEqual(Data(float).floatToDouble(), Double(extractMantissa(float))/10)
        }
    }
}

extension FloatTests {
    private func extractMantissa(_ float: FLOAT) -> Int {
        var mantissa = Int(float & 0x00ffffff)
        if mantissa >= 0x00800000 {
            mantissa -= 0x01000000
        }
        return mantissa
    }
}
