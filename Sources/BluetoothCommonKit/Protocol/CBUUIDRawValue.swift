//
//  CBUUIDRawValue.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public protocol CBUUIDRawValue: RawRepresentable {}

public extension CBUUIDRawValue where RawValue == String {
    var cbUUID: CBUUID {
        return CBUUID(string: rawValue)
    }
    var uuidValue: UInt16 {
        UInt16(rawValue, radix: 16)!
    }
}
