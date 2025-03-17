//
//  Dictionary.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth

extension Dictionary where Key == String, Value == UInt16 {
    func toCBUUIDKeys() -> [CBUUID: UInt16]? {
        return Dictionary<CBUUID, UInt16>(uniqueKeysWithValues: self.map { uuidString, handle in
            (CBUUID(string: uuidString), handle)
        })
    }
}

extension Dictionary where Key: CBUUID, Value == UInt16 {
    func toCBUUIDStringKeys() -> [String: UInt16] {
        return Dictionary<String, UInt16>(uniqueKeysWithValues: self.map { uuid, handle in
            (uuid.uuidString, handle)
        })
    }
}
