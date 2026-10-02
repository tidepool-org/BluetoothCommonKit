//
//  SFloat.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public typealias SFLOAT = UInt16

public extension FixedWidthInteger {
    // the returned value is in little endian
    var sfloat: Data {
        return toSFloat(initialExponent: 0)
    }
    
    // Takes a value shifted by initial exponent and calculates the SFloat representation.
    // the returned value is in little endian
    func toSFloat(initialExponent: Int) -> Data {
        guard (-8...7).contains(initialExponent) else {
            fatalError("SFloat exponent can only be between -8 and 7: \(initialExponent)")
        }
    
        // compensate for the shifted value
        let multiplier = pow(10, Double(-initialExponent))
        let maxPositiveValue = SFloatSpecialValue.maxValuePositive * multiplier
        let maxNegativeValue = SFloatSpecialValue.maxValueNegative * multiplier
        
        switch self {
        case _ where maxPositiveValue.isLess(than: Double(self)):
            return Data(SFloatSpecialValue.infinityPostive.rawValue)
        case _ where (2047 * multiplier).isEqual(to: Double(self)):
            // 0x07ff is a reserved value. 2047 becomes 204e1
            return Data(SFLOAT(0x10cc))
        case _ where (2046 * multiplier).isEqual(to: Double(self)):
            // 0x07fe is a reserved value. 2046 becomes 204e1
            return Data(SFLOAT(0x10cc))
        case _ where (-2046 * multiplier).isEqual(to: Double(self)):
            // 0x0802 is a reserved value. -2046 becomes -204e1
            return Data(SFLOAT(0x1f34))
        case _ where (-2047 * multiplier).isEqual(to: Double(self)):
            // 0x0801 is a reserved value. -2047 becomes -204e1
            return Data(SFLOAT(0x1f34))
        case _ where (-2048 * multiplier).isEqual(to: Double(self)):
            // 0x0800 is a reserved value. -2048 becomes -204e1
            return Data(SFLOAT(0x1f34))
        case _ where Double(self).isLess(than: maxNegativeValue):
            return Data(SFloatSpecialValue.infinityNegative.rawValue)
        default:
            var exponent = initialExponent
            var value = self
            while (value > 2047 || value < -2048) {
                value /= 10
                exponent += 1
            }

            if exponent < 0 {
                // exponent is signed
                exponent += 16
            }
            
            var data = Data(SFLOAT(value & 0x0fff))
            data[1] = data[1] | UInt8(exponent)<<4
            return data
        }
    }
}

public enum SFloatSpecialValue: SFLOAT {
    case zero = 0x0000
    case infinityPostive = 0x07fe
    case nan = 0x07ff
    case nRes = 0x0800 // not at this resolution
    case rfu = 0x0801 // reserved for future use
    case infinityNegative = 0x0802

    static var maxValuePositive: Double {
        return 20470000000
    }

    static var maxValueNegative: Double {
        return -20480000000
    }

    static var minResolution: Double {
        return 1e-8
    }
}

/// IEEE 11073-20601 SFLOAT codec: 4-bit signed base-10 exponent, 12-bit signed mantissa.
///
/// `encode` is the canonical form shared by the GATT health services: integral values use exponent 0
/// (100 mg/dL -> 0x0064) and fractional values keep as much precision as the mantissa allows.
/// `Double.sfloat` / `FixedWidthInteger.toSFloat` remain for the Insulin Delivery Service's established
/// 1e-8-shifted encoding; both decode identically through `decode`.
public enum SFloat {
    private static let mantissaRange = -2048...2047
    private static let exponentRange = -8...7

