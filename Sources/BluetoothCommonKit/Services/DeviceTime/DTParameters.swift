//
//  DTParameters.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-24.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth
import os.log

// MARK: - Support Server Implementation
public class DTParametersCharacteristic: ReadableCharacteristic, E2EProtection {
    public var e2eCounter: UInt8 = 0
    public weak var e2eDelegate: E2EProtectionDelegate?
    
    var messageQueue: MessagingQueue

    public required init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    public func createData() -> Data {
        let resolutionInFractionsOfASecond: UInt16 = 1
        var characteristicValue = Data(resolutionInFractionsOfASecond)
        
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            characteristicValue = characteristicValue.appendingCRCPrefix()
        }

        ConsoleOut.shared.logMessage(message: "\(#function) Device Time Parameters characteristic value: \(characteristicValue.hexadecimalString)")
        
        return characteristicValue
    }

    public func onRead() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading Device Time Parameters characteristic")
        return (CBATTError.Code.success, self.createData())
    }
}

// MARK: - Support Client Implementation
struct DTParameterDataHandler {
    static private let log = OSLog(category: "DTParameters")
    
    static func handleData(_ data: Data, features: DTFeatureFlag) -> DeviceCommResult<Any?> {
        guard data.count >= (features.contains(.supportedE2ECRC) ? 3 : 1) else {
            log.error("device time parameter characteristic incorrect format.")
            return .failure(.invalidFormat)
        }

        guard !features.contains(.supportedE2ECRC) || data.isCRCPrefixValid else {
            log.error("device time parameter CRC is invalid.")
            return .failure(.invalidCRC)
        }

        var index = 2 // skip CRC
        let realTimeClockResolution = data[data.startIndex.advanced(by: index)...].to(UInt16.self)
        index += 2
        
        var realTimeClockMaxDriftInSeconds: UInt16?
        var maxDaysUntilSyncLoss: UInt16?
        if features.contains(.supportedRTCDriftTracking) {
            realTimeClockMaxDriftInSeconds = data[data.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
            maxDaysUntilSyncLoss = data[data.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
        }
        
        var nonLoggedTimeAdjustmentLimitInSeconds: UInt16?
        if features.contains(.supportedTimeChangeLogging) {
            nonLoggedTimeAdjustmentLimitInSeconds = data[data.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
        }
        
        var displayFormats: UInt16?
        if features.contains(.supportedDisplayedFormats) {
            displayFormats = data[data.startIndex.advanced(by: index)...].to(UInt16.self)
        }

        log.debug("device time parameter: RTC resolution %{public}d, RTC max drift %{public}@, RTC max days to sync loss %{public}@, non-logged time adjustment limit (seconds) %{public}@, display formats %{public}@", realTimeClockResolution, String(describing: realTimeClockMaxDriftInSeconds), String(describing: maxDaysUntilSyncLoss), String(describing: nonLoggedTimeAdjustmentLimitInSeconds), String(describing: displayFormats))

        return .success(nil)
    }
}

extension PeripheralManager {
    func readDTParameters(timeout: TimeInterval) throws -> DeviceCommResult<DTFeatureFlag> {
        guard let characteristic = peripheral?.getDeviceTimetCharacteristicWithUUID(.parameters) else {
            throw PeripheralManagerError.unknownCharacteristic
        }

        do {
            guard let characteristicData = try readValue(for: characteristic, timeout: timeout) else {
                throw PeripheralManagerError.timeout
            }

            return DTFeaturesDataHandler.handleData(characteristicData)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}
