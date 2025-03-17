//
//  SFloatTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class SFloatTests: XCTestCase {
    func testIntSFloat() {
        // special cases
        XCTAssertEqual(Int.max.sfloat, Data(UInt16(0x07fe)))
        XCTAssertEqual(Int.min.sfloat, Data(UInt16(0x0802)))
        XCTAssertEqual(Int(2048).sfloat, Data(UInt16(0x10cc)))
        XCTAssertEqual(Int(2047).sfloat, Data(UInt16(0x10cc)))
        XCTAssertEqual(Int(2046).sfloat, Data(UInt16(0x10cc)))
        XCTAssertEqual(Int(2045).sfloat, Data(UInt16(0x07fd)))
        XCTAssertEqual(Int(-2049).sfloat, Data(UInt16(0x1f34)))
        XCTAssertEqual(Int(-2048).sfloat, Data(UInt16(0x1f34)))
        XCTAssertEqual(Int(-2047).sfloat, Data(UInt16(0x1f34)))
        XCTAssertEqual(Int(-2046).sfloat, Data(UInt16(0x1f34)))
        XCTAssertEqual(Int(-2045).sfloat, Data(UInt16(0x0803)))
        
        // other cases
        XCTAssertEqual(Int(0).sfloat, Data(UInt16(0x0000)))
        XCTAssertEqual(Int(10000).sfloat, Data(UInt16(0x13e8)))
        XCTAssertEqual(Int(-200000).sfloat, Data(UInt16(0x2830)))
        XCTAssertEqual(Int(300000000).sfloat, Data(UInt16(0x612c)))
        XCTAssertEqual(Int(-4000000000).sfloat, Data(UInt16(0x7e70)))
        XCTAssertEqual(Int(20470000000).sfloat, Data(UInt16(0x77ff)))
        XCTAssertEqual(Int(-20480000000).sfloat, Data(UInt16(0x7800)))
    }
    
    func testToSFloat() {
        // check right shift. 10000 initial exponent 2 (i.e. original value is 1000000, converts to 1000e3)
        XCTAssertEqual(Int(10000).toSFloat(initialExponent: 2), Data(UInt16(0x33e8)))
        
        // check left shift. 10000 initial exponent -7 (i.e. original value is 0.001, converts to 1000e-6)
        XCTAssertEqual(Int(10000).toSFloat(initialExponent: -7), Data(UInt16(0xa3e8)))
    }
    
    func testFloatingPointToSFLoat() {
        // special cases
        XCTAssertEqual(1234e10.sfloat, Data(UInt16(0x07fe))) // too positive
        XCTAssertEqual((-1234e10).sfloat, Data(UInt16(0x0802))) // too negative
        XCTAssertEqual(Double.nan.sfloat, Data(UInt16(0x07ff))) // not a number
        XCTAssertEqual(1e-9.sfloat, Data(UInt16(0x0800))) // not at this positive resolution
        XCTAssertEqual((-1e-9).sfloat, Data(UInt16(0x0800))) // not at this positive resolution
        XCTAssertEqual(Double(2048).sfloat, Data(UInt16(0x10cc)))
        XCTAssertEqual(Double(2047).sfloat, Data(UInt16(0x10cc)))
        XCTAssertEqual(Double(2046).sfloat, Data(UInt16(0x10cc)))
        XCTAssertEqual(Double(2045).sfloat, Data(UInt16(0x07fd)))
        XCTAssertEqual(Double(-2048).sfloat, Data(UInt16(0x1f34)))
        XCTAssertEqual(Double(-2047).sfloat, Data(UInt16(0x1f34)))
        XCTAssertEqual(Double(-2046).sfloat, Data(UInt16(0x1f34)))
        XCTAssertEqual(Double(-2045).sfloat, Data(UInt16(0x0803)))
        
        // other cases
        XCTAssertEqual(Double(0).sfloat, Data(UInt16(0x0000)))
        XCTAssertEqual(Double(10000).sfloat, Data(UInt16(0x13e8)))
        XCTAssertEqual(Double(-200000).sfloat, Data(UInt16(0x2830)))
        XCTAssertEqual(Double(300000000).sfloat, Data(UInt16(0x612c)))
        XCTAssertEqual(Double(-4000000000).sfloat, Data(UInt16(0x7e70)))
        XCTAssertEqual(Double(2047e7).sfloat, Data(UInt16(0x77ff))) // largest positive
        XCTAssertEqual(Double(-2048e7).sfloat, Data(UInt16(0x7800))) // largest negative
        XCTAssertEqual((-0.1).sfloat, Data(UInt16(0xcc18))) // -1000e-4
        XCTAssertEqual(0.02.sfloat, Data(UInt16(0xb7d0))) // 2000e-5
        XCTAssertEqual((-0.003).sfloat, Data(UInt16(0xbed4))) // -300e-5
        XCTAssertEqual(0.0004.sfloat, Data(UInt16(0xa190))) // 400e-6
        XCTAssertEqual((-0.00123).sfloat, Data(UInt16(0xab32))) // -1230e-6
        XCTAssertEqual(0.000456.sfloat, Data(UInt16(0xa1c8))) // 456e-6
        XCTAssertEqual((-0.00000789).sfloat, Data(UInt16(0x8ceb))) // -789e-8

        // possible basal rates
        XCTAssertEqual(0.1.sfloat, Data(UInt16(0xc3e8))) // 1000e-4
        XCTAssertEqual(0.11.sfloat, Data(UInt16(0xc44c))) // 1100e-4
        XCTAssertEqual(2.28.sfloat, Data(UInt16(0xe0e4))) // 228e-2
        XCTAssertEqual(2.3.sfloat, Data(UInt16(0xe0e6))) // 230e-2
        XCTAssertEqual(10.25.sfloat, Data(UInt16(0xe401))) // 1025e-2
        XCTAssertEqual(20.5.sfloat, Data(UInt16(0xf0cd))) // 205e-1
        
        // iterate insulin delivery rates
        //  - positive values (mirror negative values just for stress testing)
        //  - hundreds resolution (include thousands just for stress testing)
        //  - max value of at least 205 (since this will stress test the 12-bit resolution of the mantissa)
        //  - range will be [-300.000 to 300.000]
        for thousandthsValue in -300000...300000 {
            let doubleValue = Double(thousandthsValue) / 1000
            switch doubleValue {
            case let value where value == 0:
                XCTAssertEqual(value.sfloat, Data(SFloatSpecialValue.zero.rawValue))
            case let value where value == 2047 || value == 2046:
                XCTAssertEqual(value.sfloat, Data(UInt16(0x10cc)))
            case let value where value == -2048 || value == -2047 || value == -2046:
                XCTAssertEqual(value.sfloat, Data(UInt16(0x1f34)))
            default:
                var shiftedvalue = thousandthsValue * 100000
                var exponent = -8
                
                while (shiftedvalue > 2047 || shiftedvalue < -2048) {
                    shiftedvalue /= 10
                    exponent += 1
                }
                
                if exponent < 0 {
                    // exponent is signed
                    exponent += 16
                }
                
                var data = Data(UInt16(shiftedvalue & 0x0fff))
                data[1] = data[1] | UInt8(exponent)<<4
                
                XCTAssertEqual(doubleValue.sfloat, data)
            }
        }
    }
    
    func testSFloatToDouble() {
        // iterate all possible values
        for sfloat: UInt16 in 0...65535 { // UInt16 is used for SFloat storage
            switch sfloat {
            case let value where value == SFloatSpecialValue.rfu.rawValue:
                XCTAssertTrue(Data(value).sfloatToDouble().isNaN)
            case let value where value == SFloatSpecialValue.nan.rawValue:
                XCTAssertTrue(Data(value).sfloatToDouble().isNaN)
            case let value where value == SFloatSpecialValue.nRes.rawValue:
                XCTAssertTrue(Data(value).sfloatToDouble().isNaN)
            case let value where value == SFloatSpecialValue.infinityPostive.rawValue:
                XCTAssertEqual(Data(value).sfloatToDouble(), Double.infinity)
            case let value where value == SFloatSpecialValue.infinityNegative.rawValue:
                XCTAssertEqual(Data(value).sfloatToDouble(), -Double.infinity)
            case let value where value <= 0x0fff:
                // exponent 0
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)))
            case let value where value <= 0x1fff:
                // exponent 1
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)*10))
            case let value where value <= 0x2fff:
                // exponent 2
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)*100))
            case let value where value <= 0x3fff:
                // exponent 3
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)*1000))
            case let value where value <= 0x4fff:
                // exponent 4
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)*10000))
            case let value where value <= 0x5fff:
                // exponent 5
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)*100000))
            case let value where value <= 0x6fff:
                // exponent 6
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)*1000000))
            case let value where value <= 0x7fff:
                // exponent 7
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value)*10000000))
            case let value where value <= 0x8fff:
                // exponent -8
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/100000000)
            case let value where value <= 0x9fff:
                // exponent -7
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/10000000)
            case let value where value <= 0xafff:
                // exponent -6
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/1000000)
            case let value where value <= 0xbfff:
                // exponent -5
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/100000)
            case let value where value <= 0xcfff:
                // exponent -4
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/10000)
            case let value where value <= 0xdfff:
                // exponent -3
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/1000)
            case let value where value <= 0xefff:
                // exponent -2
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/100)
            case let value where value <= 0xffff:
                // exponent -1
                XCTAssertEqual(Data(value).sfloatToDouble(), Double(extractMantissa(value))/10)
            default:
                XCTAssert(false, "default case should not be executed")
            }
        }
    }
}

extension SFloatTests {
    private func extractMantissa(_ sfloat: UInt16) -> Int {
        var mantissa = Int(sfloat & 0x0fff)
        if mantissa >= 0x0800 {
            mantissa -= 0x1000
        }
        return mantissa
    }
}
