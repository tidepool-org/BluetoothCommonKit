//
//  InformationSecurityConfigurationDescriptorTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class InformationSecurityConfigurationDescriptorTests: XCTestCase {
    
    func testRecordTypeSecurityConfiguration() {
        XCTAssertEqual(RecordTypeSecurityConfiguration(rawValue: 0x00), RecordTypeSecurityConfiguration.informationSecurityConfigurationID)
        XCTAssertNil(RecordTypeSecurityConfiguration(rawValue: 0x01))
    }
    
    func testSecurityControlType() {
        XCTAssertEqual(SecurityControlType(rawValue: 0x00), SecurityControlType.nonce)
        XCTAssertEqual(SecurityControlType(rawValue: 0x01), SecurityControlType.authenticatedATTPacket)
        XCTAssertEqual(SecurityControlType(rawValue: 0x02), SecurityControlType.encryptedATTPacket)
        XCTAssertEqual(SecurityControlType(rawValue: 0x03), SecurityControlType.authenticatedEncryptedATTPacket)
        XCTAssertEqual(SecurityControlType(rawValue: 0x04), SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData)
        XCTAssertEqual(SecurityControlType(rawValue: 0x05), SecurityControlType.unencryptedATTPacket)
        XCTAssertEqual(SecurityControlType(rawValue: 0x06), SecurityControlType.mac)
        XCTAssertNil(SecurityControlType(rawValue: 0x07))
    }
    
    func testGetInformationSecurityConfigurationDescriptorRequest() {
        // `request` gained a security-configuration-ID filter operand (#22): opcode
        // followed by the match-all filter.
        let request = InformationSecurityConfigurationDescriptor.request()
        var expected = Data([ACControlPointOpcode.getInformationSecurityConfigurationDescriptor.rawValue])
        expected.append(Data(InformationSecurityConfigurationDescriptor.noFilter))
        XCTAssertEqual(request, expected)
    }
    
    func testInformationSecurityConfigurationDescriptorResponse() {
        // information security configuration 1
        let securityConfigurationID1: UInt16 = 1
        let config1DataSize: UInt8 = 6
        let config1NumControls: UInt8 = 3
        let config1KeyID: UInt16 = 2
        
        // information security configuration 2
        let securityConfigurationID2: UInt16 = 2
        let config2DataSize: UInt8 = 6
        let config2NumControls: UInt8 = 3
        let config2KeyID: UInt16 = 3
        
        // information security configuration 3
        let securityConfigurationID3: UInt16 = 3
        let config3DataSize: UInt8 = 2
        let config3NumControls: UInt8 = 1
        
        var response = Data()
        response.append(ACControlPointOpcode.informationSecurityConfigurationDescriptorResponse.rawValue)
        response.append(RecordTypeSecurityConfiguration.informationSecurityConfigurationID.rawValue)
        response.append(securityConfigurationID1)
        response.append(config1DataSize)
        response.append(config1NumControls)
        response.append(SecurityControlType.nonce.rawValue)
        response.append(SecurityControlType.mac.rawValue)
        response.append(SecurityControlType.authenticatedEncryptedATTPacket.rawValue)
        response.append(config1KeyID)
        response.append(RecordTypeSecurityConfiguration.informationSecurityConfigurationID.rawValue)
        response.append(securityConfigurationID2)
        response.append(config2DataSize)
        response.append(config2NumControls)
        response.append(SecurityControlType.nonce.rawValue)
        response.append(SecurityControlType.mac.rawValue)
        response.append(SecurityControlType.authenticatedATTPacket.rawValue)
        response.append(config2KeyID)
        response.append(RecordTypeSecurityConfiguration.informationSecurityConfigurationID.rawValue)
        response.append(securityConfigurationID3)
        response.append(config3DataSize)
        response.append(config3NumControls)
        response.append(SecurityControlType.unencryptedATTPacket.rawValue)
        
        let securityManager = SecurityManager()
        let result = InformationSecurityConfigurationDescriptor.handleResponse(response, securityManager: securityManager)
        switch result {
        case .success:
            let expectedSecurityControls: [SecurityControlType] = [SecurityControlType.unencryptedATTPacket]
            XCTAssertEqual(securityManager.configuration.securityControls, expectedSecurityControls)
        case .failure(_):
            XCTAssert(false)
        }
    }    
}
