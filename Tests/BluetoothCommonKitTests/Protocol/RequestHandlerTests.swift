//
//  RequestHandlerTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class RequestHandlerTests: XCTestCase, RequestHandler {
    
    func testBuildControlPointRequest() {
        let opcode = ACControlPointOpcode.responseCode
        let operand = Data([0x01, 0x02, 0x03, 0x04])
        let request = RequestHandlerTests.buildControlPointRequest(opcode: opcode, operand: operand)
        var expectedRequest = Data()
        expectedRequest.append(opcode.rawValue)
        expectedRequest.append(operand)
        XCTAssertEqual(request, expectedRequest)
    }
    
}
