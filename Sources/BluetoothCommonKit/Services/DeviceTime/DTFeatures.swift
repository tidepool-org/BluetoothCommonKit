//
//  DTFeatures.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth
import os.log

// MARK: - Support Server Implementation
public class DTFeaturesCharacteristic: E2EProtection {
    public var e2eCounter: UInt8 = 0
    public weak var e2eDelegate: E2EProtectionDelegate?
    
    var messageQueue: MessagingQueue

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    public func createData() -> Data {
        var flags: DTFeatureFlag = [.supportedEpochYear2000]
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            flags.insert(.supportedE2ECRC)
        }
        
        var characteristicValue = Data(flags.rawValue)
        
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            characteristicValue = characteristicValue.appendingCRCPrefix()
        } else {
            characteristicValue.insert(contentsOf: Data(UInt16(0xffff)), at: 0)
        }

        ConsoleOut.shared.logMessage(message: "\(#function) Device Time Feature characteristic value: \(characteristicValue.hexadecimalString)")
        
        return characteristicValue
    }

    public func onRead() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading Device Time Feature characteristic")
        return (CBATTError.Code.success, self.createData())
    }
}

// MARK: - Support Client Implementation
struct DTFeaturesDataHandler {
    static private let log = OSLog(category: "DTFeatures")
    
    static func handleData(_ data: Data) -> DeviceCommResult<DTFeatureFlag> {
        guard data.count == 4 else {
            log.error("device time feature characteristic incorrect format.")
            return .failure(.invalidFormat)
        }

        var index = 2 // skip CRC
        let flags = DTFeatureFlag(rawValue: data[data.startIndex.advanced(by: index)...].to(DTFeatureFlag.RawValue.self))
        index += 1

        if flags.contains(.supportedE2ECRC),
           !data.isCRCPrefixValid
        {
            log.error("device time feature CRC is invalid.")
            return .failure(.invalidCRC)
        }

        log.debug("device time features %{public}@", String(describing: flags))
        return .success(flags)
    }
}

extension PeripheralManager {
    func readDTFeatures(timeout: TimeInterval) throws -> DeviceCommResult<DTFeatureFlag> {
        guard let characteristic = peripheral?.getDeviceTimetCharacteristicWithUUID(.feature) else {
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

//MARK: - Option sets
struct DTFeatureFlag: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt16

    static let supportedE2ECRC  = DTFeatureFlag(rawValue: 1 << 0)
    static let supportedTimeChangeLogging = DTFeatureFlag(rawValue: 1 << 1)
    static let supportedBaseTimeSecondFractions = DTFeatureFlag(rawValue: 1 << 2)
    static let supportedTimeDateDisplayToUser = DTFeatureFlag(rawValue: 1 << 3)
    static let supportedDisplayedFormats = DTFeatureFlag(rawValue: 1 << 4)
    static let supportedDisplayedFormatsChangeable = DTFeatureFlag(rawValue: 1 << 5)
    static let supportedSeparateUserTimeline = DTFeatureFlag(rawValue: 1 << 6)
    static let supportedAuthorizationRequired = DTFeatureFlag(rawValue: 1 << 7)
    static let supportedRTCDriftTracking = DTFeatureFlag(rawValue: 1 << 8)
    static let supportedEpochYear1900 = DTFeatureFlag(rawValue: 1 << 9)
    static let supportedEpochYear2000 = DTFeatureFlag(rawValue: 1 << 10)
    static let supportedProposeNonLoggedTimeAdjustmentLimit = DTFeatureFlag(rawValue: 1 << 11)
    static let supportedRetrieveActiveTimeAdjustments = DTFeatureFlag(rawValue: 1 << 12)
    static let allZeros = DTFeatureFlag([])

    static let debugDescriptions: [DTFeatureFlag: String] = {
        var descriptions = [DTFeatureFlag: String]()
        descriptions[.supportedE2ECRC] = "supportedE2ECRC"
        descriptions[.supportedTimeChangeLogging] = "supportedTimeChangeLogging"
        descriptions[.supportedBaseTimeSecondFractions] = "supportedBaseTimeSecondFractions"
        descriptions[.supportedTimeDateDisplayToUser] = "supportedTimeDateDisplayToUser"
        descriptions[.supportedDisplayedFormats] = "supportedDisplayedFormats"
        descriptions[.supportedDisplayedFormatsChangeable] = "supportedDisplayedFormatsChangeable"
        descriptions[.supportedSeparateUserTimeline] = "supportedSeparateUserTimeline"
        descriptions[.supportedAuthorizationRequired] = "supportedAuthorizationRequired"
        descriptions[.supportedRTCDriftTracking] = "supportedRTCDriftTracking"
        descriptions[.supportedEpochYear1900] = "supportedEpochYear1900"
        descriptions[.supportedEpochYear2000] = "supportedEpochYear2000"
        descriptions[.supportedProposeNonLoggedTimeAdjustmentLimit] = "supportedProposeNonLoggedTimeAdjustmentLimit"
        descriptions[.supportedRetrieveActiveTimeAdjustments] = "supportedRetrieveActiveTimeAdjustments"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for key in DTFeatureFlag.debugDescriptions.keys {
            guard self.contains(key),
                let description = DTFeatureFlag.debugDescriptions[key] else { continue }

            result.append(description)
        }
        return "DTFeatureFlag(rawValue: \(rawValue)) \(result)"
    }
}
