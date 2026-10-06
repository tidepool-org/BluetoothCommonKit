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

// MARK: - Canonical codec (SFloat.encode / decode)

extension SFloatTests {
    func testCanonicalEncodePrefersExponentZeroForIntegers() {
        XCTAssertEqual(SFloat.encode(100), 0x0064)
        XCTAssertEqual(SFloat.encode(95), 0x005f)
        XCTAssertEqual(SFloat.encode(400), 0x0190)
        XCTAssertEqual(SFloat.encode(0), 0x0000)
    }

    func testCanonicalEncodeKeepsFractionalPrecision() {
        XCTAssertEqual(SFloat.encode(120.5), 0xf4b5)   // 1205 e-1
        XCTAssertEqual(SFloat.encode(-1.25), 0xef83)   // -125 e-2
        XCTAssertEqual(SFloat.encode(0.3), 0xf003)     // 3 e-1
    }

    func testCanonicalSpecialValues() {
        XCTAssertEqual(SFloat.encode(.nan), SFloatSpecialValue.nan.rawValue)
        XCTAssertEqual(SFloat.encode(.infinity), SFloatSpecialValue.infinityPostive.rawValue)
        XCTAssertEqual(SFloat.encode(-.infinity), SFloatSpecialValue.infinityNegative.rawValue)
        XCTAssertEqual(SFloat.encode(1e12), SFloatSpecialValue.infinityPostive.rawValue)
        XCTAssertEqual(SFloat.encode(-1e12), SFloatSpecialValue.infinityNegative.rawValue)
        XCTAssertTrue(SFloat.decode(SFloatSpecialValue.nan.rawValue).isNaN)
        XCTAssertTrue(SFloat.decode(SFloatSpecialValue.nRes.rawValue).isNaN)
        XCTAssertTrue(SFloat.decode(SFloatSpecialValue.rfu.rawValue).isNaN)
        XCTAssertEqual(SFloat.decode(SFloatSpecialValue.infinityPostive.rawValue), .infinity)
        XCTAssertEqual(SFloat.decode(SFloatSpecialValue.infinityNegative.rawValue), -.infinity)
    }

    func testCanonicalEncodeAvoidsReservedMantissaAtExponentZero() {
        for value in [2046.0, 2047.0, -2046.0, -2047.0, -2048.0] {
            let raw = SFloat.encode(value)
            XCTAssertNil(SFloatSpecialValue(rawValue: raw), "\(value) must not encode to a special value")
            XCTAssertEqual(SFloat.decode(raw), value, accuracy: 5)
        }
    }

    func testCanonicalRoundTripIsExactForFractions() {
        // Values whose decimal mantissa has no exact binary form still round-trip exactly thanks to division.
        for value in [0.3, 0.6, 0.7, 2.3, 1.1, 0.05, 123.4, -0.3] {
            XCTAssertEqual(SFloat.decode(SFloat.encode(value)), value)
        }
    }

    /// The 12-bit mantissa tops out at 2047, so a value keeps three or four significant digits depending on its
    /// leading digits (204.8 must become 205e0, not 2048e-1). The precision of each encoding is therefore one unit
    /// in the last place of the exponent it actually chose: the canonical encoder rounds (error at most half a unit)
    /// and the legacy encoder truncates (error under one unit).
    func testCanonicalEncodeStaysWithinMantissaPrecision() {
        for thousandths in stride(from: -300000, through: 300000, by: 7) {
            let value = Double(thousandths) / 1000
            let canonicalRaw = SFloat.encode(value)
            let legacyRaw = value.sfloat.to(SFLOAT.self)
            let canonical = SFloat.decode(canonicalRaw)
            let legacy = SFloat.decode(legacyRaw)
            let canonicalUnit = pow(10, Double(exponent(of: canonicalRaw)))
            let legacyUnit = pow(10, Double(exponent(of: legacyRaw)))
            XCTAssertEqual(canonical, value, accuracy: 0.5 * canonicalUnit + 1e-9, "canonical \(value)")
            XCTAssertEqual(legacy, value, accuracy: legacyUnit + 1e-9, "legacy \(value)")
            XCTAssertEqual(canonical, legacy, accuracy: 0.5 * canonicalUnit + legacyUnit + 1e-9, "legacy vs canonical \(value)")
        }
    }

    /// Every finite SFLOAT code must survive decode -> encode -> decode unchanged.
    func testCanonicalRoundTripsEveryCode() {
        for raw in SFLOAT.min...SFLOAT.max {
            let value = SFloat.decode(raw)
            guard value.isFinite else { continue }
            XCTAssertEqual(SFloat.decode(SFloat.encode(value)), value, String(format: "0x%04X", raw))
        }
    }

    func testCanonicalEncodeHandlesMagnitudesBeyondInt() {
        XCTAssertEqual(SFloat.encode(1e300), SFloatSpecialValue.infinityPostive.rawValue)
        XCTAssertEqual(SFloat.encode(-1e300), SFloatSpecialValue.infinityNegative.rawValue)
        XCTAssertEqual(SFloat.encode(.greatestFiniteMagnitude), SFloatSpecialValue.infinityPostive.rawValue)
        XCTAssertEqual(SFloat.encode(-.greatestFiniteMagnitude), SFloatSpecialValue.infinityNegative.rawValue)
    }

    func testCanonicalEncodeUsesFullMantissaRangeAtNegativeExponents() {
        XCTAssertEqual(SFloat.encode(-204.8), 0xf800)  // -2048 e-1; 0x800 is only reserved at exponent 0
        XCTAssertEqual(SFloat.encode(2.047), 0xd7ff)   // 2047 e-3
        XCTAssertEqual(SFloat.encode(204.7), 0xf7ff)   // 2047 e-1
    }

    func testAppendSFloat() {
        var data = Data()
        data.appendSFloat(120.5)
        XCTAssertEqual(data, Data([0xb5, 0xf4]))
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

    /// The signed 4-bit base-10 exponent stored in the top nibble.
    private func exponent(of sfloat: SFLOAT) -> Int {
        var exponent = Int(sfloat >> 12)
        if exponent >= 8 {
            exponent -= 16
        }
        return exponent
    }
}
