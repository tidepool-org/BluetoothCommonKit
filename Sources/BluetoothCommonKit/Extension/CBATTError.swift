//
//  CBATTError.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

extension CBATTError {
    static let e2eCounterCode = 0x82
    static let segmentCounterCode = 0x83

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

extension CBATTError.Code {
    static var e2eCounterCode: CBATTError.Code {
        CBATTError.Code(rawValue: 0x82)!
    }

    static var segmentCounterCode: CBATTError.Code {
        CBATTError.Code(rawValue: 0x83)!
    }

    static var procedureAlreadyInProgress: CBATTError.Code {
        CBATTError.Code(rawValue: 0xfe)!
    }
}
