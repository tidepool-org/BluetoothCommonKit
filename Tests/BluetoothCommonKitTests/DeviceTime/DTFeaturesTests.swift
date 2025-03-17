//
//  DTFeaturesTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

final class DTFeaturesTests: XCTestCase {
    private var testE2EProtection = TestE2EProtection()

    func testDeviceTimeFeatureFlag() {
        let flags: UInt16 = 0xffff
        let featureFlags = DTFeatureFlag(rawValue: flags)
        XCTAssertTrue(featureFlags.contains(.supportedE2ECRC))
        XCTAssertTrue(featureFlags.contains(.supportedTimeChangeLogging))
        XCTAssertTrue(featureFlags.contains(.supportedBaseTimeSecondFractions))
        XCTAssertTrue(featureFlags.contains(.supportedTimeDateDisplayToUser))
        XCTAssertTrue(featureFlags.contains(.supportedDisplayedFormats))
        XCTAssertTrue(featureFlags.contains(.supportedDisplayedFormatsChangeable))
        XCTAssertTrue(featureFlags.contains(.supportedSeparateUserTimeline))
        XCTAssertTrue(featureFlags.contains(.supportedAuthorizationRequired))
        XCTAssertTrue(featureFlags.contains(.supportedRTCDriftTracking))
        XCTAssertTrue(featureFlags.contains(.supportedEpochYear1900))
        XCTAssertTrue(featureFlags.contains(.supportedEpochYear2000))
        XCTAssertTrue(featureFlags.contains(.supportedProposeNonLoggedTimeAdjustmentLimit))
        XCTAssertTrue(featureFlags.contains(.supportedRetrieveActiveTimeAdjustments))
    }

    func testHandleInsulinDeliveryStatusData() {
        let featureFlags = DTFeatureFlag([.supportedE2ECRC, .supportedEpochYear2000])
        let data = Data(featureFlags.rawValue)
        let dataWithE2EProtection = data.appendingCRCPrefix()

        let result = DTFeatures.handleData(dataWithE2EProtection)
        switch result {
        case .failure(_):
            XCTAssert(false)
        case .success(let resultFlags):
            XCTAssertEqual(resultFlags, featureFlags)
        }
    }

    func testHandleInsulinDeliveryStatusDataInvalidFormat() {
        let featureFlags = DTFeatureFlag([.supportedE2ECRC, .supportedEpochYear2000])
        var data = Data(featureFlags.rawValue)
        let result = DTFeatures.handleData(data)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        default:
            XCTAssert(false)
        }
    }

    func testHandleInsulinDeliveryStatusDataInvalidCRC() {
        let featureFlags = DTFeatureFlag([.supportedE2ECRC, .supportedEpochYear2000])
        var data = Data(UInt16(0))
        data.append(featureFlags.rawValue)

        let result = DTFeatures.handleData(data)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidCRC)
        default:
            XCTAssert(false)
        }
    }
}
