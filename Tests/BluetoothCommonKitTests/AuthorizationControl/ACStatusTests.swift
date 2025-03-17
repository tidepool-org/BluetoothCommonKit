//
//  ACStatusTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class ACStatusTests: XCTestCase {
    
    func testStatusValueValid() {
        let expectedCurrentRestrictionMapID: UInt16 = 1
        let expectedStatus: StatusFlag = .securityControlsEnabled
        
        var expectedStatusValue = Data()
        expectedStatusValue.append(expectedStatus.rawValue)
        expectedStatusValue.append(expectedCurrentRestrictionMapID)
        
        let parsedValue = ACStatus.handleData(expectedStatusValue)
        XCTAssertNotNil(parsedValue)
        if let parsedValue = parsedValue {
            XCTAssertEqual(parsedValue.status, expectedStatus)
            XCTAssertEqual(parsedValue.currentRestrictionMapID, Int(expectedCurrentRestrictionMapID))
        }
    }
    
    func testStatusValueInvalid() {
        let expectedCurrentRestrictionMapID: UInt16 = 1
        let expectedStatus: StatusFlag = .securityControlsEnabled
        let extraData: UInt8 = 0xFF
        
        var expectedStatusValue = Data()
        expectedStatusValue.append(expectedStatus.rawValue)
        expectedStatusValue.append(expectedCurrentRestrictionMapID)
        expectedStatusValue.append(extraData)
        
        let parsedValue = ACStatus.handleData(expectedStatusValue)
        XCTAssertNil(parsedValue)
    }
}
