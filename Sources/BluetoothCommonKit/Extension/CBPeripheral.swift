//
//  CBPeripheral.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import CoreBluetooth

// MARK: - Allow mocking
public protocol PeripheralProtocol: AnyObject {
    var services: [CBService]? { get }
    
    func servicesToDiscover(from serviceUUIDs: [CBUUID]) -> [CBUUID]
    
    func characteristicsToDiscover(from characteristicUUIDs: [CBUUID], for service: CBService) -> [CBUUID]
}

// MARK: - Discovery helpers.
public extension PeripheralProtocol {
    func servicesToDiscover(from serviceUUIDs: [CBUUID]) -> [CBUUID] {
        let knownServiceUUIDs = services?.compactMap({ $0.uuid }) ?? []
        return serviceUUIDs.filter({ !knownServiceUUIDs.contains($0) })
    }

    func characteristicsToDiscover(from characteristicUUIDs: [CBUUID], for service: CBService) -> [CBUUID] {
        let knownCharacteristicUUIDs = service.characteristics?.compactMap({ $0.uuid }) ?? []
        return characteristicUUIDs.filter({ !knownCharacteristicUUIDs.contains($0) })
    }
}

extension CBPeripheral: PeripheralProtocol { }

public extension Collection where Element: CBAttribute {
    func itemWithUUID(_ uuid: CBUUID) -> Element? {
        for attribute in self {
            if attribute.uuid == uuid {
                return attribute
            }
        }

        return nil
    }
    
    func itemWithUUIDString(_ uuidString: String) -> Element? {
        for attribute in self {
            if attribute.uuid.uuidString == uuidString {
                return attribute
            }
        }

        return nil
    }
}
