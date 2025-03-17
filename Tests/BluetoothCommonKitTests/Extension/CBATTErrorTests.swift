//
//  CBATTErrorTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import BluetoothCommonKit

class CBATTErrorTests: XCTestCase {

    func testIsE2ECounterError() {
        let cbATTError  = CBATTError(CBATTError.Code(rawValue: 0x82)!)
        XCTAssertTrue(cbATTError.isE2ECounterError())
    }

    func testIsSegmentCounterError() {
        let cbATTError  = CBATTError(CBATTError.Code(rawValue: 0x83)!)
        XCTAssertTrue(cbATTError.isSegmentCounterError())
    }
}
