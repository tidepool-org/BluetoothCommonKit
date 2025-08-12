//
//  DeviceCommErrorTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2022-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class DeviceCommErrorTests: XCTestCase {

    func testWasUnacknowledgedCommand() {
        XCTAssertFalse(DeviceCommError.authenticationFailed.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.commandFailed("").wasCommandUnacknowledged)
        XCTAssertTrue(DeviceCommError.connectionTimeout.wasCommandUnacknowledged)
        XCTAssertTrue(DeviceCommError.disconnected.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.invalidCRC.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.invalidFormat.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.invalidOperand.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.maxBolusNumberReached.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.noRecordsFound.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.opcodeNotImplemented.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.opcodeNotSupported.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.opcodeUnknown("").wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.parameterOutOfRange.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.partialResponse.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.procedureInProgress.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.procedureNotApplicable.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.procedureNotCompleted.wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.securityManagerError(.decryptionFailed).wasCommandUnacknowledged)
        XCTAssertFalse(DeviceCommError.unknown.wasCommandUnacknowledged)
    }
}
