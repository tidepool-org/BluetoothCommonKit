//
//  DTControlPoint.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import os.log

public class DTControlPoint: ControlPoint {

    private let log = OSLog(category: "DTControlPoint")

    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])

    public var procedureRunning: Bool = false
    
    public init() { }

    //MARK: - Response Handling
    public func handleResponse(_ response: Data) -> (result: DeviceCommResult<Void>, completion: Any?) {
        guard response.isCRCPrefixValid else {
            return (.failure(.invalidCRC), nil)
        }

        let responseWithoutCRC = response.dropFirst(2)

        guard let opcode: DTControlPointOpcode = responseOpcode(responseWithoutCRC) else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return (.failure(.opcodeUnknown(response.hexadecimalString)), nil)
        }

        log.debug("device time control point response opcode: %{public}@", opcode.procedureID)
        switch opcode {
        case .responseCode:
            guard responseWithoutCRC.count >= 2 else { return (.failure(.invalidFormat), nil) }

            guard let requestOpcode = DTControlPointOpcode(rawValue: responseWithoutCRC[responseWithoutCRC.startIndex.advanced(by: 1)...].to(DTControlPointOpcode.RawValue.self)),
                  let responseCode = DTControlPointResponseCode(rawValue: responseWithoutCRC[responseWithoutCRC.startIndex.advanced(by: 2)...].to(DTControlPointResponseCode.RawValue.self)) else
            {
                return (.failure(.parameterOutOfRange), nil)
            }
            log.debug("request opcode  %{public}@, response code %{public}@", requestOpcode.procedureID, String(reflecting: responseCode))

            let completion = completeProcedure(requestOpcode)
            switch responseCode {
            case .success:
                return (.success, completion)
            case .opcodeNotSupported:
                return (.failure(.opcodeNotSupported), completion)
            case .invalidOperand:
                return (.failure(.invalidOperand), completion)
            case .procedureRejected:
                return (.failure(.procedureNotCompleted), completion)
            case .operationFailed:
                return (.failure(.procedureNotCompleted), completion)
            case .deviceBusy:
                return (.failure(.procedureNotCompleted), completion)
            }
        default:
            log.error("handler not implemented yet")
            return (.failure(.opcodeNotImplemented), nil)
        }
    }

    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in DTControlPointOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    if let requestOpcode = DTControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 3)...].to(DTControlPointOpcode.RawValue.self)) {
                        return  requestOpcode.procedureID
                    }
                default:
                    if let requestOpcode = opcode.requestOpcode {
                        return requestOpcode.procedureID
                    } else {
                        log.error("Opcode does not have a procedure ID")
                        break
                    }
                }
            }
        }
        log.error("Device Time Control Point response does not have a procedure ID (raw response: %{public}@)", response.toHexString())
        return nil
    }

    public func procedureIDForRequest(_ request: Data) -> ProcedureID {
        guard let procedureID = DTControlPointOpcode(rawValue: request[request.startIndex.advanced(by: 2)...].to(DTControlPointOpcode.RawValue.self))?.procedureID else {
            fatalError("Opcode does not have a procedure ID \(request.toHexString())")
        }
        return procedureID
    }

    func isSpecificResponse(expectedOpcode: DTControlPointOpcode, response: Data) -> Bool {
        guard let opcode = DTControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(DTControlPointOpcode.RawValue.self)),
              opcode == expectedOpcode else
        {
            return false
        }
        return true
    }

    public func isExpectedRequest<O: RawRepresentable>(_ request: Data, expectedOpcode: O) -> Bool where O.RawValue: FixedWidthInteger {
        let opcodeIndex = 2
        guard request.count >= Data(expectedOpcode.rawValue).count + opcodeIndex else {
            return false
        }

        let opcodeElement = request[request.startIndex.advanced(by: opcodeIndex)...].to(O.RawValue.self)

        guard let opcode = O(rawValue: opcodeElement) else {
            return false
        }

        return expectedOpcode == opcode
    }

    //MARK: - Create Requests
    func buildRequest(_ opcode: DTControlPointOpcode, operand: Data? = nil) -> Data {
        var request = DTControlPoint.buildControlPointRequest(opcode: opcode, operand: operand)
        // add E2E-CRC
        request = request.appendingCRCPrefix()
        return request
    }

    public func createProposeTimeUpdateRequest(_ date: Date = Date(), using timeZone: TimeZone) -> Data? {
        let timeUpdateFlags = TimeUpdateFlags([.epochYear2000, .utcAligned, .secondFractionsNotValid])

        // base time is the number of seconds from January 1, 2000 (Epoch 2000)
        let baseTime = date.baseTimeInSecondsFromEpoch2000

        // time zone offset is 15-minute increments from UTC
        let timeZoneOffset = timeZone.gattTimeZoneOffset
        let dstOffset = TimeZone.current.dstOffset
        let timeSource = TimeSource.networkTimeProtocol
        let timeAccuracy = TimeAccuracy.unknown

        var operand = Data(timeUpdateFlags.rawValue)
        operand.append(baseTime)
        operand.append(timeZoneOffset)
        operand.append(dstOffset.rawValue)
        operand.append(timeSource.rawValue)
        operand.append(timeAccuracy.rawValue)

        return buildRequest(DTControlPointOpcode.proposeTimeUpdate, operand: operand)
    }

    //MARK: - Queue Requests
    public func queueProposeTimeUpdateRequest(_ date: Date = Date(), using timeZone: TimeZone, completion: ProcedureResultCompletion? = nil) {
        guard let request = createProposeTimeUpdateRequest(date, using: timeZone) else { return }
        appendToRequestQueue(request, completion: completion)
    }
}

