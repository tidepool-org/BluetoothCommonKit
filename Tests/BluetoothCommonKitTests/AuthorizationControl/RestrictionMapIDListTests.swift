//
//  RestrictionMapIDListTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class RestrictionMapIDListTests: XCTestCase {
    
    func testGetRestrictionMapIDListRequest() {
        let request = RestrictionMapIDList.request
        XCTAssertEqual(request, Data([ACControlPointOpcode.getRestrictionMapIDList.rawValue]))
    }
    
    func testRestrictionMapIDListResponse() {
        let expectedIDList: [UInt16] = [0x0001, 0x0002, 0x0003]
        let expectedSecurityConfigurationIDList: [UInt16] = [0x0000, 0x0001, 0x0002]
        
        var response = Data()
        response.append(ACControlPointOpcode.restrictionMapIDListResponse.rawValue)
        response.append(expectedIDList[0])
        response.append(expectedSecurityConfigurationIDList[0])
        response.append(expectedIDList[1])
        response.append(expectedSecurityConfigurationIDList[1])
        response.append(expectedIDList[2])
        response.append(expectedSecurityConfigurationIDList[2])
        
        let result = RestrictionMapIDList.handleResponse(response)
        switch result {
        case .success:
            XCTAssert(true)
        case .failure(_):
            XCTAssert(false)
        }
    }
}
