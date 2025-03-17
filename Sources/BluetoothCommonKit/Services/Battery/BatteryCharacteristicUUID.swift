//
//  BatteryCharacteristicUUID.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public enum BatteryCharacteristicUUID: String, CBUUIDDetails {
    case service = "180f"
    
    // Read, Notify
    // Notify is currently not supported
    case batteryLevel = "2a19"

    var name: String { "battery.level" }

    var properties: [CBUUIDProperties] { [.read, .notify] }

    func toPercent(_ data: Data) -> Int {
        return Int(data[data.startIndex...].to(UInt8.self))
    }
}

extension CBPeripheral {
    func getBatteryCharacteristicWithUUID(_ uuid: BatteryCharacteristicUUID, serviceUUID: BatteryCharacteristicUUID = .service) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }
        
        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}

extension PeripheralManager {
    func readBatteryLevel(timeout: TimeInterval) throws -> Int {
        guard let characteristic = peripheral?.getBatteryCharacteristicWithUUID(.batteryLevel) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            guard let characteristicData = try readValue(for: characteristic, timeout: timeout) else {
                throw PeripheralManagerError.timeout
            }
            
            guard characteristicData.count == 1 else {
                throw PeripheralManagerError.invalidResponse(characteristicData)
            }
            
            return BatteryCharacteristicUUID.batteryLevel.toPercent(characteristicData)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}
