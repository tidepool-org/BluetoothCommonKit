//
//  TimeInterval.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public extension TimeInterval {
    
    static func days(_ days: Int) -> TimeInterval {
        return self.init(days: days)
    }
    
    static func days(_ days: Double) -> TimeInterval {
        return self.init(days: days)
    }
    
    static func hours(_ hours: Int) -> TimeInterval {
        return self.init(hours: hours)
    }
    
    static func hours(_ hours: Double) -> TimeInterval {
        return self.init(hours: hours)
    }
    
    static func minutes(_ minutes: Int) -> TimeInterval {
        return self.init(minutes: minutes)
    }
    
    static func minutes(_ minutes: Double) -> TimeInterval {
        return self.init(minutes: minutes)
    }
    
    static func seconds(_ seconds: Int) -> TimeInterval {
        return self.init(seconds)
    }
    
    static func seconds(_ seconds: Double) -> TimeInterval {
        return self.init(seconds)
    }
    
    static func milliseconds(_ milliseconds: Int) -> TimeInterval {
        return self.init(milliseconds: milliseconds)
    }
    
    static func milliseconds(_ milliseconds: Double) -> TimeInterval {
        return self.init(milliseconds: milliseconds)
    }

    static func hundredthsOfMilliseconds(_ hundredthsOfMilliseconds: Int) -> TimeInterval {
        return self.init(hundredthsOfMilliseconds:hundredthsOfMilliseconds)
    }
    
    static func hundredthsOfMilliseconds(_ hundredthsOfMilliseconds: Double) -> TimeInterval {
        return self.init(hundredthsOfMilliseconds: hundredthsOfMilliseconds)
    }
    
    static func hundredthsOfMicroseconds(_ hundredthsOfMicroseconds: Int) -> TimeInterval {
        return self.init(hundredthsOfMicroseconds: hundredthsOfMicroseconds)
    }
    
    static func hundredthsOfMicroseconds(_ hundredthsOfMicroseconds: Double) -> TimeInterval {
        return self.init(hundredthsOfMicroseconds: hundredthsOfMicroseconds)
    }
    
    init(days: Int) {
        self.init(days: Double(days))
    }
    
    init(days: Double) {
        self.init(hours: days * 24)
    }
    
    init(hours: Int) {
        self.init(hours: Double(hours))
    }
    
    init(hours: Double) {
        self.init(minutes: hours * 60)
    }
    
    init(minutes: Int) {
        self.init(minutes: Double(minutes))
    }
    
    init(minutes: Double) {
        self.init(minutes * 60)
    }
    
    init(seconds: Int) {
        self.init(seconds: Double(seconds))
    }
    
    init(seconds: Double) {
        self.init(seconds)
    }
    
    init(milliseconds: Int) {
        self.init(milliseconds: Double(milliseconds))
    }
    
    init(milliseconds: Double) {
        self.init(milliseconds / 1000)
    }
    
    init(hundredthsOfMilliseconds: Int) {
        self.init(hundredthsOfMilliseconds: Double(hundredthsOfMilliseconds))
    }
    
    init(hundredthsOfMilliseconds: Double) {
        self.init(hundredthsOfMilliseconds / 100000)
    }
    
    init(hundredthsOfMicroseconds: Int) {
        self.init(hundredthsOfMicroseconds: Double(hundredthsOfMicroseconds))
    }
    
    init(hundredthsOfMicroseconds: Double) {
        self.init(hundredthsOfMicroseconds / 100000000)
    }
    
    var days: Double {
        return hours / 24.0
    }
    
    var hours: Double {
        return minutes / 60.0
    }

    var minutes: Double {
        return self / 60.0
    }
    
    var seconds: Double {
        return self
    }
    
    var milliseconds: Double {
        return self * 1000
    }
        
    var hundredthsOfMilliseconds: Double {
        return self * 100000
    }
    
    var hundredthsOfMicroseconds: Double {
        return self * 100000000
    }
}
