//
//  CBATTError.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

public extension CBATTError {
    static let e2eCRCCode = 0x81
    static let e2eCounterCode = 0x82
    static let segmentCounterCode = 0x83
    static let procedureAlreadyInProgressCode = 0xfe

    func isE2ECRCError() -> Bool {
        code == CBATTError.Code.e2eCRCCode
    }
    
    func isE2ECounterError() -> Bool {
        code == CBATTError.Code.e2eCounterCode
    }

    func isSegmentCounterError() -> Bool {
        code == CBATTError.Code.segmentCounterCode
    }

    func isProcedureAlreadyInProgress() -> Bool {
        code == CBATTError.Code.procedureAlreadyInProgress
    }
}

public extension CBATTError.Code {
    static var e2eCRCCode: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.e2eCRCCode)!
    }
    
    static var e2eCounterCode: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.e2eCounterCode)!
    }

    static var segmentCounterCode: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.segmentCounterCode)!
    }

    static var procedureAlreadyInProgress: CBATTError.Code {
        CBATTError.Code(rawValue: CBATTError.procedureAlreadyInProgressCode)!
    }
}