//MARK: - Write Insulin Delivery Control Point Request
extension PeripheralManager {
    public func writeDeviceTimeControlPointRequest(_ request: Data, type: CBCharacteristicWriteType = .withResponse, timeout: TimeInterval) throws {
        guard let characteristic = peripheral?.getDeviceTimetCharacteristicWithUUID(.controlPoint) else {
            throw PeripheralManagerError.unknownCharacteristic
        }

        do {
            try writeValue(request, for: characteristic, type: type, timeout: timeout)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}

//MARK: - Enumerations
public enum DTControlPointOpcode: UInt8, CaseIterable {
    case proposeTimeUpdate = 2
    case forceTimeUpdate = 3
    case proposeNonLoggedTimeAdjustmentLimit = 4
    case retrieveActiveTimeAdjustments = 5
    case reportActiveTimeAdjustments = 7
    case responseCode = 9

    public var procedureID: ProcedureID {
        String("DeviceTimeControlPoint.\(self.debugDescription)")
    }

    var requestOpcode: DTControlPointOpcode? {
        switch self {
        case .reportActiveTimeAdjustments: return .retrieveActiveTimeAdjustments
        default:
            return nil
        }
    }

    static var responseOpcodes: [DTControlPointOpcode] {
        return [
            .responseCode,
            .reportActiveTimeAdjustments
        ]
    }

    private var debugDescription: String {
        switch self {
        case .proposeTimeUpdate: return "proposeTimeUpdate"
        case .forceTimeUpdate: return "forceTimeUpdate"
        case .proposeNonLoggedTimeAdjustmentLimit: return "proposeNonLoggedTimeAdjustmentLimit"
        case .retrieveActiveTimeAdjustments: return "retrieveActiveTimeAdjustments"
        case .reportActiveTimeAdjustments: return "reportActiveTimeAdjustments"
        case .responseCode: return "responseCode"
        }
    }
}

public enum DTControlPointResponseCode: UInt8 {
    case success = 1
    case opcodeNotSupported = 2
    case invalidOperand = 3
    case operationFailed = 4
    case procedureRejected = 5
    case deviceBusy = 7
}

enum TimeSource: UInt8 {
    case unknown = 0
    case networkTimeProtocol = 1
    case gps = 2
    case radioTimeSignal = 3
    case manual = 4
    case atomicClock = 5
    case cellularNetwork = 6
}

enum TimeAccuracy: UInt8 {
    case unknown = 255
}

public enum DSTOffset: UInt8 {
    case standardTime = 0
    case daylightHalfHour = 2
    case daylight1Hour = 4
    case daylight2Hour = 8
    case unknown = 255
}

//MARK: - Option sets
struct RejectionFlags: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt16

    static let notRealistic  = RejectionFlags(rawValue: 1 << 0)
    static let notAuthorized = RejectionFlags(rawValue: 1 << 1)
    static let outOfRangeOperand = RejectionFlags(rawValue: 1 << 2)
    static let notUTCAligned = RejectionFlags(rawValue: 1 << 3)
    static let outOfRangeTimeAccuracy = RejectionFlags(rawValue: 1 << 4)
    static let timeSourceLowQuality = RejectionFlags(rawValue: 1 << 5)
    static let epochYearNotAligned = RejectionFlags(rawValue: 1 << 6)
    static let lackOfPrecision = RejectionFlags(rawValue: 1 << 8)
    static let baseTimeRejected = RejectionFlags(rawValue: 1 << 9)
    static let timeZoneDSTRejected = RejectionFlags(rawValue: 1 << 10)
    static let allZeros = RejectionFlags([])

    static let debugDescriptions: [RejectionFlags:String] = {
        var descriptions = [RejectionFlags:String]()
        descriptions[.notRealistic] = "notRealistic"
        descriptions[.notAuthorized] = "notAuthorized"
        descriptions[.outOfRangeOperand] = "outOfRangeOperand"
        descriptions[.notUTCAligned] = "notUTCAligned"
        descriptions[.outOfRangeTimeAccuracy] = "outOfRangeTimeAccuracy"
        descriptions[.timeSourceLowQuality] = "timeSourceLowQuality"
        descriptions[.epochYearNotAligned] = "epochYearNotAligned"
        descriptions[.lackOfPrecision] = "lackOfPrecision"
        descriptions[.baseTimeRejected] = "baseTimeRejected"
        descriptions[.timeZoneDSTRejected] = "timeZoneDSTRejected"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in RejectionFlags.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "RejectionFlags(rawValue: \(rawValue)) \(result)"
    }
}

struct TimeUpdateFlags: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt16

