//
//  SecurityManagerError.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public enum SecurityManagerError: Error, Equatable {
    case decryptionFailed
    case encryptionFailed
    case incorrectSecurityConfiguration
    case missingKey
    case keyDerivationFailed
    case unsupportedAlgorithm
}

extension SecurityManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .decryptionFailed:
            return LocalizedString("Decryption failed", comment: "error when decryption fails")
        case .encryptionFailed:
            return LocalizedString("Encryption failed", comment: "error when encryption fails")
        case .incorrectSecurityConfiguration:
            return LocalizedString("Incorrect security configuration", comment: "error when the security configuration is not correct")
        case .missingKey:
            return LocalizedString("Missing key", comment: "error when the security key is missing")
        case .keyDerivationFailed:
            return LocalizedString("Key derivation failed", comment: "error when the key derivation failed")
        case .unsupportedAlgorithm:
            return LocalizedString("Unsupported algorithm", comment: "error when the algorithm type is not supported")
        }
    }
}
