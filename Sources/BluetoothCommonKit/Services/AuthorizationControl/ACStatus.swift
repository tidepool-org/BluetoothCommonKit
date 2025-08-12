//
//  ACStatus.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth
import os.log

public typealias RestrictionMapID = UInt16

// MARK: - Support Server Implementation
public class ACStatusCharacteristic {
    private let log = OSLog(category: "ACStatusCharacteristic")
    var messageQueue: MessagingQueue
    public var isSecurityEstablished = false
    public var currentRestrictionMapID: RestrictionMapID = 1

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    public func createData() -> Data {
        var flags: StatusFlag = [.securityControlsEnabled]
        if isSecurityEstablished {
            flags.insert(.securityEstablished)
        }
        
        var characteristicValue = Data(flags.rawValue)
        characteristicValue.append(currentRestrictionMapID)
        
        log.debug("Authorization Control Status characteristic value: %{public}@", characteristicValue.hexadecimalString)
        
        return characteristicValue
    }

    public func onRead() -> (CBATTError.Code, Data) {
        log.debug("reading Authorization Control Status characteristic")
        return (CBATTError.Code.success, self.createData())
    }
    
    public func triggerIndication() {
        if messageQueue.gattServer.isCharacteristicSubscribed(ACCharacteristicUUID.status.cbUUID) ?? false {
            let valuepair = UUIDValuePair(
                uuid: ACCharacteristicUUID.status.cbUUID,
                value: createData()
            )
            log.debug("%{public}@", valuepair.description)
            messageQueue.addQueueItem(valuepair)
        } else {
            log.debug("AC status changed characteristic is not configured for indications")
        }
    }
}

// MARK: - Support Client Implementation
public struct ACStatusDataHandler {
    static private let log = OSLog(category: "AuthorizationControlStatus")
    
    static public func handleData(_ data: Data) -> (currentRestrictionMapID: Int, status: StatusFlag)? {
        if (data.count != 3) {
            log.error("status charactersitic is an unexpected size: (expect 3, actual, %d", data.count)
            return nil
        } else {
            let statusFlags = StatusFlag(rawValue: data[data.startIndex...].to(UInt8.self))
            let currentRestrictionMapID = Int( data[data.startIndex.advanced(by: 1)...].to(UInt16.self))
            return (currentRestrictionMapID, statusFlags)
        }
    }
}

public extension PeripheralManager {
    func readACSStatus(timeout: TimeInterval) throws -> (currentRestrictionMapID: Int, status: StatusFlag) {
        guard let characteristic = peripheral?.getACSCharacteristicWithUUID(.status) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            guard let characteristicData = try readValue(for: characteristic, timeout: timeout) else {
                throw PeripheralManagerError.timeout
            }
            
            guard let status = ACStatusDataHandler.handleData(characteristicData) else {
                throw PeripheralManagerError.invalidResponse(characteristicData)
            }
            
            return status
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}

public struct StatusFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    static let securityControlsEnabled  = StatusFlag(rawValue: 1 << 0)
    static let securityEstablished = StatusFlag(rawValue: 1 << 1)
    static let allZeros = StatusFlag([])
    
    static let debugDescriptions: [StatusFlag: String] = {
        var descriptions = [StatusFlag: String]()
        descriptions[.securityControlsEnabled] = "securityControlsEnabled"
        descriptions[.securityEstablished] = "securityEstablished"
        return descriptions
    }()
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        var result = [String]()
        for (key, value) in StatusFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "StatusFlag(rawValue: \(rawValue)) \(result)"
    }
}
