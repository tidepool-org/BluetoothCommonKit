//
//  E2EProtection.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public protocol E2EProtectionDelegate: AnyObject {
    var isE2EProtectionSupported: Bool { get }
}

public protocol E2EProtection: AnyObject {
    var e2eCounter: UInt8 { get set }
    var e2eDelegate: E2EProtectionDelegate? { get set }
    func incrementE2ECounter()
    func resetE2ECounter()
    func appendingE2EProtection(_ request: Data) -> Data
}

public extension E2EProtection {
    func appendingE2EProtection(_ request: Data) -> Data {
        let e2eProtectedRequest = request.appendingE2ECounter(e2eCounter).appendingCRC()
        return e2eProtectedRequest
    }
    
    func incrementE2ECounter() {
        // range is 1...255
        if e2eCounter == 255 {
          e2eCounter = 0
        }
        e2eCounter += 1
    }
    
    func resetE2ECounter() {
        e2eCounter = Self.e2eCounterInitalValue
    }
    
    static var e2eCounterInitalValue: UInt8 {
        return 1
    }
}

public extension Data {
    func appendingE2ECounter(_ e2eCounter: UInt8) -> Data {
        var data = self
        data.append(e2eCounter)
        return data
    }
}
