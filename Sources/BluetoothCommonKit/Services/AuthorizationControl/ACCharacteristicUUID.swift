//
//  ACCharacteristicUUID.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public enum ACCharacteristicUUID: String, CBUUIDDetails {
    case service = "183d"

    // Read, Indicate
    case status = "2b2f"
    
    // Write
    case dataIn = "2b30"
    
    // Notify
    case dataOutNotify = "2b31"
    
    // Indicate
    case dataOutIndicate = "2b32"
    
    // Write, Indicate
    case controlPoint = "2b33"

    var serviceName: String { "authorizationControl" }

    public var name: String {
        switch self {
        case .service: return serviceName
        case .status: return serviceName + ".status"
        case .dataIn: return serviceName + ".dataIn"
        case .dataOutNotify: return serviceName + ".dataOutNotify"
        case .dataOutIndicate: return serviceName + ".dataOutIndicate"
        case .controlPoint: return serviceName + ".controlPoint"
        }
    }

    public var properties: [CBUUIDProperties] {
        switch self {
        case .service: return []
        case .status: return [.read, .indicate]
        case .dataIn: return [.write]
        case .dataOutNotify: return [.notify]
        case .dataOutIndicate: return [.indicate]
        case .controlPoint: return [.write, .indicate]
        }
    }
}

public extension CBPeripheral {
    func getACSCharacteristicWithUUID(_ uuid: ACCharacteristicUUID, serviceUUID: ACCharacteristicUUID = .service) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }

        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}
