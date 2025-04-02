//
//  MessageQueue.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth

public class MessageQueue: NSObject, MessagingQueue {
    public var gattServer: GATTService!
    
    var timer: Timer = Timer()
    public var messageQueue: [UUIDValuePair] = [UUIDValuePair]()
    var lock: AnyObject = NSNull() as AnyObject
    
    public func sync(_ lock: AnyObject, closure: () -> Void) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    public func addQueueItem(_ update : UUIDValuePair) {
        print("UPDATE_GATT_SERVER: async dispatch active")
        let shouldSend = !hasMessagesInQueue
        print("shouldSend \(shouldSend)")
        sync(lock) {
            messageQueue.append(update)
        }
        if shouldSend { sendNextQueueItem() }
        print("UPDATE_GATT_SERVER: update done.")
    }

    public func emptyQueue() {
        print("UPDATE_GATT_SERVER: async dispatch active")
        sync(lock) { messageQueue.removeAll() }
        print("UPDATE_GATT_SERVER: empty queue done.")
    }

    public var hasMessagesInQueue: Bool {
        return !messageQueue.isEmpty
    }

    @objc public func sendNextQueueItem() {
        guard let uuidValuePair = messageQueue.first else { return }

        ConsoleOut.shared.logMessage(message: "sendNextQueueItem sent next item")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.gattServer.update(uuidValuePair.value, forUUID: uuidValuePair.uuid, onSubscribedCentrals: uuidValuePair.onSubscribedCentrals)
        }
    }

    public init(gattService: GATTService) {
        super.init()
        self.gattServer = gattService
        self.gattServer.observers = self
    }
}

extension MessageQueue: GATTServiceObservers {
    public func readyToSend() {
        print("\(#function)")

        guard hasMessagesInQueue else {
            print("no messages to send")
            return
        }

        messageQueue.removeFirst()
        print("has more messages in queue \(hasMessagesInQueue) (\(messageQueue.count))")
        sendNextQueueItem()
    }
}
