//
//  MockPeripheral.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit

class MockPeripheral: PeripheralProtocol {
    
    var delegate: CBPeripheralDelegate?
    
    var identifier: UUID = UUID()
    
    var state: CBPeripheralState = .disconnected
    
    let services: [CBService]?
    
    var servicesRequestedToDiscover: [CBUUID]?
    
    var discoverServicesRequestedHandler: (() -> Void)?
    
    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        servicesRequestedToDiscover = serviceUUIDs
        discoverServicesRequestedHandler?()
    }
    
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        
    }
    
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        
    }
    
    func readValue(for characteristic: CBCharacteristic) {
        
    }
    
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        
    }
        
    init(services: [CBService]? = nil,
         discoverServicesRequestedHandler: (() -> Void)? = nil) {
        self.services = services
        self.discoverServicesRequestedHandler = discoverServicesRequestedHandler
    }
    
}
