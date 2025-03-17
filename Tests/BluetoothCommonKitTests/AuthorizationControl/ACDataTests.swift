//
//  ACDataTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-04-24.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class ACDataTests: XCTestCase {
    
    private var securityManagerTestingDelegate = SecurityManagerTestingDelegate()

    func testSecureRequestSegmentationAndSecureResponseAssembly() {
        // setup symmetric key
        let attributes256 = [kSecAttrKeySizeInBits: 256,
                             kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                             kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as [CFString : Any] as CFDictionary
        
        var error: Unmanaged<CFError>?
        let serverPrivateKey = SecKeyCreateRandomKey(attributes256, &error)
        let serverPublicKey = SecKeyCopyPublicKey(serverPrivateKey!)
        let serverPublicKeyRep04XY = SecKeyCopyExternalRepresentation(serverPublicKey!, &error)
        let serverPublicKeyData = (serverPublicKeyRep04XY! as Data).subdata(in: 1..<(serverPublicKeyRep04XY! as Data).count)
        
        let securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        securityManager.generateKeyPair()
        securityManager.generateSharedSecret(serverPublicKeyData: serverPublicKeyData)
        
        // create secure request segments
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        let secretMessage = "This is a top secret message!!"
        let request = secretMessage.data(using: .utf8)
        let resourceHandle: ResourceHandle = 1234

        let result = acData.prepareSecureRequestSegments(request, resourceHandle: resourceHandle)
        switch result {
        case .success(let secureRequestSegments):
            // assemble secure response segments
            secureRequestSegments.forEach { secureRequestSegment in
                let result = acData.handleSecureResponse(secureRequestSegment)
                switch result {
                case .success(let resourceResponse):
                    XCTAssertEqual(resourceResponse.resourceHandle, resourceHandle)
                    XCTAssertEqual(resourceResponse.response, request)
                    XCTAssertEqual(String(bytes: resourceResponse.response, encoding: .utf8), secretMessage)
                case .failure(let error):
                    if error != .partialResponse {
                        XCTAssert(false)
                    }
                }
            }
        case .failure(let error):
            print("error \(error)")
            XCTAssert(false)
        }
    }

    func testPrepareSecureRequestErrorMissingKey() {
        let securityManager = SecurityManager()
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        let secretMessage = "This is a top secret message!!"
        let request = secretMessage.data(using: .utf8)
        let resourceHandle: ResourceHandle = 1234
        let result = acData.prepareSecureRequestSegments(request, resourceHandle: resourceHandle)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .missingKey)
        }
    }

    func testHandleResponsePartialResponse() {
        let securityManager = SecurityManager()
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        let segmentationHeader = SegmentationHeader(rawValue: 0b00010101)
        var response = Data(segmentationHeader.rawValue)
        response.append(0x01020304)

        let result = acData.handleSecureResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .partialResponse)
        }
    }

    func testHandleResponseSecurityManagerErrorMissingKey() {
        let securityManager = SecurityManager()
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        let segmentationHeader = SegmentationHeader(rawValue: 0b00010111)
        var response = Data(segmentationHeader.rawValue)
        response.append(0x01020304)

        let result = acData.handleSecureResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            if case .securityManagerError(let securityManagerError) = error {
                XCTAssertEqual(securityManagerError, .missingKey)
            } else {
                XCTAssert(false)
            }
        }
    }

    func testHandleResponseSecurityManagerErrorIncorrectSecurityConfiguration() {
        securityManagerTestingDelegate.sharedKeyData = Data(hexadecimalString: "7fddb57453c241d03efbed3ac44e371c")!
        let securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        let segmentationHeader = SegmentationHeader(rawValue: 0b00010111)
        var response = Data(segmentationHeader.rawValue)
        response.append(0x01020304)
        let result = acData.handleSecureResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            if case .securityManagerError(let securityManagerError) = error {
                XCTAssertEqual(securityManagerError, .incorrectSecurityConfiguration)
            } else {
                XCTAssert(false)
            }
        }
    }

    func testHandleResponseSecurityManagerErrorDecryptionFailed() {
        securityManagerTestingDelegate.sharedKeyData = Data(hexadecimalString: "7fddb57453c241d03efbed3ac44e371c")!
        let inproperlyEncryptedMessage = Data(hexadecimalString: "7fddb57453c241d03efbed3ac44e371c")!
        let securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        let segmentationHeader = SegmentationHeader(rawValue: 0b00010111)
        let securityConfiguration = securityManager.configuration.securityConfigurationID
        var response = Data(segmentationHeader.rawValue)
        response.append(securityConfiguration)
        response.append(inproperlyEncryptedMessage)
        let result = acData.handleSecureResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            if case .securityManagerError(let securityManagerError) = error {
                XCTAssertEqual(securityManagerError, .decryptionFailed)
            } else {
                XCTAssert(false)
            }
        }
    }

    func testUpdateMaxRequestSize() {
        var maxRequestSize = 19
        let securityManager = SecurityManager()
        let acData = ACData(securityManager: securityManager, maxRequestSize: maxRequestSize)
        XCTAssertEqual(acData.maxRequestSize, maxRequestSize)

        maxRequestSize = 256
        acData.updateMaxRequestSize(maxRequestSize)
        XCTAssertEqual(acData.maxRequestSize, maxRequestSize)
    }
}
