//
//  DeviceInformationCharacteristics.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth

public class DeviceInformationCharacteristics {
    var messageQueue: MessagingQueue

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }

    public func createDataManufacturerName(_ manufacturerName: String = "Tidepool") -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function): manufacturer name is \(manufacturerName)")
        return manufacturerName.data(using: .utf8) ?? Data()
    }

    public func onReadManufacturerName() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading manufacturer name characteristic")
        return (CBATTError.Code.success, self.createDataManufacturerName())
    }

    public func createDataModelNumber(_ modelNumber: String = "123xyz") -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function): model numebr is \(modelNumber)")
        return modelNumber.data(using: .utf8) ?? Data()
    }

    public func onReadModelNumber() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading model number characteristic")
        return (CBATTError.Code.success, self.createDataModelNumber())
    }

    public func createDataSerialNumber(_ serialNumber: String = "12345678") -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function): serial number is \(serialNumber)")
        return serialNumber.data(using: .utf8) ?? Data()
    }

    public func onReadSerialNumber() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading serial number characteristic")
        return (CBATTError.Code.success, self.createDataSerialNumber())
    }

    public func createDataHardwareRevision(_ hardwareRevision: String = "1.2.3") -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function): hardware revision is \(hardwareRevision)")
        return hardwareRevision.data(using: .utf8) ?? Data()
    }

    public func onReadHardwareRevision() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading hardware revision characteristic")
        return (CBATTError.Code.success, self.createDataHardwareRevision())
    }

    public func createDataFirmwareRevision(_ firmwareRevision: String = "4.5.6") -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function): firmware revision is \(firmwareRevision)")
        return firmwareRevision.data(using: .utf8) ?? Data()
    }

    public func onReadFirmwareRevision() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading firmware revision characteristic")
        return (CBATTError.Code.success, self.createDataFirmwareRevision())
    }

    public func createDataSoftwareRevision(_ softwareRevision: String = "7.8.9") -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function): software revision is \(softwareRevision)")
        return softwareRevision.data(using: .utf8) ?? Data()
    }

    public func onReadSoftwareRevision() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading software revision characteristic")
        return (CBATTError.Code.success, self.createDataSoftwareRevision())
    }

    public func createDataUniqueDeviceIdentifier(
        flags: UDIFlag = [.presentLabel, .presentIssuer, .presentAuthority, .presentDeviceIdentifier],
        label: String = "L0",
        deviceIdentifier: String = "DI0",
        issuer: String = "I0",
        authority: String = "A0") -> Data
    {
        var udi = Data(flags.rawValue)
        udi.append(label.data(using: .utf8) ?? Data())
        udi.append(deviceIdentifier.data(using: .utf8) ?? Data())
        udi.append(issuer.data(using: .utf8) ?? Data())
        udi.append(authority.data(using: .utf8) ?? Data())

        ConsoleOut.shared.logMessage(message: "\(#function): unique device identifier is \(udi)")

        return udi
    }

    public func onReadUniqueDeviceIdentifier() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading unique device identifier characteristic")
        return (CBATTError.Code.success, self.createDataUniqueDeviceIdentifier())
    }
}
