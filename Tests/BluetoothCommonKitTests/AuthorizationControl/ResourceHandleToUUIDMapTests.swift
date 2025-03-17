//
//  ResourceHandleToUUIDMapTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import BluetoothCommonKit

class ResourceHandleToUUIDMapTests: XCTestCase {
    
    func testAttributeType() {
        XCTAssertEqual(AttributeType(rawValue: 0x00), AttributeType.primaryService)
        XCTAssertEqual(AttributeType(rawValue: 0x01), AttributeType.secondaryService)
        XCTAssertEqual(AttributeType(rawValue: 0x02), AttributeType.characteristicValue)
        XCTAssertNil(AttributeType(rawValue: 0x03))
    }
    
    func testGetResourceHandleToUUIDMapRequest() {
        let request = ResourceHandleToUUIDMap.request
        XCTAssertEqual(request, Data([ACControlPointOpcode.getResourceHandleToUUIDMap.rawValue]))
    }
    
    func testResourceHandleToUUIDMapResponse() {
        let acsServiceHandle: UInt16 = 1
        let acsServiceUUIDSize: UInt8 = 2
        let acsServiceUUID: UInt16 = 0x7FC0
        let acsServiceNumOfSubAttributes: UInt8 = 5
        let acsStatusHandle: UInt16 = 2
        let acsStatusUUIDSize: UInt8 = 2
        let acsStatusUUID: UInt16 = 0x7FC1
        let acsDataInHandle: UInt16 = 3
        let acsDataInUUIDSize: UInt8 = 2
        let acsDataInUUID: UInt16 = 0x7FC2
        let acsDataOutNotifyHandle: UInt16 = 4
        let acsDataOutNotifyUUIDSize: UInt8 = 2
        let acsDataOutNotifyUUID: UInt16 = 0x7FC3
        let acsDataOutIndicateHandle: UInt16 = 5
        let acsDataOutIndicateUUIDSize: UInt8 = 2
        let acsDataOutIndicateUUID: UInt16 = 0x7FC4
        let acsCPHandle: UInt16 = 6
        let acsCPUUIDSize: UInt8 = 2
        let acsCPUUID: UInt16 = 0x7FC5
        
        let primaryService1Handle: UInt16 = 7
        let primaryService1UUIDSize: UInt8 = 4
        let primaryService1UUID: UInt32 = 0x10010001
        let primaryService1NumOfSubAttributes: UInt8 = 2
        let primaryService2Handle: UInt16 = 10
        let primaryService2UUIDSize: UInt8 = 16
        let primaryService2UUID: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
        let primaryService2NumOfSubAttributes: UInt8 = 2
        let secondaryService1Handle: UInt16 = 12
        let secondardService1UUIDSize: UInt8 = 2
        let secondardService1UUID: UInt16 = 0x0007
        let secondaryService1NumOfSubAttributes: UInt8 = 1
        let char1Handle: UInt16 = 8
        let char1UUIDSize: UInt8 = 2
        let char1UUID: UInt16 = 0x0002
        let char2Handle: UInt16 = 9
        let char2UUIDSize: UInt8 = 2
        let char2UUID: UInt16 = 0x0004
        let char3Handle: UInt16 = 11
        let char3UUIDSize: UInt8 = 2
        let char3UUID: UInt16 = 0x0006
        let char4Handle: UInt16 = 13
        let char4UUIDSize: UInt8 = 2
        let char4UUID: UInt16 = 0x0008
        
        var response = Data()
        response.append(ACControlPointOpcode.resourceHandleToUUIDMapResponse.rawValue)
        response.append(AttributeType.primaryService.rawValue)
        response.append(acsServiceHandle)
        response.append(acsServiceUUIDSize)
        response.append(acsServiceUUID)
        response.append(acsServiceNumOfSubAttributes)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(acsStatusHandle)
        response.append(acsStatusUUIDSize)
        response.append(acsStatusUUID)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(acsDataInHandle)
        response.append(acsDataInUUIDSize)
        response.append(acsDataInUUID)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(acsDataOutNotifyHandle)
        response.append(acsDataOutNotifyUUIDSize)
        response.append(acsDataOutNotifyUUID)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(acsDataOutIndicateHandle)
        response.append(acsDataOutIndicateUUIDSize)
        response.append(acsDataOutIndicateUUID)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(acsCPHandle)
        response.append(acsCPUUIDSize)
        response.append(acsCPUUID)
        response.append(AttributeType.primaryService.rawValue)
        response.append(primaryService1Handle)
        response.append(primaryService1UUIDSize)
        response.append(primaryService1UUID)
        response.append(primaryService1NumOfSubAttributes)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(char1Handle)
        response.append(char1UUIDSize)
        response.append(char1UUID)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(char2Handle)
        response.append(char2UUIDSize)
        response.append(char2UUID)
        response.append(AttributeType.primaryService.rawValue)
        response.append(primaryService2Handle)
        response.append(primaryService2UUIDSize)
        response.append(contentsOf: primaryService2UUID)
        response.append(primaryService2NumOfSubAttributes)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(char3Handle)
        response.append(char3UUIDSize)
        response.append(char3UUID)
        response.append(AttributeType.secondaryService.rawValue)
        response.append(secondaryService1Handle)
        response.append(secondardService1UUIDSize)
        response.append(secondardService1UUID)
        response.append(secondaryService1NumOfSubAttributes)
        response.append(AttributeType.characteristicValue.rawValue)
        response.append(char4Handle)
        response.append(char4UUIDSize)
        response.append(char4UUID)
        
        let result = ResourceHandleToUUIDMap.handleResponse(response)
        switch result {
        case .success(let resourceHandleToUUIDMap):
            XCTAssertEqual(resourceHandleToUUIDMap.count, 13)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: acsServiceUUID).hexadecimalString)], acsServiceHandle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: acsStatusUUID).hexadecimalString)], acsStatusHandle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: acsDataInUUID).hexadecimalString)], acsDataInHandle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: acsDataOutNotifyUUID).hexadecimalString)], acsDataOutNotifyHandle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: acsDataOutIndicateUUID).hexadecimalString)], acsDataOutIndicateHandle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: acsCPUUID).hexadecimalString)], acsCPHandle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: primaryService1UUID).hexadecimalString)], primaryService1Handle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: char1UUID).hexadecimalString)], char1Handle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: char2UUID).hexadecimalString)], char2Handle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: char3UUID).hexadecimalString)], char3Handle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: char4UUID).hexadecimalString)], char4Handle)
            let expectedLongUUID = "100f0e0d-0c0b-0a09-0807-060504030201"
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: expectedLongUUID)], primaryService2Handle)
            XCTAssertEqual(resourceHandleToUUIDMap[CBUUID(string: Data(bigEndian: secondardService1UUID).hexadecimalString)], secondaryService1Handle)
        case .failure(_):
            XCTAssert(false)
        }
    }
}
