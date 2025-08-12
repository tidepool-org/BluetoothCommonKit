//
//  ImmediateAlertCharacteristicUUID.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public enum ImmediateAlertCharacteristicUUID: String, CBUUIDDetails {
    case service = "1802"
    
    // Write without response
    case alertLevel = "2a06"

    public var name: String { "immediateAlert.level" }

    public var properties: [CBUUIDProperties] { [.write] }
}

public struct ImmediateAlertService {
    static public func createBeepRequest() -> Data {
        return Data(AlertType.mildAlert.rawValue)
    }
}

public extension CBPeripheral {
    func getImmediateAlertCharacteristicWithUUID(_ uuid: ImmediateAlertCharacteristicUUID, serviceUUID: ImmediateAlertCharacteristicUUID = .service) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }

        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}


public extension PeripheralManager {
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
