//
//  CBATTError.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public extension CBATTError {
    static let invalidKey = 0x80
    static let commandNotSupported = 0x81
    static let resourceNotProtected = 0x81
    static let e2eCRCCode = 0x81
    static let e2eCounterCode = 0x82
    static let incorrectSecurityConfigurationCode = 0x82
    static let segmentCounterCode = 0x83
    static let improperlyConfigured = 0xfd
    static let procedureAlreadyInProgressCode = 0xfe
    static let outOfRange = 0xff

    func isInvalidKeyError() -> Bool {
        code == CBATTError.Code.invalidKey
    }
    
    func isCommandNotSupportedInvalidKeyError() -> Bool {
        code == CBATTError.Code.commandNotSupported
    }
    
    func isResourceNotProtectedError() -> Bool {
        code == CBATTError.Code.resourceNotProtected
    }
    
    func isE2ECRCError() -> Bool {
        code == CBATTError.Code.e2eCRCCode
    }
    
    func isE2ECounterError() -> Bool {
        code == CBATTError.Code.e2eCounterCode
    }
    
    func isIncorrectSecurityConfigurationCodeError() -> Bool {
        code == CBATTError.Code.incorrectSecurityConfigurationCode
    }

    func isSegmentCounterError() -> Bool {
        code == CBATTError.Code.segmentCounterCode
    }

    func isImproperlyConfiguredError() -> Bool {
        code == CBATTError.Code.improperlyConfigured
    }
    
    func isProcedureAlreadyInProgress() -> Bool {
        code == CBATTError.Code.procedureAlreadyInProgress
    }
    
    func isOutOfRange() -> Bool {
        code == CBATTError.Code.outOfRange
    }
}

public extension CBATTError.Code {
    static var invalidKey: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.invalidKey)!
    }
    
    static var commandNotSupported: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.commandNotSupported)!
    }
    
    static var resourceNotProtected: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.resourceNotProtected)!
    }
    
    static var e2eCRCCode: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.e2eCRCCode)!
    }
    
    static var e2eCounterCode: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.e2eCounterCode)!
    }
    
    static var incorrectSecurityConfigurationCode: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.e2eCounterCode)!
    }
        
    static var segmentCounterCode: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.segmentCounterCode)!
    }

    static var improperlyConfigured: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.improperlyConfigured)!
    }

    static var procedureAlreadyInProgress: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.procedureAlreadyInProgressCode)!
    }
    
    static var outOfRange: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.outOfRange)!
    }
}
