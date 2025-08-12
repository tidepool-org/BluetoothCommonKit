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
        
        guard self != Data(SFloatSpecialValue.rfu.rawValue) else {
            return Double.nan
        }
        
        guard self != Data(SFloatSpecialValue.nan.rawValue),
            self != Data(SFloatSpecialValue.nRes.rawValue) else
        {
            return Double.nan
        }
        
        guard self != Data(SFloatSpecialValue.infinityPostive.rawValue) else {
            return Double.infinity
        }
        
        guard self != Data(SFloatSpecialValue.infinityNegative.rawValue) else {
            return -1*Double.infinity
        }
        
        let number = self[startIndex...].to(SFLOAT.self)
        var exponent = Int((number & 0xf000) >> 12)
        if exponent >= 8 {
            // exponent is signed and should be negative
            exponent -= 16
        }
        
        var mantissa = Int(number & 0x0fff)
        if (mantissa >= 2048) {
            // mantissa is signed and should be negative
            mantissa -= 4096
        }
        
        if exponent < 0 {
            return Double(mantissa) / pow(10, Double(-exponent))
        } else {
            return Double(mantissa) * pow(10, Double(exponent))
        }
    }
}
