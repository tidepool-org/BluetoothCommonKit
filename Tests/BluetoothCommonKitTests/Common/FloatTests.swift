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
    func testIntToFloat() {
        // special cases
        XCTAssertEqual(Int.max.float, Data(UInt32(0x0d0e12e1)))
        XCTAssertEqual(Int.min.float, Data(UInt32(0x0df1ed1f)))
        
        // other cases
        XCTAssertEqual(Int(0).float, Data(UInt32(0x00000000)))
        XCTAssertEqual(Int(10000).float, Data(UInt32(0x00002710)))
        XCTAssertEqual(Int(-200000).float, Data(UInt32(0x00fcf2c0)))
        XCTAssertEqual(Int(300000000).float, Data(UInt32(0x022dc6c0)))
        XCTAssertEqual(Int(-4000000000).float, Data(UInt32(0x03c2f700)))
        XCTAssertEqual(Int(20470000000).float, Data(UInt32(0x041f3c18)))
        XCTAssertEqual(Int(-20480000000).float, Data(UInt32(0x04e0c000)))
    }
    
    func testToFloatInitialExponent() {
        XCTAssertEqual(Int.max.toFloat(initialExponent: 50), Data(UInt32(0x3f0e12e1)))
        XCTAssertEqual(Int.max.toFloat(initialExponent: -50), Data(UInt32(0xdb0e12e1)))
    }

    func testToFloatAvoidsSpecialValueMantissas() {
        // Exponent 0 with these mantissas would be read as +INF, NaN, NRes, RFU, -INF; encode as x10 one decade up
        XCTAssertEqual(Int(8388606).float, Data(UInt32(0x010ccccc)))
        XCTAssertEqual(Int(8388607).float, Data(UInt32(0x010ccccc)))
        XCTAssertEqual(Int(-8388606).float, Data(UInt32(0x01f33334)))
        XCTAssertEqual(Int(-8388607).float, Data(UInt32(0x01f33334)))
        XCTAssertEqual(Int(-8388608).float, Data(UInt32(0x01f33334)))

        // Neighbours just outside the band encode directly
        XCTAssertEqual(Int(8388605).float, Data(UInt32(0x007ffffd)))
        XCTAssertEqual(Int(-8388605).float, Data(UInt32(0x00800003)))

        // Values that only reach a special-value mantissa after normalization
        XCTAssertEqual(Int(83886070).toFloat(initialExponent: -1), Data(UInt32(0x010ccccc)))
        XCTAssertEqual(Int(-83886060).toFloat(initialExponent: -1), Data(UInt32(0x01f33334)))
        XCTAssertEqual(Double(8388606.5).float, Data(UInt32(0x010ccccc)))
        XCTAssertEqual(Double(-8388606.5).float, Data(UInt32(0x01f33334)))

        // The same mantissas are ordinary values at any other exponent
        XCTAssertEqual(Int(83886070).float, Data(UInt32(0x017fffff)))
        XCTAssertEqual(Int(-83886060).float, Data(UInt32(0x01800002)))
        XCTAssertEqual(Int(8388607).toFloat(initialExponent: -1), Data(UInt32(0xff7fffff)))
        XCTAssertEqual(Int(-8388608).toFloat(initialExponent: -1), Data(UInt32(0xff800000)))

        // Mantissas that are only special for SFLOAT must not be remapped here
        XCTAssertEqual(Int(-2046).float, Data(UInt32(0x00fff802)))
        XCTAssertEqual(Int(-2047).float, Data(UInt32(0x00fff801)))

        // The remapped encodings decode to the truncated neighbour, never to a special value
        XCTAssertEqual(Data(UInt32(0x010ccccc)).floatToDouble(), 8388600)
        XCTAssertEqual(Data(UInt32(0x01f33334)).floatToDouble(), -8388600)
    }
    
    func testFloatingPointToFLoat() {
        // other cases
        XCTAssertEqual(Double(0).float, Data(UInt32(0x00000000)))
        XCTAssertEqual(Double(10000).float, Data(UInt32(0xfe0f4240)))
        XCTAssertEqual(Double(-200000).float, Data(UInt32(0xffe17b80)))
        XCTAssertEqual(Double(300000000).float, Data(UInt32(0x022dc6c0)))
        XCTAssertEqual(Double(-400000000).float, Data(UInt32(0x02c2f700)))
        XCTAssertEqual(Double(2047e7).float, Data(UInt32(0x041f3c18)))
        XCTAssertEqual(Double(-2048e7).float, Data(UInt32(0x04e0c000)))
        XCTAssertEqual((-0.1).float, Data(UInt32(0xf9f0bdc0)))
        XCTAssertEqual(0.02.float, Data(UInt32(0xf81e8480)))
        XCTAssertEqual((-0.003).float, Data(UInt32(0xf8fb6c20)))
        XCTAssertEqual(0.0004.float, Data(UInt32(0xf8009c40)))
        XCTAssertEqual((-0.00123).float, Data(UInt32(0xf8fe1f88)))
        XCTAssertEqual(0.000456.float, Data(UInt32(0xf800b220)))
        XCTAssertEqual((-0.00000789).float, Data(UInt32(0xf8fffceb)))
    }
    
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
