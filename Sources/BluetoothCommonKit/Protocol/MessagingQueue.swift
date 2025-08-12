//
//  MessagingQueue.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public protocol MessagingQueue {
    var gattServer: GATTService! { get }
    var hasMessagesInQueue: Bool { get }
    func addQueueItem(_ update : UUIDValuePair)
    func emptyQueue()
}
