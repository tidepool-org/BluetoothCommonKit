//
//  CBCentralManager.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth

// MARK: - It's only valid to call these methods on the central manager's queue
public extension CBCentralManager {
    func connectIfNecessary(_ peripheral: CBPeripheral, options: [String: Any]? = nil) {
        guard case .poweredOn = state else {
            return
        }

        switch peripheral.state {
        case .connected:
            delegate?.centralManager?(self, didConnect: peripheral)
        case .connecting, .disconnected, .disconnecting:
            fallthrough
        @unknown default:
            connect(peripheral, options: options)
        }
    }
    
    func cancelPeripheralConnectionIfNecessary(_ peripheral: CBPeripheral) {
        guard case .poweredOn = state else {
            return
        }

        switch peripheral.state {
        case .disconnected:
            delegate?.centralManager?(self, didDisconnectPeripheral: peripheral, error: nil)
        case .connected, .connecting, .disconnecting:
            fallthrough
        @unknown default:
            cancelPeripheralConnection(peripheral)
        }
    }
}

public extension CBManagerState {
    var description: String {
        switch self {
        case .poweredOff:
            return "Powered Off"
        case .poweredOn:
            return "Powered On"
        case .resetting:
            return "Resetting"
        case .unauthorized:
            return "Unauthorized"
        case .unknown:
            return "Unknown"
        case .unsupported:
            return "Unsupported"
        @unknown default:
            return "Unknown: \(rawValue)"
        }
    }
}
