//
//  CorrelatedControlPointTests.swift
//  BluetoothCommonKit
//
//  Created by LoopKit Authors on 2026-09-25.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class CorrelatedControlPointTests: XCTestCase {

    private let testControlPoint = TestCorrelatedControlPoint()

    func testRequestLeavesQueueWhenDequeued() {
        XCTAssertFalse(testControlPoint.hasRequestToSend)
        testControlPoint.appendToRequestQueue(Data(hex: "0101"), completion: nil)
        testControlPoint.appendToRequestQueue(Data(hex: "0202"), completion: nil)
        XCTAssertTrue(testControlPoint.hasRequestToSend)

        XCTAssertEqual(testControlPoint.dequeueNextRequest()?.request, Data(hex: "0101"))
        XCTAssertEqual(testControlPoint.lockedRequestQueue.value.count, 1)
        XCTAssertEqual(testControlPoint.dequeueNextRequest()?.request, Data(hex: "0202"))
        XCTAssertNil(testControlPoint.dequeueNextRequest())
        XCTAssertFalse(testControlPoint.hasRequestToSend)
    }

    func testDrainRequestQueue() {
        testControlPoint.appendToRequestQueue(Data(hex: "0101"), completion: { _ in })
        testControlPoint.appendToRequestQueue(Data(hex: "0202"), completion: nil)

        let drainedRequests = testControlPoint.drainRequestQueue()
        XCTAssertEqual(drainedRequests.map(\.request), [Data(hex: "0101"), Data(hex: "0202")])
        XCTAssertNotNil(drainedRequests.first?.completion)
        XCTAssertNil(drainedRequests.last?.completion)
        XCTAssertFalse(testControlPoint.hasRequestToSend)
        XCTAssertTrue(testControlPoint.drainRequestQueue().isEmpty)
    }

    func testConcurrentDequeuesReturnEachRequestOnce() {
        let requestCount = 1000
        for index in 0..<requestCount {
            testControlPoint.appendToRequestQueue(Data(UInt16(index)), completion: nil)
        }

        nonisolated(unsafe) let controlPoint = testControlPoint
        nonisolated(unsafe) let dequeuedRequests = Locked<[Data]>([])
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            while let nextRequest = controlPoint.dequeueNextRequest() {
                dequeuedRequests.mutate { $0.append(nextRequest.request) }
            }
        }

        XCTAssertEqual(dequeuedRequests.value.count, requestCount)
        XCTAssertEqual(Set(dequeuedRequests.value).count, requestCount)
    }
}

private class TestCorrelatedControlPoint: CorrelatedControlPoint {
    typealias Completion = (Data) -> Void
    typealias Response = Data

    let lockedRequestQueue = Locked<[(request: Data, completion: Completion?)]>([])

    func procedureIDForRequest(_ request: Data) -> ProcedureID {
        "TestCorrelatedControlPoint.TestRequestProcedureID"
    }

    func result(forResponse response: Data, to request: Data) -> Data? {
        response.first == request.first ? response : nil
    }
}
