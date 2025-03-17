//
//  DeviceCommLoggingDelegate.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

public protocol DeviceCommLoggingDelegate: AnyObject {
    func logConnectionEvent(function: StaticString, _ message: String)
    func logSendEvent(function: StaticString, _ message: String)
    func logReceiveEvent(function: StaticString, _ message: String)
    func logErrorEvent(function: StaticString, _ message: String)
}

public extension DeviceCommLoggingDelegate {
    func logConnectionEvent(function: StaticString = #function, _ message: String = "") { logConnectionEvent(function: function, message) }
    func logSendEvent(function: StaticString = #function, _ message: String = "") { logSendEvent(function: function, message) }
    func logReceiveEvent(function: StaticString = #function, _ message: String = "") { logReceiveEvent(function: function, message) }
    func logErrorEvent(function: StaticString = #function, _ message: String = "") { logErrorEvent(function: function, message) }
}
