//
//  SegmentationHandlerTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class SegmentationHandlerTests: XCTestCase, SegmentationHandler {
    
    var maxRequestSize: Int = 19
    
    var storedResponses: [Data] = []
    
    var lockedSegmentCounter: Locked<UInt8> = Locked(0)

    func testSegmentCounter() {
        for counter in 0...100 {
            segmentCounter = UInt8(counter)
            XCTAssertEqual(segmentCounter, UInt8(counter % 64))
        }
    }
    
    func testSegmentedRequest1() {
        let uint8Array: [UInt8] = stride(from: 1, through: 16, by: 1).map { UInt8($0) }
        let request = Data(uint8Array)
        let segmentCountInitialValue: UInt8 = 0
        var expectedRequest = Data(SegmentationHeader.firstPart.rawValue | SegmentationHeader.lastPart.rawValue | (segmentCountInitialValue << 2))
        expectedRequest.append(request)
        
        let segmentedRequests = segmentPayload(request)
        
        XCTAssertEqual(segmentedRequests.count, 1)
        XCTAssertEqual(segmentCounter, 1)
        XCTAssertEqual(segmentedRequests[0], expectedRequest)
    }
    
    func testSegmentedRequest2() {
        let uint8Array: [UInt8] = stride(from: 1, through: 30, by: 1).map { UInt8($0) }
        let request = Data(uint8Array)
        let segmentCountInitialValue: UInt8 = 0
        var expectedSegmentedRequest1 = Data(SegmentationHeader.firstPart.rawValue | (segmentCountInitialValue << 2))
        expectedSegmentedRequest1.append(contentsOf: stride(from: 1, through: 19, by: 1).map { UInt8($0) })
        
        var expectedSegmentedRequest2 = Data(SegmentationHeader.lastPart.rawValue | ((segmentCountInitialValue+1) << 2))
        expectedSegmentedRequest2.append(contentsOf: stride(from: 20, through: 30, by: 1).map { UInt8($0) })
        
        let segmentedRequests = segmentPayload(request)
        XCTAssertEqual(segmentedRequests.count, 2)
        XCTAssertEqual(segmentCounter, 2)
        XCTAssertEqual(segmentedRequests[0], expectedSegmentedRequest1)
        XCTAssertEqual(segmentedRequests[1], expectedSegmentedRequest2)
    }
    
    func testCheckResponseSegment() {
        // create a segmented response
        let uint8Array1: [UInt8] = stride(from: 1, through: 30, by: 1).map { UInt8($0) }
        let expectedResponse = Data(uint8Array1)
        let segmentCountInitialValue: UInt8 = 0
        var responseSegment1 = Data(SegmentationHeader.firstPart.rawValue | (segmentCountInitialValue << 2))
        responseSegment1.append(contentsOf: stride(from: 1, through: 19, by: 1).map { UInt8($0) })
        var responseSegment2 = Data(SegmentationHeader.lastPart.rawValue | ((segmentCountInitialValue+1) << 2))
        responseSegment2.append(contentsOf: stride(from: 20, through: 30, by: 1).map { UInt8($0) })
        
        // create a segmented interrupting response
        let uint8Array2: [UInt8] = stride(from: 31, through: 60, by: 1).map { UInt8($0) }
        let expectedInterruptingResponse = Data(uint8Array2)
        let interruptingSegmentCountInitialValue: UInt8 = 54
        var interruptingResponse1 = Data(SegmentationHeader.firstPart.rawValue | (interruptingSegmentCountInitialValue << 2))
        interruptingResponse1.append(contentsOf: stride(from: 31, through: 49, by: 1).map { UInt8($0) })
        var interruptingResponse2 = Data(SegmentationHeader.lastPart.rawValue | ((interruptingSegmentCountInitialValue+1) << 2))
        interruptingResponse2.append(contentsOf: stride(from: 50, through: 60, by: 1).map { UInt8($0) })

        var result = checkResponseSegment(responseSegment1)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            if error != .partialResponse {
                XCTAssert(false)
            }
        }
        XCTAssertEqual(storedResponses[0], responseSegment1)
        
        result = checkResponseSegment(interruptingResponse1)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            if error != .partialResponse {
                XCTAssert(false)
            }
        }
        XCTAssertEqual(storedResponses[0], responseSegment1)
        XCTAssertEqual(storedResponses[1], interruptingResponse1)
        
        result = checkResponseSegment(responseSegment2)
        switch result {
        case .success(let complete):
            XCTAssertEqual(complete, expectedResponse)
        case .failure(_):
            XCTAssert(false)
        }
        XCTAssertEqual(storedResponses.count, 1)
        XCTAssertEqual(storedResponses[0], interruptingResponse1)
        
        result = checkResponseSegment(interruptingResponse2)
        switch result {
        case .success(let complete):
            XCTAssertEqual(complete, expectedInterruptingResponse)
        case .failure(_):
            XCTAssert(false)
        }
        XCTAssertTrue(storedResponses.isEmpty)
    }
    
    func testCheckResponseSegmentCounterRollover() {
        let uint8Array: [UInt8] = stride(from: 1, through: 30, by: 1).map { UInt8($0) }
        let expectedResponse = Data(uint8Array)
        let segmentCountInitialValue: UInt8 = SegmentationHeader.maxCounterValue
        var responseSegment1 = Data(SegmentationHeader.firstPart.rawValue | (segmentCountInitialValue << 2))
        responseSegment1.append(contentsOf: stride(from: 1, through: 19, by: 1).map { UInt8($0) })
        
        var responseSegment2 = Data(SegmentationHeader.lastPart.rawValue | ((0) << 2)) // 0 is the rollover value
        responseSegment2.append(contentsOf: stride(from: 20, through: 30, by: 1).map { UInt8($0) })

        var result = checkResponseSegment(responseSegment1)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            if error != .partialResponse {
                XCTAssert(false)
            }
        }
        XCTAssertEqual(storedResponses[0], responseSegment1)
        
        result = checkResponseSegment(responseSegment2)
        switch result {
        case .success(let complete):
            XCTAssertEqual(complete, expectedResponse)
        case .failure(_):
            XCTAssert(false)
        }
        XCTAssertTrue(storedResponses.isEmpty)
    }
    
    func testResetSegmentCounter() {
        segmentCounter = 100
        resetSegmentCounter()
        XCTAssertEqual(segmentCounter, 0)
    }
}
