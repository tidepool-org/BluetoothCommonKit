//
//  GATTService.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol GATTServiceDelegate: AnyObject {
    func centralDidSubscribe(characteristicUUID: CBUUID)
    func centralDidUnsubscribe(characteristicUUID: CBUUID)
    func isProcedureAlreadyInProgress() -> Bool
    func isOutOfRange() -> Bool
}

public protocol GATTServiceObservers: AnyObject {
    func readyToSend()
}

public protocol GATTService {
    func preWriteConstrain(_ preWriteConstrain: @escaping ([CallbackCharacteristic]) -> CBATTError.Code)
    func createService(_ serviceUUID : CBUUID, primary : Bool, withCharacteristics characteristics: [CallbackCharacteristic])
    func addService()
    func update(_ data : Data?, forUUID : CBUUID, onSubscribedCentrals: [CBCentral]?)
    func startAdvertising(advertisementDataHandler: @escaping () -> [String: Any]?)
    func isCharacteristicSubscribed (_ forUUID : CBUUID) -> Bool?
    var delegate: GATTServiceDelegate? { get set }
    var observers: GATTServiceObservers? { get set }
}

public extension GATTService {
    func startAdvertising() { startAdvertising(advertisementDataHandler: { nil }) }
}
