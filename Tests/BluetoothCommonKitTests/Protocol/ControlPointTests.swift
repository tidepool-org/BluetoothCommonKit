//
//  ControlPointTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class ControlPointTests: XCTestCase {

    private var testControlPoint = TestControlPoint()

    override func tearDown() {
        _ = testControlPoint.getPendingProceduresAndReset()
    }
    
    func testRequestQueue() {
        XCTAssertTrue(testControlPoint.requestQueue.isEmpty)
        let dummyRequest = Data(hex:"0102030405")
        testControlPoint.appendToRequestQueue(dummyRequest, completion: nil)
        XCTAssertTrue(!testControlPoint.requestQueue.isEmpty)
        XCTAssertEqual(testControlPoint.requestQueue.count, 1)
        XCTAssertEqual(testControlPoint.requestQueue.first?.request, dummyRequest)
    }

    func testIsExpectedRequest() {
        let dummyRequest = Data(ACControlPointOpcode.abort.rawValue)
        testControlPoint.appendToRequestQueue(dummyRequest, completion: nil)
        XCTAssertTrue(testControlPoint.isExpectedRequest(dummyRequest, expectedOpcode: ACControlPointOpcode.abort))
    }

    func testCompleteProcedure() {
        let dummyRequest = Data(ACControlPointOpcode.abort.rawValue)
        testControlPoint.procedureRunning = true
        testControlPoint.appendToRequestQueue(dummyRequest, completion: nil)
        _ = testControlPoint.completeProcedure(ACControlPointOpcode.attMTUResponse)
        XCTAssertTrue(!testControlPoint.requestQueue.isEmpty)
        _ = testControlPoint.completeProcedure(ACControlPointOpcode.abort)
        XCTAssertTrue(testControlPoint.requestQueue.isEmpty)
        XCTAssertFalse(testControlPoint.procedureRunning)
    }
    
    func testNextRequestToSend() {
        let dummyRequest = Data(ACControlPointOpcode.abort.rawValue)
        testControlPoint.appendToRequestQueue(dummyRequest, completion: nil)
        let nextRequest = testControlPoint.nextRequestToSend()
        XCTAssertEqual(nextRequest?.0, dummyRequest)
    }

    func testBuildControlPointRequest() {
        var opcode = ACControlPointOpcode.getACSFeature
        var request = TestControlPoint.buildControlPointRequest(opcode: opcode)
        XCTAssertEqual(request.count, 1)
        XCTAssertEqual(request[request.startIndex...].to(UInt8.self), ACControlPointOpcode.getACSFeature.rawValue)
        
        opcode = ACControlPointOpcode.activateRestrictionMap
        let restrictionMapID: UInt16 = 0x0001
        let operand = Data(restrictionMapID)
        request = TestControlPoint.buildControlPointRequest(opcode: opcode, operand: operand)
        XCTAssertEqual(request.count, 3)
        XCTAssertEqual(request[request.startIndex...].to(UInt8.self), ACControlPointOpcode.activateRestrictionMap.rawValue)
        XCTAssertEqual(request[request.startIndex.advanced(by: 1)...].to(UInt16.self), restrictionMapID)
    }

    func testReset() {
        testControlPoint.appendToRequestQueue(Data(1), completion: nil)
        testControlPoint.appendToRequestQueue(Data(2), completion: nil)
        testControlPoint.procedureRunning = true
        _ = testControlPoint.getPendingProceduresAndReset()
        XCTAssertTrue(testControlPoint.requestQueue.isEmpty)
        XCTAssertFalse(testControlPoint.procedureRunning)
    }
}

private class TestControlPoint: ControlPoint {
    func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        return "TestControlPoint.TestResponseProcedureID"
    }

    func procedureIDForRequest(_ response: Data) -> ProcedureID {
        return "TestControlPoint.TestRequestProcedureID"
    }

    var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])

    var procedureRunning: Bool = false
    
    func nextRequestToSend() -> (Data, Any?)? {
        lockedRequestQueue.value.first
    }
}

extension ControlPoint {
    var requestQueue: [(request: Data, completion: Any?)] {
        lockedRequestQueue.value
    }
}
