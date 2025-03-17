//
//  Float.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public typealias FLOAT = UInt32

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
