//
//  DeviceInfoCharacteristicUUID.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public enum DeviceInfoCharacteristicUUID: String, CBUUIDDetails {
    case service = "180a"
    
    // Read
    case manufacturerNameString = "2a29"
    
    // Read
    case modelNumberString = "2a24"
    
    // Read
    case serialNumberString = "2a25"
    
    // Read
    case firmwareRevisionString = "2a26"
    
    // Read
    case hardwareRevisionString = "2a27"
    
    // Read
    case softwareRevisionString = "2a28"
    
    // Read
    case systemID = "2a23"
    
    // Read
    case regulatoryCertificationDataList = "2a2A"
    
    // Read
    case pnpID = "2a50"
    
    // Read
    case uniqueDeviceIdentifierString = "7f3a" // actual value is unknown

    var serviceName: String { "deviceInformation"}

    public var name: String {
        switch self {
        case .service: return serviceName
        case .manufacturerNameString: return serviceName + ".manufacturerNameString"
        case .modelNumberString: return serviceName + ".modelNumberString"
        case .serialNumberString: return serviceName + ".serialNumberString"
        case .firmwareRevisionString: return serviceName + ".firmwareRevisionString"
        case .hardwareRevisionString: return serviceName + ".hardwareRevisionString"
        case .softwareRevisionString: return serviceName + ".softwareRevisionString"
        case .systemID: return serviceName + ".systemID"
        case .regulatoryCertificationDataList: return serviceName + ".regulatoryCertificationDataList"
        case .pnpID: return serviceName + ".pnpID"
        case .uniqueDeviceIdentifierString: return serviceName + ".uniqueDeviceIdentifierString"
        }
    }

    public var properties: [CBUUIDProperties] { [.read] }
    
    public func toString(_ data: Data) -> String? {
        switch self {
        case .manufacturerNameString, .modelNumberString, .serialNumberString, .hardwareRevisionString, .firmwareRevisionString, .softwareRevisionString:
            return String(bytes: data, encoding: .utf8)
        default:
            return nil
        }
    }
}

public extension CBPeripheral {
    func getDISCharacteristicWithUUID(_ uuid: DeviceInfoCharacteristicUUID, serviceUUID: DeviceInfoCharacteristicUUID = .service) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }
        
        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}

public extension PeripheralManager {
    func readCharacteristicStringValue(_ characteristic: CBCharacteristic, timeout: TimeInterval) throws -> String {
        do {
            guard let characteristicData = try readValue(for: characteristic, timeout: timeout) else {
                throw PeripheralManagerError.timeout
            }
            
            guard let stringValue = String(bytes: characteristicData, encoding: .utf8) else {
                throw PeripheralManagerError.invalidResponse(characteristicData)
            }
            
            return stringValue
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
    
    func readDISManufacturerName(timeout: TimeInterval) throws -> String {
        guard let characteristic = peripheral?.getDISCharacteristicWithUUID(.manufacturerNameString) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            return try readCharacteristicStringValue(characteristic, timeout: timeout)
        } catch let error {
            throw error
        }
    }
    
    func readDISModelNumber(timeout: TimeInterval) throws -> String {
        guard let characteristic = peripheral?.getDISCharacteristicWithUUID(.modelNumberString) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            return try readCharacteristicStringValue(characteristic, timeout: timeout)
        } catch let error {
            throw error
        }
    }
    
    func readDISSerialNumber(timeout: TimeInterval) throws -> String {
        guard let characteristic = peripheral?.getDISCharacteristicWithUUID(.serialNumberString) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            return try readCharacteristicStringValue(characteristic, timeout: timeout)
        } catch let error {
            throw error
        }
    }
    
    func readDISFirmwareRevision(timeout: TimeInterval) throws -> String {
        guard let characteristic = peripheral?.getDISCharacteristicWithUUID(.firmwareRevisionString) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            return try readCharacteristicStringValue(characteristic, timeout: timeout)
        } catch let error {
            throw error
        }
    }
    
    func readDISHardwareRevision(timeout: TimeInterval) throws -> String {
        guard let characteristic = peripheral?.getDISCharacteristicWithUUID(.hardwareRevisionString) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            return try readCharacteristicStringValue(characteristic, timeout: timeout)
        } catch let error {
            throw error
        }
    }
}
