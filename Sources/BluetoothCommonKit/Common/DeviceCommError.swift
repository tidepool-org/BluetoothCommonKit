//
//  DeviceCommError.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public typealias ProcedureID = String
public typealias DeviceCommResult<T> = Result<T, DeviceCommError>
public typealias ProcedureCompletion<T> = (DeviceCommResult<T>) -> Void
public typealias ProcedureResultCompletion = ProcedureCompletion<Void>
public typealias ProcedureTimeCompletion = ProcedureCompletion<Date>

public extension DeviceCommResult where Success == Void {
    static var success: Self { .success(()) }
}

public enum DeviceCommError: Equatable {
    case authenticationCancelled
    case authenticationFailed
    case commandFailed(String)
    case connectionTimeout
    case disconnected
    case deviceAlreadyPaired
    case deviceNotReady
    case invalidCRC
    case invalidFormat
    case invalidOperand
    case maxBolusNumberReached
    case noRecordsFound
    case opcodeNotImplemented
    case opcodeNotSupported
    case opcodeUnknown(String)
    case parameterOutOfRange
    case partialResponse
    case procedureInProgress
    case procedureNotApplicable
    case procedureNotCompleted
    case securityManagerError(SecurityManagerError)
    case unknown

    public var wasCommandUnacknowledged: Bool {
        switch self {
        case .disconnected, .connectionTimeout:
            return true
        default:
            return false
        }
    }
}

extension DeviceCommError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authenticationCancelled:
            return LocalizedString("You need to accept the pairing request in order to establish a connection.", comment: "Error description when authentication failed")
        case .authenticationFailed:
            return LocalizedString("A connection could not be established. Try re-entering the information again.", comment: "Error description when authentication failed")
        case .commandFailed(let description):
            return String(format: LocalizedString("The command sent failed. %@", comment: "Error description when the command sent fails"), description)
        case .connectionTimeout:
            return LocalizedString("The connection has timed out.\n\nCheck whether the device is too far away and try again.", comment: "Error description when the procedure times out")
        case .disconnected:
            return LocalizedString("A connection could not be established.\n\nCheck whether the device is too far away and try again.", comment: "Error description when the is not connected")
        case .deviceAlreadyPaired:
            return LocalizedString("This device appears to already have been used and a connection cannot be established.", comment: "Error description when a device has already been paired")
        case .deviceNotReady:
            return LocalizedString("The setup was interrupted. Complete the setup to make settings changes.", comment: "Error description when the device is not configured")
        case .invalidCRC:
            return LocalizedString("The CRC provided is invalid.", comment: "Error description when the CRC is invalid")
        case .invalidFormat:
            return LocalizedString("The response has invalid format.", comment: "Error description when the response format is invalid")
        case .invalidOperand:
            return LocalizedString("The operand provided is invalid.", comment: "Error description when the operand is invalid")
        case .maxBolusNumberReached:
            return LocalizedString("The maximum number of bolus has been reached.", comment: "Error description when the max number of bolus is reached")
        case .noRecordsFound:
            return LocalizedString("No records found matching the requested.", comment: "Error description when no records are found")
        case .opcodeNotImplemented:
            return LocalizedString("The opcode is not yet implemented.", comment: "Error description when the opcode is not implemented")
        case .opcodeNotSupported:
            return LocalizedString("The opcode is not supported.", comment: "Error description when the opcode is not supported")
        case .opcodeUnknown(let details):
            return String(format: LocalizedString("The provided response code is unknown. %@", comment: "Error description when an unknown response code is provided"), details)
        case .parameterOutOfRange:
            return LocalizedString("A parameter is out of range.", comment: "Error description when a parameter is out of range")
        case .partialResponse:
            return LocalizedString("The response is segmented and this is only a part of the response.", comment: "Error description when expecting more response")
        case .procedureInProgress:
            return LocalizedString("Another procedure is already in progress.", comment: "Error description when a procedure is in progress")
        case .procedureNotApplicable:
            return LocalizedString("Could not complete request. Wait a few seconds before trying again. If the issue does not resolve on its own you will receive additional information describing how to fix the problem.", comment: "Error description when a procedure is not applicable")
        case .procedureNotCompleted:
            return LocalizedString("The procedure was not completed.", comment: "Error description when a procedure is not completed")
        case .securityManagerError(_):
            return LocalizedString("Unable to communication with device. Wait a few seconds before trying again.", comment: "Error description when the security error is reported")
        case .unknown:
            return LocalizedString("An unknown communication error occurred.", comment: "Error description when an unknown error occurred during communication")
        }
    }
}
