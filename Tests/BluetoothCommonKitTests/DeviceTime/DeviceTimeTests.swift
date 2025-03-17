//
//  DeviceTimeTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

final class DeviceTimeTests: XCTestCase {

    private var deviceTime: DeviceTime!
    
    override func setUp() {
        deviceTime = DeviceTime()
    }
    
    func testDTStatusFlag() {
        XCTAssertTrue(DTStatusFlag(rawValue: 1).contains(.timeFault))
        XCTAssertTrue(DTStatusFlag(rawValue: 2).contains(.utcAligned))
        XCTAssertTrue(DTStatusFlag(rawValue: 4).contains(.qualifiedLocalTimeSynchronized))
        XCTAssertTrue(DTStatusFlag(rawValue: 8).contains(.proposeTimeUpdateRequest))
        XCTAssertTrue(DTStatusFlag(rawValue: 16).contains(.epochYear2000))
        XCTAssertTrue(DTStatusFlag(rawValue: 32).contains(.nonLoggedTimeChangeActive))
        XCTAssertTrue(DTStatusFlag(rawValue: 64).contains(.logConsolidationActive))
    }

    func testDeviceTimeHandleData() {
        let timeZone = TimeZone(secondsFromGMT: Int(.hours(-4).seconds))!
        let timeZone15MinIncrements = Int8(timeZone.secondsFromGMT() / (60 * 15))
        let dstOffset = timeZone.dstOffset
        let statusFlags = DTStatusFlag([.epochYear2000, .utcAligned])
        let baseTime = Date().baseTimeInSecondsFromEpoch2000
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let expectedDeviceTime = calendar.date(byAdding: DateComponents(second: Int(baseTime)), to: Date.epoch2000)

        var response = Data(baseTime)
        response.append(timeZone15MinIncrements)
        response.append(dstOffset.rawValue)
        response.append(statusFlags.rawValue)
        response = response.appendingCRCPrefix()

        let (result, _) = deviceTime.handleData(response)
        switch result {
        case .success(let deviceTime):
            XCTAssertNotNil(deviceTime)
            XCTAssertEqual(deviceTime, expectedDeviceTime)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testDeviceTimeHandleDataInvalidFormat() {
        let response = Data(UInt64(123456789))
        let (result, _) = deviceTime.handleData(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        }
    }

    func testDeviceTimeHandleDataInvalidCRC() {
        let timeZone = TimeZone.current
        let timeZone15MinIncrements = Int8(timeZone.secondsFromGMT() / (60 * 15))
        let dstOffset = timeZone.dstOffset
        let statusFlags = DTStatusFlag([.epochYear2000, .utcAligned])
        let baseTime = Date().baseTimeInSecondsFromEpoch2000

        var response = Data(baseTime)
        response.append(timeZone15MinIncrements)
        response.append(dstOffset.rawValue)
        response.append(statusFlags.rawValue)
        response.append(UInt16(0))

        let (result, _) = deviceTime.handleData(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .invalidCRC)
        }
    }

    func testDeviceTimeHandleDataNilDateTimeFault() {
        let timeZone = TimeZone.current
        let timeZone15MinIncrements = Int8(timeZone.secondsFromGMT() / (60 * 15))
        let dstOffset = timeZone.dstOffset
        let statusFlags = DTStatusFlag([.timeFault, .epochYear2000, .utcAligned])
        let baseTime = Date().baseTimeInSecondsFromEpoch2000

        var response = Data(baseTime)
        response.append(timeZone15MinIncrements)
        response.append(dstOffset.rawValue)
        response.append(statusFlags.rawValue)
        response = response.appendingCRCPrefix()

        let (result, _) = deviceTime.handleData(response)
        switch result {
        case .success(let date):
            XCTAssertNil(date)
        case .failure(_):
            XCTAssert(false)
        }
    }
}
