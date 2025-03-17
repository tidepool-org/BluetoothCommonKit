//
//  CBUUIDRawValueTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import BluetoothCommonKit

class CBUUIDRawValueTests: XCTestCase {

    func testInitialization() {
        XCTAssertEqual(ACCharacteristicUUID.controlPoint.cbUUID, CBUUID(string:"2b33"))
    }
}
