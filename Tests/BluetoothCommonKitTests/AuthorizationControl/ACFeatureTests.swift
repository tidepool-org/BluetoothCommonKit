//
//  ACFeatureTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class ACFeatureTests: XCTestCase {

    func testFeatureFlag() {
        let featureFlagRawValue: UInt32 = 0x001E78AE
        let featureFlag = FeaturesFlag(rawValue: featureFlagRawValue)
        XCTAssertFalse(featureFlag.contains(.setInformationSecurityControlsAvailabilitySupported))
        XCTAssertTrue(featureFlag.contains(.descriptorsSupported))
        XCTAssertTrue(featureFlag.contains(.multipleRestrictionMapsSupported))
        XCTAssertTrue(featureFlag.contains(.resourceHandleToUUIDMapSupported))
        XCTAssertFalse(featureFlag.contains(.initiatePairingSupported))
        XCTAssertTrue(featureFlag.contains(.keyExchangeOOBSupported))
        XCTAssertFalse(featureFlag.contains(.keyExchangeECDHSupported))
        XCTAssertTrue(featureFlag.contains(.keyExchangeKDFSupported))
        XCTAssertFalse(featureFlag.contains(.keyURISupported))
        XCTAssertFalse(featureFlag.contains(.invalidateEstablishedSecuritySupported))
        XCTAssertFalse(featureFlag.contains(.attMTUSupported))
        XCTAssertTrue(featureFlag.contains(.protectedResourceWriteSupported))
        XCTAssertTrue(featureFlag.contains(.protectedResourceReadSupported))
        XCTAssertTrue(featureFlag.contains(.protectedResourceNotificationSupported))
        XCTAssertTrue(featureFlag.contains(.protectedResourceIndicationSupported))
        XCTAssertFalse(featureFlag.contains(.keyFormatServerManufacturerSpecificSupported))
        XCTAssertFalse(featureFlag.contains(.keyFormatClientManufacturerSpecificSupported))
        XCTAssertTrue(featureFlag.contains(.keyFormatServerUncompressedPlainSupported))
        XCTAssertTrue(featureFlag.contains(.keyFormatClientUncompressedPlainSupported))
        XCTAssertTrue(featureFlag.contains(.keyFormatServerX509Supported))
        XCTAssertTrue(featureFlag.contains(.keyFormatClientX509Supported))
    }
    
    func testQualityOfProtection() {
        let qualityOfProtectionRawValue: UInt16 = 0x002B
        let qualityOfProtection = QualityOfProtection(rawValue: qualityOfProtectionRawValue)
        XCTAssertTrue(qualityOfProtection.contains(.confidentiality))
        XCTAssertTrue(qualityOfProtection.contains(.integrity))
        XCTAssertFalse(qualityOfProtection.contains(.authentication))
        XCTAssertTrue(qualityOfProtection.contains(.authorization))
        XCTAssertFalse(qualityOfProtection.contains(.nonRepudiation))
        XCTAssertTrue(qualityOfProtection.contains(.manufactureSpecificControlsUsed))
    }
        
    func testOOBKeyExchangeCapability() {
        let oobCapabilityRawValue: UInt16 = 0x087C
        let oobCapability = OOBCapability(rawValue: oobCapabilityRawValue)
        XCTAssertFalse(oobCapability.contains(.other))
        XCTAssertFalse(oobCapability.contains(.uri))
        XCTAssertTrue(oobCapability.contains(.machineReadableCode2D))
        XCTAssertTrue(oobCapability.contains(.barCode))
        XCTAssertTrue(oobCapability.contains(.nfc))
        XCTAssertTrue(oobCapability.contains(.number))
        XCTAssertTrue(oobCapability.contains(.string))
        XCTAssertFalse(oobCapability.contains(.certificateX509))
        XCTAssertTrue(oobCapability.contains(.onBox))
        XCTAssertFalse(oobCapability.contains(.insideBox))
        XCTAssertFalse(oobCapability.contains(.onPaper))
        XCTAssertFalse(oobCapability.contains(.insideManual))
        XCTAssertFalse(oobCapability.contains(.onDevice))
    }
    
    func testConfirmationInputCapability() {
        let confirmationInputCapabilityRawValue: UInt16 = 0x0004
        let confirmationInputCapability = ConfirmationInputCapability(rawValue: confirmationInputCapabilityRawValue)
        XCTAssertFalse(confirmationInputCapability.contains(.push))
        XCTAssertTrue(confirmationInputCapability.contains(.inputNumeric))
    }
    
    func testConfirmationOutputCapability() {
        let confirmationOutputCapabilityRawValue: UInt16 = 0x0001
        let confirmationOutputCapability = ConfirmationOutputCapability(rawValue: confirmationOutputCapabilityRawValue)
        XCTAssertTrue(confirmationOutputCapability.contains(.beep))
        XCTAssertFalse(confirmationOutputCapability.contains(.outputNumeric))
    }
    
    func testGetACSFeatureRequest() {
        let request = ACFeatureDataHandler.request
        XCTAssertEqual(request, Data([ACControlPointOpcode.getACSFeature.rawValue]))
    }
    
    func testFeatureResponseValid() {
        let expectedFeatureFlags: FeaturesFlag = [.descriptorsSupported, .keyExchangeECDHSupported, .multipleRestrictionMapsSupported]
        let expectedQualityOfProtection: QualityOfProtection = [.authentication, .manufactureSpecificControlsUsed]
        let expectedOOBKeyExchangeCapability: OOBCapability = [.barCode]
        let expectedOOBStaticNumberExchangeCapability: OOBCapability = [.insideManual]
        let expectedConfirmationInputSize: UInt32 = 4
        let expectedConfirmationInputCapability: ConfirmationInputCapability = [.inputNumeric]
        let expectedConfirmationOutputSize: UInt32 = 10
        let expectedConfirmationOutputCapability: ConfirmationOutputCapability = [.beep]
        
        var expectedFeatureResponse = Data([ACControlPointOpcode.acsFeatureResponse.rawValue])
        expectedFeatureResponse.append(expectedFeatureFlags.rawValue)
        expectedFeatureResponse.append(expectedQualityOfProtection.rawValue)
        expectedFeatureResponse.append(expectedOOBKeyExchangeCapability.rawValue)
        expectedFeatureResponse.append(expectedOOBStaticNumberExchangeCapability.rawValue)
        expectedFeatureResponse.append(expectedConfirmationInputSize)
        expectedFeatureResponse.append(expectedConfirmationInputCapability.rawValue)
        expectedFeatureResponse.append(expectedConfirmationOutputSize)
        expectedFeatureResponse.append(expectedConfirmationOutputCapability.rawValue)
        
        let result = ACFeatureDataHandler.handleResponse(expectedFeatureResponse)
        switch result {
        case .success(let features):
            XCTAssertEqual(expectedFeatureFlags, features)
        case .failure(_):
            XCTAssert(false)
        }
    }
    
    func testFeatureResponseInvalidFormat() {
        let notEnoughData = Data([0xFF, 0xEF, 0x45])
        let result = ACFeatureDataHandler.handleResponse(notEnoughData)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        }
    }
}