    public static func encode(_ value: Double) -> SFLOAT {
        if value.isNaN { return SFloatSpecialValue.nan.rawValue }
        if value == .infinity { return SFloatSpecialValue.infinityPostive.rawValue }
        if value == -.infinity { return SFloatSpecialValue.infinityNegative.rawValue }

        var exponent = 0
        var mantissa = value

        // Gain fractional precision while the mantissa still fits.
        while exponent > exponentRange.lowerBound,
              !isIntegral(mantissa),
              abs(mantissa * 10) <= Double(mantissaRange.upperBound)
        {
            mantissa *= 10
            exponent -= 1
        }

        // Shed magnitude until the mantissa fits.
        while exponent < exponentRange.upperBound,
              !mantissaRange.contains(Int(mantissa.rounded()))
        {
            mantissa /= 10
            exponent += 1
        }

        var rounded = Int(mantissa.rounded())
        guard mantissaRange.contains(rounded) else {
            return value > 0 ? SFloatSpecialValue.infinityPostive.rawValue : SFloatSpecialValue.infinityNegative.rawValue
        }

        // Exponent 0 with mantissa 0x7FE...0x802 collides with the special values; step up one decade.
        if exponent == 0, rounded >= 2046 || rounded <= -2046 {
            rounded = Int((Double(rounded) / 10).rounded())
            exponent = 1
        }

        let exponentBits = SFLOAT(truncatingIfNeeded: exponent) & 0x000f
        let mantissaBits = SFLOAT(truncatingIfNeeded: rounded) & 0x0fff
        return exponentBits << 12 | mantissaBits
    }

    public static func decode(_ raw: SFLOAT) -> Double {
        switch raw {
        case SFloatSpecialValue.nan.rawValue, SFloatSpecialValue.nRes.rawValue, SFloatSpecialValue.rfu.rawValue:
            return .nan
        case SFloatSpecialValue.infinityPostive.rawValue:
            return .infinity
        case SFloatSpecialValue.infinityNegative.rawValue:
            return -.infinity
        default:
            break
        }

        var exponent = Int(raw >> 12)
        if exponent >= 8 { exponent -= 16 }

        var mantissa = Int(raw & 0x0fff)
        if mantissa >= 2048 { mantissa -= 4096 }

        // Divide for negative exponents: 3 / 10 is exactly 0.3, while 3 * 0.1 is not.
        if exponent < 0 {
            return Double(mantissa) / pow(10, Double(-exponent))
        }
        return Double(mantissa) * pow(10, Double(exponent))
    }

    private static func isIntegral(_ value: Double) -> Bool {
        abs(value - value.rounded()) <= 1e-9 * max(1, abs(value))
    }
}

public extension Data {
    /// Appends `value` as a canonical little-endian SFLOAT (see `SFloat.encode`).
    mutating func appendSFloat(_ value: Double) {
        append(SFloat.encode(value))
    }
}

public extension Double {
    // the returned value is in little endian
    var sfloat: Data {
        switch self {
        case _ where self.isNaN:
            return Data(SFloatSpecialValue.nan.rawValue)
        case _ where self == 0:
            return Data(SFloatSpecialValue.zero.rawValue)
        case _ where abs(self).isLess(than: SFloatSpecialValue.minResolution):
            return Data(SFloatSpecialValue.nRes.rawValue)
        case _ where self > Double(SFloatSpecialValue.maxValuePositive):
            return Data(SFloatSpecialValue.infinityPostive.rawValue)
        case _ where self < Double(SFloatSpecialValue.maxValueNegative):
            return Data(SFloatSpecialValue.infinityNegative.rawValue)
        default:
            // the resolution of SFloat is only to 1e-8. Create an Int by shifting the value to the left and removing any inaccuracy
            let shiftedValue = Int((self*1e8).rounded())
            return shiftedValue.toSFloat(initialExponent: -8)
        }
    }
}

public extension Data {
    // bytes are expected in little endian
    func sfloatToDouble() -> Double {
        guard self.count == 2 else {
            fatalError("SFloat is a 16-bit value: \(self.toHexString())")
        }

        return SFloat.decode(self[startIndex...].to(SFLOAT.self))
    }
}
