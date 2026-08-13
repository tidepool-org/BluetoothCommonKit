//
//  KeyDescriptorTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class KeyDescriptorTests: XCTestCase {
    func testKeyType() {
        XCTAssertEqual(KeyType(rawValue: 0x00), KeyType.oobKey)
        XCTAssertEqual(KeyType(rawValue: 0x01), KeyType.ecdh)
        XCTAssertEqual(KeyType(rawValue: 0x02), KeyType.kdfKeyExchange)
        XCTAssertEqual(KeyType(rawValue: 0x03), KeyType.aesCMAC)
        XCTAssertEqual(KeyType(rawValue: 0x04), KeyType.aesCCM)
        XCTAssertEqual(KeyType(rawValue: 0x05), KeyType.aesEAX)
        XCTAssertEqual(KeyType(rawValue: 0x06), KeyType.aesGCM)
        XCTAssertEqual(KeyType(rawValue: 0x07), KeyType.aesGMAC)
        XCTAssertNil(KeyType(rawValue: 0x08))
    }
    
    func testEllipticCurve() {
        XCTAssertEqual(EllipticCurve(rawValue: 0x00), EllipticCurve.p256)
        XCTAssertEqual(EllipticCurve(rawValue: 0x01), EllipticCurve.p384)
        XCTAssertEqual(EllipticCurve(rawValue: 0x02), EllipticCurve.p521)
        XCTAssertEqual(EllipticCurve(rawValue: 0x03), EllipticCurve.curve25519)
        XCTAssertNil(EllipticCurve(rawValue: 0x07))
    }
    
    func testOOBMethod() {
        XCTAssertEqual(OOBMethod(rawValue: 0x00), OOBMethod.manufacturer)
        XCTAssertEqual(OOBMethod(rawValue: 0x01), OOBMethod.uri)
        XCTAssertEqual(OOBMethod(rawValue: 0x02), OOBMethod.machineReadableCode2D)
        XCTAssertEqual(OOBMethod(rawValue: 0x03), OOBMethod.barCode)
        XCTAssertEqual(OOBMethod(rawValue: 0x04), OOBMethod.nfc)
        XCTAssertNil(OOBMethod(rawValue: 0x05))
    }
    
    func testMessageType() {
        XCTAssertEqual(MessageType(rawValue: 0x00), MessageType.profileDefinedParameter)
        XCTAssertEqual(MessageType(rawValue: 0x01), MessageType.protectedResourceValue)
        XCTAssertNil(MessageType(rawValue: 0x02))
    }
    
    func testNonceType() {
        XCTAssertEqual(NonceType(rawValue: 0x00), NonceType.profileDefinedParameter)
        XCTAssertEqual(NonceType(rawValue: 0x01), NonceType.sequenceNumberEvenOdd)
        XCTAssertEqual(NonceType(rawValue: 0x02), NonceType.sequenceNumberDifferentFixedParts)
        XCTAssertNil(NonceType(rawValue: 0x03))
    }
    
    func testGetKeyDescriptorRequest() {
        // `request` gained a key-ID filter operand (#22): opcode followed by the
        // match-all filter.
        let request = KeyDescriptor.request()
        var expected = Data([ACControlPointOpcode.getKeyDescriptor.rawValue])
        expected.append(Data(KeyDescriptor.noFilter))
        XCTAssertEqual(request, expected)
    }
    
    func testKeyDescriptorResponse() {
        // key record 1
        let keyRecord1TypeValue: UInt16 = 1
        let keyRecord1DataSize: UInt8 = 4
        let keyRecord1ServerKeyFormat: KeyFormat = .plain
        let keyRecord1ClientKeyFormat: KeyFormat = .plain
        let KeyRecord1EllipticCurve: EllipticCurve = .p256
        let keyRecord1KeyDerivationFunction: KeyDerivationFunction = .hkdfSHA256
        
        // key record 2
        let keyRecord2TypeValue: UInt16 = 2
        let keyRecord2DataSize: UInt8 = 11
        let keyRecord2MACSize: UInt8 = 8
        let keyRecord2NonceSizeVariable: UInt8 = 8
        let keyRecord2NonceSizeFixed: UInt8 = 4
        let keyRecord2IVFixedField: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        
        // key record 3
        let keyRecord3TypeValue: UInt16 = 3
        let keyRecord3DataSize: UInt8 = 11
        let keyRecord3MACSize: UInt8 = 8
        let keyRecord3NonceSizeVariable: UInt8 = 6
        let keyRecord3NonceSizeFixed: UInt8 = 6
        let keyRecord3IVFixedField: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        
        // Key Record 4
        let keyRecord4TypeValue: UInt16 = 4
        let keyRecord4DataSize: UInt8 = 3
        let keyRecord4KeyDerivationFunction: KeyDerivationFunction = .hkdfSHA256
                
        var response = Data()
        response.append(ACControlPointOpcode.keyDescriptorResponse.rawValue)
        response.append(KeyType.ecdh.rawValue)
        response.append(keyRecord1TypeValue)
        response.append(keyRecord1DataSize)
        response.append(keyRecord1ServerKeyFormat.rawValue)
        response.append(keyRecord1ClientKeyFormat.rawValue)
        response.append(KeyRecord1EllipticCurve.rawValue)
        response.append(keyRecord1KeyDerivationFunction.rawValue)
        response.append(KeyType.aesGCM.rawValue)
        response.append(keyRecord2TypeValue)
        response.append(keyRecord2DataSize)
        response.append(keyRecord1TypeValue)
        response.append(MessageType.protectedResourceValue.rawValue)
        response.append(keyRecord2MACSize)
        response.append(NonceType.sequenceNumberEvenOdd.rawValue)
        response.append(keyRecord2NonceSizeVariable)
        response.append(keyRecord2NonceSizeFixed)
        response.append(contentsOf: keyRecord2IVFixedField)
        response.append(KeyType.aesGMAC.rawValue)
        response.append(keyRecord3TypeValue)
        response.append(keyRecord3DataSize)
        response.append(keyRecord1TypeValue)
        response.append(MessageType.protectedResourceValue.rawValue)
        response.append(keyRecord3MACSize)
        response.append(NonceType.sequenceNumberEvenOdd.rawValue)
        response.append(keyRecord3NonceSizeVariable)
        response.append(keyRecord3NonceSizeFixed)
        response.append(contentsOf: keyRecord3IVFixedField)
        response.append(KeyType.kdfKeyExchange.rawValue)
        response.append(keyRecord4TypeValue)
        response.append(keyRecord4DataSize)
        response.append(keyRecord1TypeValue)
        response.append(keyRecord4KeyDerivationFunction.rawValue)
        
        let securityManager = SecurityManager()
        let result = KeyDescriptor.handleResponse(response, securityManager: securityManager)
        switch result {
        case .success:
            XCTAssertEqual(securityManager.configuration.ecdhKeyID, keyRecord1TypeValue)
        case .failure(_):
            XCTAssert(false)
        }
    }
}
