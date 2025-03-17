//
//  ImmediateAlertCharacteristicUUID.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

enum ImmediateAlertCharacteristicUUID: String, CBUUIDDetails {
    case service = "1802"
    
    // Write without response
    case alertLevel = "2a06"

    var name: String { "immediateAlert.level" }

    var properties: [CBUUIDProperties] { [.write] }
}

enum AlertType: UInt8 {
    case noAlert
    case mildAlert
    case highAlert
}

struct ImmediateAlertService {
    static func createBeepRequest() -> Data {
        return Data(AlertType.mildAlert.rawValue)
    }
}

extension CBPeripheral {
    func getImmediateAlertCharacteristicWithUUID(_ uuid: ImmediateAlertCharacteristicUUID, serviceUUID: ImmediateAlertCharacteristicUUID = .service) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }

        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}


extension PeripheralManager {
    func writeAlertLevelRequest(_ request: Data, type: CBCharacteristicWriteType = .withoutResponse, timeout: TimeInterval) throws {
        guard let characteristic = peripheral?.getImmediateAlertCharacteristicWithUUID(.alertLevel) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            try writeValue(request, for: characteristic, type: type, timeout: timeout)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}
