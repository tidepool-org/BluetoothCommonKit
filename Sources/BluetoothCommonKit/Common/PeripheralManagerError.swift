//
//  PeripheralManagerError.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

enum PeripheralManagerError: Error {
    case cbPeripheralError(Error)
    case notReady
    case timeout
    case unknownCharacteristic
    case invalidResponse(Data)
}

extension PeripheralManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cbPeripheralError(let error):
            return error.localizedDescription
        case .notReady:
            return LocalizedString("Peripheral is not connected", comment: "Not ready error description")
        case .timeout:
            return LocalizedString("Peripheral did not respond in time", comment: "Timeout error description")
        case .unknownCharacteristic:
            return LocalizedString("Unknown characteristic", comment: "Error description")
        case .invalidResponse(let data):
            return String(format: LocalizedString("Invalid response %@", comment: "Invalid response description (1: data as hexidecimal)"), data.hexadecimalString)
        }
    }

    var failureReason: String? {
        switch self {
        case .cbPeripheralError(let error as NSError):
            return error.localizedFailureReason
        default:
            return errorDescription
        }
    }
}
