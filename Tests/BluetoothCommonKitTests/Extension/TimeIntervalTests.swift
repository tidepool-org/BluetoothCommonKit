//
//  TimeIntervalTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class TimeIntervalTests: XCTestCase {

    func testDays() {
        let expected1Day: TimeInterval = 60*60*24
        XCTAssertEqual(expected1Day, TimeInterval.days(1))
        XCTAssertEqual(expected1Day, TimeInterval(days: 1))
        XCTAssertEqual(expected1Day.days, 1)
        
        let expected1AndHalfDays: TimeInterval = 60*60*24*1.5
        XCTAssertEqual(expected1AndHalfDays, TimeInterval.days(1.5))
        XCTAssertEqual(expected1AndHalfDays, TimeInterval(days: 1.5))
        XCTAssertEqual(expected1AndHalfDays.days, 1.5)
    }

    func testHours() {
        let expected1Hour: TimeInterval = 60*60
        XCTAssertEqual(expected1Hour, TimeInterval.hours(1))
        XCTAssertEqual(expected1Hour, TimeInterval(hours: 1))
        XCTAssertEqual(expected1Hour.hours, 1)
        
        let expected1AndHalfHours: TimeInterval = 60*60*1.5
        XCTAssertEqual(expected1AndHalfHours, TimeInterval.hours(1.5))
        XCTAssertEqual(expected1AndHalfHours, TimeInterval(hours: 1.5))
        XCTAssertEqual(expected1AndHalfHours.hours, 1.5)
    }
    
    func testMinutes() {
        let expected1Minute: TimeInterval = 60
        XCTAssertEqual(expected1Minute, TimeInterval.minutes(1))
        XCTAssertEqual(expected1Minute, TimeInterval(minutes: 1))
        XCTAssertEqual(expected1Minute.minutes, 1)
        
        let expected1AndHalfMinutes: TimeInterval = 60*1.5
        XCTAssertEqual(expected1AndHalfMinutes, TimeInterval.minutes(1.5))
        XCTAssertEqual(expected1AndHalfMinutes, TimeInterval(minutes: 1.5))
        XCTAssertEqual(expected1AndHalfMinutes.minutes, 1.5)
    }
    
    func testSeconds() {
        let expected1Second: TimeInterval = 1
        XCTAssertEqual(expected1Second, TimeInterval.seconds(1))
        XCTAssertEqual(expected1Second, TimeInterval(seconds: 1))
        XCTAssertEqual(expected1Second.seconds, 1)
        
        let expected1AndHalfSeconds: TimeInterval = 1.5
        XCTAssertEqual(expected1AndHalfSeconds, TimeInterval.seconds(1.5))
        XCTAssertEqual(expected1AndHalfSeconds, TimeInterval(seconds: 1.5))
        XCTAssertEqual(expected1AndHalfSeconds.seconds, 1.5)
    }
    
    func testMilliseconds() {
        let expected1Millisecond: TimeInterval = 0.001
        XCTAssertEqual(expected1Millisecond, TimeInterval.milliseconds(1))
        XCTAssertEqual(expected1Millisecond, TimeInterval(milliseconds: 1))
        XCTAssertEqual(expected1Millisecond.milliseconds, 1)
        
        let expected1AndHalfMilliseconds: TimeInterval = 0.0015
        XCTAssertEqual(expected1AndHalfMilliseconds, TimeInterval.milliseconds(1.5))
        XCTAssertEqual(expected1AndHalfMilliseconds, TimeInterval(milliseconds: 1.5))
        XCTAssertEqual(expected1AndHalfMilliseconds.milliseconds, 1.5)
    }
    
    func testHundredthsOfMilliseconds() {
        let expected1HundredthOfMillisecond: TimeInterval = 0.00001
        XCTAssertEqual(expected1HundredthOfMillisecond, TimeInterval.hundredthsOfMilliseconds(1))
        XCTAssertEqual(expected1HundredthOfMillisecond, TimeInterval(hundredthsOfMilliseconds: 1))
        XCTAssertEqual(expected1HundredthOfMillisecond.hundredthsOfMilliseconds, 1)
        
        let expected1AndHalfHundredthsOfMillisecond: TimeInterval = 0.000015
        XCTAssertEqual(expected1AndHalfHundredthsOfMillisecond, TimeInterval.hundredthsOfMilliseconds(1.5))
        XCTAssertEqual(expected1AndHalfHundredthsOfMillisecond, TimeInterval(hundredthsOfMilliseconds: 1.5))
        XCTAssertEqual(expected1AndHalfHundredthsOfMillisecond.hundredthsOfMilliseconds, 1.5)
    }
}
