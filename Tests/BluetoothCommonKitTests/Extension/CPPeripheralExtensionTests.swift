//
//  CPPeripheralExtensionTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import BluetoothCommonKit

class CPPeripheralExtensionTests: XCTestCase {

    func testServicesToDiscover() {
        let uuidKnownService1 = CBUUID(string: "1111")
        let uuidKnownService2 = CBUUID(string: "2222")
        let uuidUknownService1 = CBUUID(string: "3333")
        let uuidUknownService2 = CBUUID(string: "4444")
        let knownService1 = CBMutableService(type: uuidKnownService1, primary: true)
        let knownService2 = CBMutableService(type: uuidKnownService2, primary: false)
        let services: [CBService] = [knownService1, knownService2]
        
        let mockPeripheral = MockPeripheral(services: services)
        
        let servicesToDiscover = mockPeripheral.servicesToDiscover(from: [uuidKnownService1, uuidKnownService2, uuidUknownService1, uuidUknownService2])
        XCTAssertEqual(servicesToDiscover.count, 2)
        XCTAssertEqual(servicesToDiscover, [uuidUknownService1, uuidUknownService2])
    }
    
    func testCharacteristicsToDiscover() {
        let uuidService = CBUUID(string: "1111")
        let service = CBMutableService(type: uuidService, primary: true)
        let services: [CBService] = [service]
        
        let uuidKnownCharacteristic1 = CBUUID(string: "2222")
        let uuidKnownCharacteristic2 = CBUUID(string: "3333")
        let uuidUnknownCharacteristic1 = CBUUID(string: "4444")
        let uuidUnknownCharacteristic2 = CBUUID(string: "5555")
        
        let knownCharacteristic1 = CBMutableCharacteristic(type: uuidKnownCharacteristic1, properties: .read, value: Data(), permissions: .readable)
        let knownCharacteristic2 = CBMutableCharacteristic(type: uuidKnownCharacteristic2, properties: .read, value: Data(), permissions: .readable)
        let characteristics: [CBCharacteristic] = [knownCharacteristic1, knownCharacteristic2]
        service.characteristics = characteristics
        
        let mockPeripheral = MockPeripheral(services: services)
        
        let characteristicstoDiscover = mockPeripheral.characteristicsToDiscover(from: [uuidKnownCharacteristic1, uuidKnownCharacteristic2, uuidUnknownCharacteristic1, uuidUnknownCharacteristic2],
                                                                                 for: service)
        XCTAssertEqual(characteristicstoDiscover.count, 2)
        XCTAssertEqual(characteristicstoDiscover, [uuidUnknownCharacteristic1, uuidUnknownCharacteristic2])
    }
    
}