    static let utcAligned  = TimeUpdateFlags(rawValue: 1 << 0)
    static let qualifiedLocalTime = TimeUpdateFlags(rawValue: 1 << 1)
    static let adjustmentReasonManual = TimeUpdateFlags(rawValue: 1 << 2)
    static let adjustmenReasonExternal = TimeUpdateFlags(rawValue: 1 << 3)
    static let adjustmentReasonTimeZone = TimeUpdateFlags(rawValue: 1 << 4)
    static let adjustmentReasonDSTOffest = TimeUpdateFlags(rawValue: 1 << 5)
    static let epochYear2000 = TimeUpdateFlags(rawValue: 1 << 6)
    static let secondFractionsNotValid = TimeUpdateFlags(rawValue: 1 << 7)
    static let allZeros = TimeUpdateFlags([])

    static let debugDescriptions: [TimeUpdateFlags:String] = {
        var descriptions = [TimeUpdateFlags:String]()
        descriptions[.utcAligned] = "utcAligned"
        descriptions[.qualifiedLocalTime] = "qualifiedLocalTime"
        descriptions[.adjustmentReasonManual] = "adjustmentReasonManual"
        descriptions[.adjustmenReasonExternal] = "adjustmenReasonExternal"
        descriptions[.adjustmentReasonTimeZone] = "adjustmentReasonTimeZone"
        descriptions[.adjustmentReasonDSTOffest] = "adjustmentReasonDSTOffest"
        descriptions[.epochYear2000] = "epochYear2000"
        descriptions[.secondFractionsNotValid] = "secondFractionsNotValid"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in TimeUpdateFlags.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "TimeUpdateFlags(rawValue: \(rawValue)) \(result)"
    }
}

public extension Date {
    static var epoch2000: Date {
        return Date(timeIntervalSince1970: 946684800) // Jan 1, 2000 00:00:00 GMT
    }

    var baseTimeInSecondsFromEpoch2000: UInt32 {
        UInt32(self.timeIntervalSince(Date.epoch2000).seconds)
    }
}

public extension TimeZone {
    var dstOffset: DSTOffset {
        guard self.isDaylightSavingTime() else { return .standardTime }

        switch self.daylightSavingTimeOffset().hours {
        case let x where x == 0.5:
            return .daylightHalfHour
        case let x where x == 1:
            return .daylight1Hour
        case let x where x == 2:
            return .daylight2Hour
        default:
            return .unknown
        }
    }
}
