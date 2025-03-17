//
//  DeviceTime.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import os.log

public class DeviceTime {
    
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
        guard data.count == 10 else {
            log.error("device time characteristic incorrect format.")
            return (.failure(.invalidFormat), nil)
        }

        guard data.isCRCPrefixValid else {
            log.error("device time CRC is invalid.")
            return (.failure(.invalidCRC), nil)
        }

        var index = 2 // skip CRC
        
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
