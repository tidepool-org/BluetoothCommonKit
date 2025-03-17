//
//  CBUUIDDetails.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public protocol CBUUIDDetails: CBUUIDRawValue {
    var name: String { get }
    var properties: [CBUUIDProperties] { get }
    var procedureID: ProcedureID { get }
}

public extension CBUUIDDetails {
    var procedureID: ProcedureID {
        if self.properties.contains(.read) {
            return name + ".read"
        } else if self.properties.contains(.write) {
            return name + ".write"
        } else if self.properties.contains(.notify) || self.properties.contains(.indicate) {
            return name + ".receive"
        } else {
            return name
        }
    }
}

public enum CBUUIDProperties: String {
    case read
    case indicate
    case notify
    case write
}
