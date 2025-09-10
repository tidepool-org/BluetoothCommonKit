//
//  DeviceTime.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth
import os.log

// MARK: - Support Server implementation
public class DeviceTimeCharacteristic: ReadableCharacteristic, E2EProtection {
    public var e2eCounter: UInt8 = 0
    public weak var e2eDelegate: E2EProtectionDelegate?
    var messageQueue: MessagingQueue
    
    public required init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    public func createData() -> Data {
        let secondsSinceEpoch2000 = Date().baseTimeInSecondsFromEpoch2000
        let timeZoneOffset = TimeZone.current.gattTimeZoneOffset
        let dstOffset = TimeZone.current.dstOffset
        let status: DTStatusFlag = [.utcAligned, .qualifiedLocalTimeSynchronized, .epochYear2000]
        var characteristicValue = Data(secondsSinceEpoch2000)
        characteristicValue.append(timeZoneOffset)
        characteristicValue.append(dstOffset.rawValue)
        characteristicValue.append(status.rawValue)
        
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            characteristicValue = characteristicValue.appendingCRCPrefix()
        }
        
        ConsoleOut.shared.logMessage(message: "\(#function) Device Time characteristic value: \(characteristicValue.hexadecimalString)")
        
        return characteristicValue
    }
    
    public func onRead() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading Device Time characteristic")
        return (CBATTError.Code.success, self.createData())
    }
    
    public func triggerIndication() {
        if messageQueue.gattServer.isCharacteristicSubscribed(DeviceTimeCharacteristicUUID.deviceTime.cbUUID) == true {
            let valuepair = UUIDValuePair(
                uuid: DeviceTimeCharacteristicUUID.deviceTime.cbUUID,
                value: createData()
            )
            ConsoleOut.shared.logMessage(message: "\(#function): \(valuepair.description)")
            messageQueue.addQueueItem(valuepair)
        } else {
            ConsoleOut.shared.logMessage(message: "\(#function): Device Time characteristic is not configured for indications")
        }
    }
}

// MARK: - Support Client implementation
public class DeviceTimeDataHandler: E2EProtection {
    public var e2eCounter: UInt8 = 0

    public weak var e2eDelegate: (any E2EProtectionDelegate)?
    
    private let log = OSLog(category: "DeviceTime")
    
    var lockedRequestQueue: Locked<[(request: Data?, completion: Any?)]> = Locked([])
    
    public init() { }
    
    public var hasRequestToSend: Bool {
        nextRequestToSend()?.request != nil
    }

    public func reset() {
        lockedRequestQueue.mutate { requestQueue in
            requestQueue.removeAll()
        }
    }
    
    public func nextRequestToSend() -> (request: Data?, completion: Any?)? {
        lockedRequestQueue.value.first
    }
    
    public func handleData(_ data: Data) -> (result: DeviceCommResult<Date?>, completion: Any?) {
        guard data.count >= 8 else {
            log.error("device time characteristic incorrect format.")
            return (.failure(.invalidFormat), nil)
        }

        guard e2eDelegate?.isE2EProtectionSupported == false || (e2eDelegate?.isE2EProtectionSupported == true && data.isCRCPrefixValid) else {
            log.error("device time CRC is invalid.")
            return (.failure(.invalidCRC), nil)
        }

        var index = e2eDelegate?.isE2EProtectionSupported == true ? 2 : 0 // skip CRC
        
        var completion: Any? = nil
        lockedRequestQueue.mutate { requestQueue in
            completion = requestQueue.first?.completion
            guard requestQueue.first != nil else { return }
            requestQueue.removeFirst()
        }
        
        let baseTimeInSecondsFromEpoch2000 = Int(data[data.startIndex.advanced(by: index)...].to(UInt32.self))
        index += 4

        let timeZone15MinIncrements = Int(data[data.startIndex.advanced(by: index)...].to(Int8.self))
        index += 1
        let timeZoneSecondsFromGMT = (timeZone15MinIncrements * 15 * 60)

        let dstOffset = DSTOffset(rawValue: data[data.startIndex.advanced(by: index)...].to(UInt8.self)) ?? .unknown
        index += 1

        let statusFlags = DTStatusFlag(rawValue: data[data.startIndex.advanced(by: index)...].to(DTStatusFlag.RawValue.self))

        guard !statusFlags.contains(.timeFault), statusFlags.contains(.epochYear2000), dstOffset != .unknown else { return (.success(nil), completion) }

        guard let timeZone = TimeZone(secondsFromGMT: timeZoneSecondsFromGMT) else { return (.failure(.invalidFormat), completion) }

        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let dateComponents = DateComponents(second: baseTimeInSecondsFromEpoch2000)
        let deviceTime = calendar.date(byAdding: dateComponents, to: Date.epoch2000)
        return (.success(deviceTime), completion)
    }
    
    public func queueGetDateTimeRequest(completion: ProcedureTimeCompletion? = nil) {
        lockedRequestQueue.mutate { requestQueue in
            requestQueue.append((nil, completion))
        }
    }
}

//MARK: - Option sets
public struct DTStatusFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let timeFault  = DTStatusFlag(rawValue: 1 << 0)
    public static let utcAligned = DTStatusFlag(rawValue: 1 << 1)
    public static let qualifiedLocalTimeSynchronized = DTStatusFlag(rawValue: 1 << 2)
    public static let proposeTimeUpdateRequest = DTStatusFlag(rawValue: 1 << 3)
    public static let epochYear2000 = DTStatusFlag(rawValue: 1 << 4)
    public static let nonLoggedTimeChangeActive = DTStatusFlag(rawValue: 1 << 5)
    public static let logConsolidationActive = DTStatusFlag(rawValue: 1 << 6)
    public static let allZeros = DTStatusFlag([])

    static let debugDescriptions: [DTStatusFlag: String] = {
        var descriptions = [DTStatusFlag: String]()
        descriptions[.timeFault] = "timeFault"
        descriptions[.utcAligned] = "utcAligned"
        descriptions[.qualifiedLocalTimeSynchronized] = "qualifiedLocalTimeSynchronized"
        descriptions[.proposeTimeUpdateRequest] = "proposeTimeUpdateRequest"
        descriptions[.epochYear2000] = "epochYear2000"
        descriptions[.nonLoggedTimeChangeActive] = "nonLoggedTimeChangeActive"
        descriptions[.logConsolidationActive] = "logConsolidationActive"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for key in DTStatusFlag.debugDescriptions.keys {
            guard self.contains(key),
                let description = DTStatusFlag.debugDescriptions[key] else { continue }

            result.append(description)
        }
        return "DTStatusFlag(rawValue: \(rawValue)) \(result)"
    }
}
