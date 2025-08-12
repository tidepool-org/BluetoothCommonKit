//
//  BatteryLevelCharacteristic.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//


import Foundation
import CoreBluetooth

public class BatteryLevelCharacteristic {
    var messageQueue: MessagingQueue

    private var batteryNotificationTimer: Timer? = nil

    public var isSubscribed: Bool {
        messageQueue.gattServer.isCharacteristicSubscribed(CBUUID(string: BatteryCharacteristicUUID.batteryLevel.rawValue)) == true
    }

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
        batteryNotificationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.sendUpdate()
        }
    }

    public func sendUpdate() {
        if isSubscribed {
            let valuepair = UUIDValuePair(
                uuid: CBUUID(string: BatteryCharacteristicUUID.batteryLevel.rawValue),
                value: createData()
            )
            ConsoleOut.shared.logMessage(message: "\(#function): \(valuepair.description)")
            messageQueue.addQueueItem(valuepair)
        }
    }

    public func createData() -> Data {
        let batteryLevel = UInt8.random(in: 0...100)
        ConsoleOut.shared.logMessage(message: "\(#function): battery level is \(batteryLevel)")
        return Data(batteryLevel)
    }

    public func onRead() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading battery level characteristic")
        return (CBATTError.Code.success, self.createData())
    }
}
