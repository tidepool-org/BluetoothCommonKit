//
//  BatteryLevelStatus.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2026-04-30.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//

import Foundation

/// Bluetooth GATT Battery Level Status characteristic (0x2BED)
///
/// Format:
/// - Flags (1 byte, mandatory)
/// - Power State (2 bytes, mandatory)
/// - Identifier (2 bytes, optional — present if Flags bit 0 set)
/// - Battery Level (1 byte, optional — present if Flags bit 1 set)
/// - Additional Status (1 byte, optional — present if Flags bit 2 set)
public struct BatteryLevelStatus {

    public let powerState: PowerState
    public let identifier: UInt16?
    public let batteryLevel: UInt8?
    public let additionalStatus: AdditionalStatus?

    // MARK: - Flags

    struct Flags: OptionSet {
        let rawValue: UInt8

        static let identifierPresent      = Flags(rawValue: 1 << 0)
        static let batteryLevelPresent     = Flags(rawValue: 1 << 1)
        static let additionalStatusPresent = Flags(rawValue: 1 << 2)
    }

    // MARK: - Power State

    public struct PowerState {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public var batteryPresent: BatteryPresent {
            BatteryPresent(rawValue: UInt8(rawValue & 0x03)) ?? .unknown
        }

        public var wiredExternalPowerConnected: ExternalPowerState {
            ExternalPowerState(rawValue: UInt8((rawValue >> 2) & 0x03)) ?? .unknown
        }

        public var wirelessExternalPowerConnected: ExternalPowerState {
            ExternalPowerState(rawValue: UInt8((rawValue >> 4) & 0x03)) ?? .unknown
        }

        public var chargeState: ChargeState {
            ChargeState(rawValue: UInt8((rawValue >> 6) & 0x03)) ?? .unknown
        }

        public var chargeLevel: ChargeLevel {
            ChargeLevel(rawValue: UInt8((rawValue >> 8) & 0x03)) ?? .unknown
        }

        public var chargingType: ChargingType {
            ChargingType(rawValue: UInt8((rawValue >> 10) & 0x03)) ?? .unknownOrNotCharging
        }

        public var chargingFaultReasonBattery: Bool {
            (rawValue >> 12) & 0x01 == 1
        }

        public var chargingFaultReasonExternalPower: Bool {
            (rawValue >> 13) & 0x01 == 1
        }

        public var chargingFaultReasonOther: Bool {
            (rawValue >> 14) & 0x01 == 1
        }

        public var hasChargingFault: Bool {
            chargingFaultReasonBattery || chargingFaultReasonExternalPower || chargingFaultReasonOther
        }

        public var isCharging: Bool {
            chargeState == .charging
        }
    }

    public enum BatteryPresent: UInt8 {
        case no      = 0
        case yes     = 1
        case unknown = 2
    }

    public enum ExternalPowerState: UInt8 {
        case no      = 0
        case yes     = 1
        case unknown = 2
    }

    public enum ChargeState: UInt8 {
        case unknown              = 0
        case charging             = 1
        case dischargingActive    = 2
        case dischargingInactive  = 3
    }

    public enum ChargeLevel: UInt8 {
        case unknown  = 0
        case good     = 1
        case low      = 2
        case critical = 3
    }

    public enum ChargingType: UInt8 {
        case unknownOrNotCharging = 0
        case constantCurrent      = 1
        case constantVoltage      = 2
        case trickle              = 3
    }

    // MARK: - Additional Status

    public struct AdditionalStatus {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public var serviceRequired: ServiceRequired {
            ServiceRequired(rawValue: rawValue & 0x03) ?? .unknown
        }

        public var batteryFault: Bool {
            (rawValue >> 2) & 0x01 == 1
        }
    }

    public enum ServiceRequired: UInt8 {
        case no      = 0
        case yes     = 1
        case unknown = 2
    }

    // MARK: - Parsing

    public init?(data: Data) {
        // Minimum: flags(1) + powerState(2) = 3 bytes
        guard data.count >= 3 else { return nil }

        let flags = Flags(rawValue: data[0])
        powerState = PowerState(rawValue: data.subdata(in: 1..<3).to(UInt16.self))

        var offset = 3

        if flags.contains(.identifierPresent) {
            guard data.count >= offset + 2 else { return nil }
            identifier = data.subdata(in: offset..<(offset + 2)).to(UInt16.self)
            offset += 2
        } else {
            identifier = nil
        }

        if flags.contains(.batteryLevelPresent) {
            guard data.count >= offset + 1 else { return nil }
            batteryLevel = data[offset]
            offset += 1
        } else {
            batteryLevel = nil
        }

        if flags.contains(.additionalStatusPresent) {
            guard data.count >= offset + 1 else { return nil }
            additionalStatus = AdditionalStatus(rawValue: data[offset])
        } else {
            additionalStatus = nil
        }
    }
}
