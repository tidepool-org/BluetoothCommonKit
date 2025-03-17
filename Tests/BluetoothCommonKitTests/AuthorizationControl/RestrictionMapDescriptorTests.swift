//
//  RestrictionMapDescriptorTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class RestrictionMapDescriptorTests: XCTestCase {
    
    func testRecordTypeRestrictionMap() {
        XCTAssertEqual(RecordTypeRestrictionMap(rawValue: 0x00), RecordTypeRestrictionMap.restrictionMapID)
        XCTAssertEqual(RecordTypeRestrictionMap(rawValue: 0x01), RecordTypeRestrictionMap.defaultInformationSecurityConfiguration)
        XCTAssertEqual(RecordTypeRestrictionMap(rawValue: 0x02), RecordTypeRestrictionMap.protectedCharacteristic)
        XCTAssertEqual(RecordTypeRestrictionMap(rawValue: 0x03), RecordTypeRestrictionMap.protectedControlPointProcedures)
        XCTAssertNil(RecordTypeRestrictionMap(rawValue: 0x04))
    }
    
    func testGetRestrictionMapDescriptorRequest() {
        let request = RestrictionMapDescriptor.request
        XCTAssertEqual(request, Data([ACControlPointOpcode.getRestrictionMapDescriptor.rawValue]))
    }
    
    func testRestrictionMapDescriptorResponse() {
        let expectedRestrictionMapID: UInt16 = 1
        let expectedDataSizeRestrictionMapID: UInt8 = 0
        let expectedDefaultSecurityConfiguration: UInt16 = 0
        let expectedDataSizeDefaultSecurityConfiguration: UInt8 = 0
        let expectedResourceHandleCharacteristic: UInt16 = 0x0006
        let expectedDataSizeCharacteristic: UInt8 = 4
        let expectedOpcodeWriteRequest: UInt16 = 0x000A
        let expectedSecurityConfigurationCharacteristic: UInt16 = 0x0001
        let expectedResourceHandleControlPoint: UInt16 = 0x00010
        let expectedDataSizeControlPoint: UInt8 = 4
        let expectedOpcodeProcedure: UInt16 = 0x0005
        let expectedSecurityConfigurationControlPoint: UInt16 = 0x0002
        
        var response = Data()
        response.append(ACControlPointOpcode.restrictionMapDescriptorResponse.rawValue)
        response.append(RecordTypeRestrictionMap.restrictionMapID.rawValue)
        response.append(expectedRestrictionMapID)
        response.append(expectedDataSizeRestrictionMapID)
        response.append(RecordTypeRestrictionMap.defaultInformationSecurityConfiguration.rawValue)
        response.append(expectedDefaultSecurityConfiguration)
        response.append(expectedDataSizeDefaultSecurityConfiguration)
        response.append(RecordTypeRestrictionMap.protectedCharacteristic.rawValue)
        response.append(expectedResourceHandleCharacteristic)
        response.append(expectedDataSizeCharacteristic)
        response.append(expectedOpcodeWriteRequest)
        response.append(expectedSecurityConfigurationCharacteristic)
        response.append(RecordTypeRestrictionMap.protectedControlPointProcedures.rawValue)
        response.append(expectedResourceHandleControlPoint)
        response.append(expectedDataSizeControlPoint)
        response.append(expectedOpcodeProcedure)
        response.append(expectedSecurityConfigurationControlPoint)
        
        let result = RestrictionMapDescriptor.handleResponse(response)
        switch result {
        case .success:
            XCTAssert(true)
        case .failure(_):
            XCTAssert(false)
        }
    }
}
