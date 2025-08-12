//
//  UUIDValuePair.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth

public struct UUIDValuePair: CustomStringConvertible {
    public var value: Data
    public var uuid: CBUUID
    public var onSubscribedCentrals: [CBCentral]?
    
    public init (uuid: CBUUID,
                 value: Data,
                 onSubscribedCentrals: [CBCentral]? = nil)
    {
        self.value = value
        self.uuid = uuid
        self.onSubscribedCentrals = onSubscribedCentrals
    }
    
    public var description: String {
        return "UUID: \(uuid), value: \(value.hexadecimalString)\n"
    }
}
