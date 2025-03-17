//
//  DeviceTimeCharacteristicUUID.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public enum DeviceTimeCharacteristicUUID: String, CBUUIDDetails {
    
    case service = "1847"

    // Read (Optional Indicate)
    case feature = "2b8e"

    // Read (Optional Indicate)
    case parameters = "2b8f"

    // Read, Indicate
    case deviceTime = "2b90"

    // Write, Indicate
    case controlPoint = "2b91"

    var serviceName: String { "deviceTime"}

    var name: String {
        switch self {
        case .service: return serviceName + ".deviceTimeService"
        case .feature: return serviceName + ".feature"
        case .parameters: return serviceName + ".parameters"
        case .deviceTime: return serviceName + ".deviceTime"
        case .controlPoint: return serviceName + ".controlPoint"
        }
    }

    var properties: [CBUUIDProperties] {
        switch self {
        case .service:
            return []
        case .feature, .parameters:
            return [.read]
        case .deviceTime:
            return [.read, .indicate]
        case .controlPoint:
            return [.write, .indicate]
        }
    }
}

extension CBPeripheral {
    func getDeviceTimetCharacteristicWithUUID(_ uuid: DeviceTimeCharacteristicUUID, serviceUUID: DeviceTimeCharacteristicUUID = .service) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }

        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}
