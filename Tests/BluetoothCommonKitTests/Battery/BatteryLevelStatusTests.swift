//
//  BatteryLevelStatusTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2026-04-30.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

final class BatteryLevelStatusTests: XCTestCase {

    // MARK: - Parsing

    func testMinimalParse() {
        // Power State subfields (spec bit positions):
        //   bit 0    : BatteryPresent           = yes (1)
        //   bits 1-2 : WiredExternal            = no (0)
        //   bits 3-4 : WirelessExternal         = no (0)
        //   bits 5-6 : ChargeState              = dischargingActive (2)
        //   bits 7-8 : ChargeLevel              = good (1)
        //   bits 9-11: ChargingType             = unknownOrNotCharging (0)
        let powerStateValue: UInt16 = (1 << 0) | (2 << 5) | (1 << 7)
        var data = Data()
        data.append(UInt8(0x00)) // flags: no optional fields
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.powerState.batteryPresent, .yes)
        XCTAssertEqual(status?.powerState.wiredExternalPowerConnected, .no)
        XCTAssertEqual(status?.powerState.wirelessExternalPowerConnected, .no)
        XCTAssertEqual(status?.powerState.chargeState, .dischargingActive)
        XCTAssertEqual(status?.powerState.chargeLevel, .good)
        XCTAssertEqual(status?.powerState.chargingType, .unknownOrNotCharging)
        XCTAssertFalse(status?.powerState.hasChargingFault ?? true)
        XCTAssertFalse(status?.powerState.isCharging ?? true)
        XCTAssertNil(status?.identifier)
        XCTAssertNil(status?.batteryLevel)
        XCTAssertNil(status?.additionalStatus)
    }

    func testParseWithAllOptionalFields() {
        // bit 0    : BatteryPresent = yes (1)
        // bits 1-2 : WiredExternal  = yes (1)
        // bits 5-6 : ChargeState    = charging (1)
        // bits 7-8 : ChargeLevel    = good (1)
        // bits 9-11: ChargingType   = constantCurrent (1)
        let powerStateValue: UInt16 = (1 << 0) | (1 << 1) | (1 << 5) | (1 << 7) | (1 << 9)

        var data = Data()
        data.append(UInt8(0x07)) // flags: all three optional fields present
        data.append(powerStateValue)
        data.append(UInt16(0x0042)) // identifier
        data.append(UInt8(75)) // battery level 75%
        data.append(UInt8(0x00)) // additional status: no service required, no fault

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.powerState.batteryPresent, .yes)
        XCTAssertEqual(status?.powerState.wiredExternalPowerConnected, .yes)
        XCTAssertEqual(status?.powerState.chargeState, .charging)
        XCTAssertEqual(status?.powerState.chargeLevel, .good)
        XCTAssertEqual(status?.powerState.chargingType, .constantCurrent)
        XCTAssertTrue(status?.powerState.isCharging ?? false)
        XCTAssertFalse(status?.powerState.hasChargingFault ?? true)
        XCTAssertEqual(status?.identifier, 0x0042)
        XCTAssertEqual(status?.batteryLevel, 75)
        XCTAssertNotNil(status?.additionalStatus)
        XCTAssertEqual(status?.additionalStatus?.serviceRequired, .no)
        XCTAssertFalse(status?.additionalStatus?.batteryFault ?? true)
    }

    func testParseWithOnlyBatteryLevel() {
        let powerStateValue: UInt16 = (1 << 0) // battery present
        var data = Data()
        data.append(UInt8(0x02)) // flags: only battery level present
        data.append(powerStateValue)
        data.append(UInt8(50)) // battery level 50%

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertNil(status?.identifier)
        XCTAssertEqual(status?.batteryLevel, 50)
        XCTAssertNil(status?.additionalStatus)
    }

    func testParseWithOnlyIdentifier() {
        let powerStateValue: UInt16 = (1 << 0)
        var data = Data()
        data.append(UInt8(0x01)) // flags: only identifier present
        data.append(powerStateValue)
        data.append(UInt16(0x1234)) // identifier

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.identifier, 0x1234)
        XCTAssertNil(status?.batteryLevel)
        XCTAssertNil(status?.additionalStatus)
    }

    func testParseWithOnlyAdditionalStatus() {
        let powerStateValue: UInt16 = (1 << 0)
        var data = Data()
        data.append(UInt8(0x04)) // flags: only additional status present
        data.append(powerStateValue)
        data.append(UInt8(0x05)) // service required = yes (1), battery fault = true (bit 2)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertNil(status?.identifier)
        XCTAssertNil(status?.batteryLevel)
        XCTAssertNotNil(status?.additionalStatus)
        XCTAssertEqual(status?.additionalStatus?.serviceRequired, .yes)
        XCTAssertTrue(status?.additionalStatus?.batteryFault ?? false)
    }

    // MARK: - Invalid Data

    func testParseTooShort() {
        let data = Data([0x00, 0x01]) // only 2 bytes, need at least 3
        let status = BatteryLevelStatus(data: data)
        XCTAssertNil(status)
    }

    func testParseEmpty() {
        let status = BatteryLevelStatus(data: Data())
        XCTAssertNil(status)
    }

    func testParseTruncatedOptionalIdentifier() {
        let powerStateValue: UInt16 = (1 << 0)
        var data = Data()
        data.append(UInt8(0x01)) // flags: identifier present
        data.append(powerStateValue)
        // missing identifier bytes

        let status = BatteryLevelStatus(data: data)
        XCTAssertNil(status)
    }

    func testParseTruncatedOptionalBatteryLevel() {
        let powerStateValue: UInt16 = (1 << 0)
        var data = Data()
        data.append(UInt8(0x02)) // flags: battery level present
        data.append(powerStateValue)
        // missing battery level byte

        let status = BatteryLevelStatus(data: data)
        XCTAssertNil(status)
    }

    func testParseTruncatedOptionalAdditionalStatus() {
        let powerStateValue: UInt16 = (1 << 0)
        var data = Data()
        data.append(UInt8(0x04)) // flags: additional status present
        data.append(powerStateValue)
        // missing additional status byte

        let status = BatteryLevelStatus(data: data)
        XCTAssertNil(status)
    }

    // MARK: - Power State Bit Fields

    func testChargingFaultFlags() {
        // Set all three fault bits (12, 13, 14)
        let powerStateValue: UInt16 = (1 << 0) | (1 << 12) | (1 << 13) | (1 << 14)
        var data = Data()
        data.append(UInt8(0x00))
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertTrue(status?.powerState.chargingFaultReasonBattery ?? false)
        XCTAssertTrue(status?.powerState.chargingFaultReasonExternalPower ?? false)
        XCTAssertTrue(status?.powerState.chargingFaultReasonOther ?? false)
        XCTAssertTrue(status?.powerState.hasChargingFault ?? false)
    }

    func testWirelessExternalPower() {
        // bits 3-4: WirelessExternal = yes (1)
        let powerStateValue: UInt16 = (1 << 0) | (1 << 3)
        var data = Data()
        data.append(UInt8(0x00))
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.powerState.wirelessExternalPowerConnected, .yes)
    }

    func testChargeLevelCritical() {
        // bits 7-8: ChargeLevel = critical (3)
        let powerStateValue: UInt16 = (1 << 0) | (3 << 7)
        var data = Data()
        data.append(UInt8(0x00))
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.powerState.chargeLevel, .critical)
    }

    func testChargingTypeTrickle() {
        // bits 5-6: ChargeState = charging (1); bits 9-11: ChargingType = trickle (3)
        let powerStateValue: UInt16 = (1 << 0) | (1 << 5) | (3 << 9)
        var data = Data()
        data.append(UInt8(0x00))
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.powerState.chargingType, .trickle)
    }

    func testChargeStateDischargingInactive() {
        // bits 5-6: ChargeState = dischargingInactive (3)
        let powerStateValue: UInt16 = (1 << 0) | (3 << 5)
        var data = Data()
        data.append(UInt8(0x00))
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.powerState.chargeState, .dischargingInactive)
        XCTAssertFalse(status?.powerState.isCharging ?? true)
    }

    // MARK: - Power State Subfield Layout (spec bit positions)

    /// Packs every Power State subfield with a distinct value at its spec bit position and
    /// reads each back. A shift error in any field bleeds into a neighbour and fails here —
    /// the regression that guards the Battery Charge Level off-by-one (bits 7-8, not 8-9).
    func testPowerStateSubfieldsIsolatedByBitPosition() {
        let powerStateValue: UInt16 =
            (1 << 0) |   // bit 0    : BatteryPresent          = yes (1)
            (2 << 1) |   // bits 1-2 : WiredExternal           = unknown (2)
            (1 << 3) |   // bits 3-4 : WirelessExternal        = yes (1)
            (1 << 5) |   // bits 5-6 : ChargeState             = charging (1)
            (2 << 7) |   // bits 7-8 : ChargeLevel             = low (2)
            (3 << 9) |   // bits 9-11: ChargingType            = trickle (3)
            (1 << 12) |  // bit 12   : ChargingFaultReasonBattery
            (1 << 13)    // bit 13   : ChargingFaultReasonExternalPower
        var data = Data()
        data.append(UInt8(0x00))
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.powerState.batteryPresent, .yes)
        XCTAssertEqual(status?.powerState.wiredExternalPowerConnected, .unknown)
        XCTAssertEqual(status?.powerState.wirelessExternalPowerConnected, .yes)
        XCTAssertEqual(status?.powerState.chargeState, .charging)
        XCTAssertEqual(status?.powerState.chargeLevel, .low)
        XCTAssertEqual(status?.powerState.chargingType, .trickle)
        XCTAssertTrue(status?.powerState.chargingFaultReasonBattery ?? false)
        XCTAssertTrue(status?.powerState.chargingFaultReasonExternalPower ?? false)
        XCTAssertFalse(status?.powerState.chargingFaultReasonOther ?? true)
    }

    /// A Good charge level (bits 7-8 = 1) alongside a non-zero Charging Type must not be
    /// misread — the earlier bits-8-9 decode returned Unknown here, defeating the
    /// readiness signal (and could read Critical as Good).
    func testChargeLevelGoodNotBledFromChargingType() {
        // bits 7-8: ChargeLevel = good (1); bits 9-11: ChargingType = constantVoltage (2)
        let powerStateValue: UInt16 = (1 << 0) | (1 << 7) | (2 << 9)
        var data = Data()
        data.append(UInt8(0x00))
        data.append(powerStateValue)

        let status = BatteryLevelStatus(data: data)
        XCTAssertEqual(status?.powerState.chargeLevel, .good)
        XCTAssertEqual(status?.powerState.chargingType, .constantVoltage)
    }

    // MARK: - Characteristic UUID

    func testBatteryLevelStatusUUID() {
        XCTAssertEqual(BatteryCharacteristicUUID.batteryLevelStatus.rawValue, "2bed")
        XCTAssertEqual(BatteryCharacteristicUUID.batteryLevelStatus.name, "battery.levelStatus")
        XCTAssertTrue(BatteryCharacteristicUUID.batteryLevelStatus.properties.contains(.read))
        XCTAssertTrue(BatteryCharacteristicUUID.batteryLevelStatus.properties.contains(.notify))
    }

    func testBatteryLevelUUIDUnchanged() {
        XCTAssertEqual(BatteryCharacteristicUUID.batteryLevel.rawValue, "2a19")
        XCTAssertEqual(BatteryCharacteristicUUID.batteryLevel.name, "battery.level")
        XCTAssertTrue(BatteryCharacteristicUUID.batteryLevel.properties.contains(.read))
        XCTAssertTrue(BatteryCharacteristicUUID.batteryLevel.properties.contains(.notify))
    }

    func testServiceUUID() {
        XCTAssertEqual(BatteryCharacteristicUUID.service.rawValue, "180f")
        XCTAssertEqual(BatteryCharacteristicUUID.service.name, "battery")
        XCTAssertTrue(BatteryCharacteristicUUID.service.properties.isEmpty)
    }
}
