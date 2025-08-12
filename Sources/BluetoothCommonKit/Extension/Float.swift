//
//  Float.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public typealias FLOAT = UInt32

public extension FixedWidthInteger {
    // the returned value is in little endian
    var float: Data {
        return toFloat(initialExponent: 0)
    }

    // Takes a value shifted by initial exponent and calculates the Float representation.
    // the returned value is in little endian
    func toFloat(initialExponent: Int) -> Data {
        guard (-128...127).contains(initialExponent) else {
            fatalError("Float exponent can only be between -128 and 127: \(initialExponent)")
        }

        // compensate for the shifted value
        let multiplier = pow(10, Double(-initialExponent))
        let maxPositiveValue = FloatSpecialValue.maxValuePositive * multiplier
        let maxNegativeValue = FloatSpecialValue.maxValueNegative * multiplier

        switch self {
        case _ where maxPositiveValue.isLess(than: Double(self)):
            return Data(FloatSpecialValue.infinityPostive.rawValue)
        case _ where (8388607 * multiplier).isEqual(to: Double(self)):
            // 0x007fffff is a reserved value. 8388607 becomes 838860e1
            return Data(FLOAT(0x010ccccc))
        case _ where (8388606 * multiplier).isEqual(to: Double(self)):
            // 0x007ffffe is a reserved value. 8388606 becomes 838860e1
            return Data(FLOAT(0x010ccccc))
        case _ where (-2046 * multiplier).isEqual(to: Double(self)):
            // 0x0802 is a reserved value. -8388606 becomes -838860e1
            return Data(FLOAT(0x01f33334))
        case _ where (-2047 * multiplier).isEqual(to: Double(self)):
            // 0x00800001 is a reserved value. -8388607 becomes -838860e1
            return Data(FLOAT(0x01f33334))
        case _ where (-8388608 * multiplier).isEqual(to: Double(self)):
            // 0x00800000 is a reserved value. -8388608 becomes -838860e1
            return Data(FLOAT(0x01f33334))
        case _ where Double(self).isLess(than: maxNegativeValue):
            return Data(FloatSpecialValue.infinityNegative.rawValue)
        default:
            var exponent = initialExponent
            var value = self
            while (value > 8388607 || value < -8388608) {
                value /= 10
                exponent += 1
            }

            if exponent < 0 {
                // exponent is signed
                exponent += 256
            }

            var data = Data(FLOAT(value & 0x00ffffff))
            data[3] = UInt8(exponent)
            return data
        }
    }
}

public extension Double {
    // the returned value is in little endian
    var float: Data {
        switch self {
        case _ where self.isNaN:
            return Data(FloatSpecialValue.nan.rawValue)
        case _ where self == 0:
            return Data(FloatSpecialValue.zero.rawValue)
        case _ where abs(self).isLess(than: FloatSpecialValue.minResolution):
            return Data(FloatSpecialValue.nRes.rawValue)
        case _ where self > Double(FloatSpecialValue.maxValuePositive):
            return Data(FloatSpecialValue.infinityPostive.rawValue)
        case _ where self < Double(FloatSpecialValue.maxValueNegative):
            return Data(FloatSpecialValue.infinityNegative.rawValue)
        default:
            guard self <= Double(2047e7) && self >= Double(-2048e7) else {
                fatalError("Current Float convertion is only in range 2047e7 to -2048e7")
            }
            let shiftedValue = Int((self*1e8).rounded())
            return shiftedValue.toFloat(initialExponent: -8)
        }
    }
}

public extension Data {
    func floatToDouble() -> Double {
        guard self.count == 4 else {
            fatalError("Float is a 32-bit value: \(self.toHexString())")
        }
        
        guard self != Data(FloatSpecialValue.rfu.rawValue) else {
            return Double.nan
        }
        
        guard self != Data(FloatSpecialValue.nan.rawValue),
            self != Data(FloatSpecialValue.nRes.rawValue) else
        {
            return Double.nan
        }
        
        guard self != Data(FloatSpecialValue.infinityPostive.rawValue) else {
            return Double.infinity
        }
        
        guard self != Data(FloatSpecialValue.infinityNegative.rawValue) else {
            return -1*Double.infinity
        }
        
        let number = self[startIndex...].to(FLOAT.self)
        var exponent = Int((number & 0xff000000) >> 24)
        if exponent >= 128 {
            // exponent is signed and should be negative
            exponent -= 256
        }
        
        var mantissa = Int(number & 0x00ffffff)
        if (mantissa >= 8388608) {
            // mantissa is signed and should be negative
            mantissa -= 16777216
        }
        
        if exponent < 0 {
            return Double(mantissa) / pow(10, Double(-exponent))
        } else {
            return Double(mantissa) * pow(10, Double(exponent))
        }
    }
}

public enum FloatSpecialValue: FLOAT {
    case zero = 0x00000000
    case infinityPostive = 0x007ffffe
    case nan = 0x007fffff
    case nRes = 0x00800000 // not at this resolution
    case rfu = 0x00800001 // reserved for future use
    case infinityNegative = 0x00800002
    
    static var maxValuePositive: Double {
        return 8388607e127
    }
    
    static var maxValueNegative: Double {
        return -8388608e127
    }
    
    static var minResolution: Double {
        return 1e-128
    }
}
