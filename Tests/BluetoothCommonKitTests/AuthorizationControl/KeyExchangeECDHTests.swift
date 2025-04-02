//
//  KeyExchangeECDHTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-04-01.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CryptoKit
@testable import BluetoothCommonKit

class KeyExchangeECDHTests: XCTestCase {
    
    private var securityManagerTestingDelegate = SecurityManagerTestingDelegate()
        
    func testStartKeyConfirmationMethod() {
        XCTAssertEqual(StartKeyExchangeConfirmationMethod(rawValue: 0x00), StartKeyExchangeConfirmationMethod.noMethod)
        XCTAssertEqual(StartKeyExchangeConfirmationMethod(rawValue: 0x01), StartKeyExchangeConfirmationMethod.oobNumberOutput)
        XCTAssertEqual(StartKeyExchangeConfirmationMethod(rawValue: 0x02), StartKeyExchangeConfirmationMethod.oobNumberInput)
        XCTAssertEqual(StartKeyExchangeConfirmationMethod(rawValue: 0x03), StartKeyExchangeConfirmationMethod.oobNumberStatic)
        XCTAssertNil(StartKeyExchangeConfirmationMethod(rawValue: 0x04))
    }
    
    func testStartKeyConfirmationAction() {
        XCTAssertEqual(StartKeyExchangeConfirmationAction(rawValue: 0x00), StartKeyExchangeConfirmationAction.push)
        XCTAssertEqual(StartKeyExchangeConfirmationAction(rawValue: 0x01), StartKeyExchangeConfirmationAction.beep)
        XCTAssertEqual(StartKeyExchangeConfirmationAction(rawValue: 0x02), StartKeyExchangeConfirmationAction.inputNumeric)
        XCTAssertEqual(StartKeyExchangeConfirmationAction(rawValue: 0x03), StartKeyExchangeConfirmationAction.outputNumeric)
        XCTAssertEqual(StartKeyExchangeConfirmationAction(rawValue: 0xff), StartKeyExchangeConfirmationAction.staticAction)
        XCTAssertNil(StartKeyExchangeConfirmationAction(rawValue: 0x04))
    }
    
    func testKeyExchangeResponseCode() {
        XCTAssertEqual(KeyExchangeResponseCode(rawValue: 0x00), KeyExchangeResponseCode.successful)
        XCTAssertEqual(KeyExchangeResponseCode(rawValue: 0x01), KeyExchangeResponseCode.failed)
        XCTAssertNil(KeyExchangeResponseCode(rawValue: 0x02))
    }
    
    func testStartKeyExchangeRequest() {
        let securityManager = SecurityManager()
        let keyID: KeyID = 1
        securityManager.configuration.ecdhKeyID = keyID
        let confirmationMethod = StartKeyExchangeConfirmationMethod.oobNumberStatic
        let confirmationAction = StartKeyExchangeConfirmationAction.staticAction
        
        let request = KeyExchangeECDH.startKeyExchange(securityManager: securityManager)
        
        XCTAssertEqual(request.count, 5)
        var index = 0
        XCTAssertEqual(request[index], ACControlPointOpcode.startKeyExchange.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(KeyID.self), keyID)
        index += 2
        XCTAssertEqual(request[index], confirmationMethod.rawValue)
        index += 1
        XCTAssertEqual(request[index], confirmationAction.rawValue)
    }
    
    func testECDHWithNISTTestVectors() {
        // NIST Test Vector
        // [P-256]
        // COUNT = 4
        // QCAVSx = 41192d2813e79561e6a1d6f53c8bc1a433a199c835e141b05a74a97b0faeb922
        // QCAVSy = 1af98cc45e98a7e041b01cf35f462b7562281351c8ebf3ffa02e33a0722a1328
        // dIUT = 59137e38152350b195c9718d39673d519838055ad908dd4757152fd8255c09bf
        // QIUTx = a8c5fdce8b62c5ada598f141adb3b26cf254c280b2857a63d2ad783a73115f6b
        // QIUTy = 806e1aafec4af80a0d786b3de45375b517a7e5b51ffb2c356537c9e6ef227d4a
        // ZIUT = 19d44c8d63e8e8dd12c22a87b8cd4ece27acdde04dbf47f7f27537a6999a8e62
        
        var error: Unmanaged<CFError>?
        let alicePublicKeyDataX = Data(hexadecimalString: "41192d2813e79561e6a1d6f53c8bc1a433a199c835e141b05a74a97b0faeb922")!
        let alicePublicKeyDataY = Data(hexadecimalString: "1af98cc45e98a7e041b01cf35f462b7562281351c8ebf3ffa02e33a0722a1328")!
        let bobPublicKeyDataX = Data(hexadecimalString: "a8c5fdce8b62c5ada598f141adb3b26cf254c280b2857a63d2ad783a73115f6b")!
        let bobPublicKeyDataY = Data(hexadecimalString: "806e1aafec4af80a0d786b3de45375b517a7e5b51ffb2c356537c9e6ef227d4a")!
        let bobPrivateKeyData = Data(hexadecimalString: "59137e38152350b195c9718d39673d519838055ad908dd4757152fd8255c09bf")!
        let expectedSharedSecret = Data(hexadecimalString: "19d44c8d63e8e8dd12c22a87b8cd4ece27acdde04dbf47f7f27537a6999a8e62")!
        
        let publicAttributes = [kSecAttrKeySizeInBits: 256,
                                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                                kSecAttrKeyClass: kSecAttrKeyClassPublic,
                                kSecPublicKeyAttrs: [kSecAttrIsPermanent: false]] as [CFString : Any] as CFDictionary
        
        let privateAttributes = [kSecAttrKeySizeInBits: 256,
                                 kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                                 kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                                 kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as [CFString : Any] as CFDictionary
        
        var tempKeyData = alicePublicKeyDataX
        tempKeyData.append(alicePublicKeyDataY)
        tempKeyData.insert(0x04, at: 0)
        
        let alicePublicKeyP256 = SecKeyCreateWithData(NSData(data: tempKeyData) as CFData, publicAttributes, &error)
        
        guard error == nil,
            let alicePublicKey = alicePublicKeyP256 else
        {
            XCTAssert(false, "alice public key creation failed \(String(describing: error))")
            return
        }
        
        tempKeyData = bobPublicKeyDataX
        tempKeyData.append(bobPublicKeyDataY)
        tempKeyData.append(bobPrivateKeyData)
        tempKeyData.insert(0x04, at: 0)
        
        let bobPrivateKeyP256 = SecKeyCreateWithData(NSData(data: tempKeyData) as CFData, privateAttributes, &error)
        guard error == nil,
            let bobPrivateKey = bobPrivateKeyP256 else
        {
            XCTAssert(false, "bob private key creation failed \(String(describing: error))")
            return
        }
        
        let dict = [:] as CFDictionary
        let sharedKeyDataP256 = SecKeyCopyKeyExchangeResult(bobPrivateKey,
                                                            SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                            alicePublicKey,
                                                            dict,
                                                            &error)
        guard error == nil,
            let sharedKeyData = sharedKeyDataP256 else
        {
            XCTAssert(false, "shared key data generation failed \(String(describing: error))")
            return
        }
        
        XCTAssertEqual(expectedSharedSecret, (sharedKeyData as Data));
    }

    func testKeyExchangeECDHCertificateRequest() {
        let securityManager = SecurityManager()
        let certificationData = Data(hexadecimalString: "1234567890abcdef")!
        let certificateSize = certificationData.count
        securityManager.configuration.ellipticCurve = .p256
        let keyID: KeyID = 1
        securityManager.configuration.ecdhKeyID = keyID

        let request = KeyExchangeECDH.ecdhRequestCertificate(securityManager: securityManager, certificateData: certificationData)
        XCTAssertNotNil(request)

        XCTAssertEqual(request.count, certificateSize+5)
        var index = 0
        XCTAssertEqual(request[index], ACControlPointOpcode.keyExchangeECDH.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(KeyID.self), keyID)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(certificateSize))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+Int(certificateSize)), certificationData)
    }

    func testKeyExchangeECDHResponseP256() {
        // generate server key
        guard let serverPrivateKeyP256 = generateServerKeyP256(),
            let serverPublicKeyP256 = SecKeyCopyPublicKey(serverPrivateKeyP256) else {
                XCTAssert(false, "error generating the server private key")
                return
        }

        guard var expectedPublicKey = publicKeyXAndY(serverPublicKeyP256) else {
            XCTAssert(false, "error generating the server public key")
            return
        }

        var expectedServerPublicKey = Data()
        expectedServerPublicKey.append(expectedPublicKey.x)
        expectedServerPublicKey.append(expectedPublicKey.y)
        expectedPublicKey.x.reverse()
        expectedPublicKey.y.reverse()

        // calculate the shared key
        let securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        securityManager.configuration.ellipticCurve = .p256
        securityManager.generateKeyPair()
        guard let clientPubicKey = securityManager.getGeneratedPublicKey() else {
            XCTAssert(false, "error generating the client public key")
            return
        }

        let dict = [:] as CFDictionary
        var error: Unmanaged<CFError>?
        let expectedSharedKeyDataP256 = SecKeyCopyKeyExchangeResult(serverPrivateKeyP256,
                                                                    SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                                    clientPubicKey,
                                                                    dict,
                                                                    &error) as Data?
        guard error == nil,
            let expectedSharedKeyData = expectedSharedKeyDataP256 else
        {
            XCTAssert(false, "error calculating the shared key \(error.debugDescription)")
            return
        }

        // create the ECDH response
        let keyID: KeyID = 0x0001
        securityManager.configuration.ecdhKeyID = keyID
        let opcode = ACControlPointOpcode.keyExchangeECDHResponse
        let response = keyExchangeECDHResponse(keyID: keyID, publicKeyX: expectedPublicKey.x, publicKeyY: expectedPublicKey.y)

        let result = KeyExchangeECDH.handleResponse(response, opcode: opcode, securityManager: securityManager)
        switch result {
        case .success:
            XCTAssertEqual(securityManager.getCounterpartPublicKeyAsData(), expectedServerPublicKey)
            XCTAssertEqual(securityManagerTestingDelegate.sharedKeyData, expectedSharedKeyData)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testKeyExchangeECDHConfirmationCodeRequestP256() {
        let securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        securityManager.configuration.ellipticCurve = .p256
        securityManager.generateKeyPair()
        let keyID: KeyID = 1
        securityManager.configuration.ecdhKeyID = keyID
        securityManager.configuration.oobRandomNumber = Data([0x04, 0x03, 0x02, 0x01])

        guard let keyExchangeECDHResponse = keyExchangeECDHResponseP256(keyID: keyID) else {
            return
        }
        let opcode = ACControlPointOpcode.keyExchangeECDHResponse
        let parsedResponse = KeyExchangeECDH.handleResponse(keyExchangeECDHResponse, opcode: opcode, securityManager: securityManager)
        XCTAssertNotNil(parsedResponse)

        let expectedClientConfirmationCode = securityManager.calculateGeneratedConfirmationCodeInLittleEndian()

        let request = KeyExchangeECDH.ecdhConfirmationCodeRequest(securityManager: securityManager)
        XCTAssertNotNil(request)

        if let request = request {
            var index = 0
            XCTAssertEqual(request[index], ACControlPointOpcode.keyExchangeECDHConfirmationCode.rawValue)
            index += 1
            XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(KeyID.self), keyID)
            index += 2
            XCTAssertEqual(request.subdata(in: index..<request.count), expectedClientConfirmationCode)
        }
    }

    func testKeyExchangeECDHConfirmCodeResponseP256() {
        // generate server key and calculate shared secret
        let keyID: KeyID = 0x0001
        guard let keyExchangeECDHResponse = keyExchangeECDHResponseP256(keyID: keyID) else {
            return
        }

        let securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        securityManager.configuration.ellipticCurve = .p256
        securityManager.generateKeyPair()
        securityManager.configuration.ecdhKeyID = keyID
        let oobRandomNumber: UInt32 = 0x0000002A
        securityManager.configuration.oobRandomNumber = Data(oobRandomNumber)
        var opcode = ACControlPointOpcode.keyExchangeECDHResponse
        var result = KeyExchangeECDH.handleResponse(keyExchangeECDHResponse, opcode: opcode, securityManager: securityManager)
        switch result {
        case .failure(_):
            XCTAssert(false)
        default:
            break
        }

        // calculate the confirmation key
        guard let confirmationKey = securityManager.calculateConfirmationKey() else {
            XCTAssert(false, "calculating the confirmation key failed")
            return
        }

        // create the ECDH confirmation code response
        let randomNumberServer = Data((1...32).map { _ in UInt8.random(in: UInt8.min...UInt8.max) })
        let message = randomNumberServer

        let key = SymmetricKey(data: confirmationKey)
        let expectedServerKeyConfirmationCode = Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        // BT transmittion expects little endian byte order
        let expectedServerKeyConfirmationCodeLittleEndian = Data(expectedServerKeyConfirmationCode.reversed())

        opcode = ACControlPointOpcode.keyExchangeECDHConfirmationCodeResponse
        var response = Data()
        response.append(opcode.rawValue)
        response.append(keyID)
        response.append(expectedServerKeyConfirmationCodeLittleEndian)

        result = KeyExchangeECDH.handleResponse(response, opcode: opcode, securityManager: securityManager)
        switch result {
        case .success:
            XCTAssertEqual(securityManager.keyConfirmationCodeReceivedLittleEndian, expectedServerKeyConfirmationCodeLittleEndian)
        case .failure(_):
            XCTAssert(false)
        }
    }
    
    func testKeyExchangeECDHConfirmationRandomNumberRequest() {
        let securityManager = SecurityManager()
        let keyID: KeyID = 1
        securityManager.configuration.ecdhKeyID = keyID
        
        let expectedClientRandomNumber = securityManager.generatedRandomNumberData
        
        let request = KeyExchangeECDH.ecdhConfirmationRandomNumberRequest(securityManager: securityManager)
        XCTAssertNotNil(request)
        
        var index = 0
        XCTAssertEqual(request[index], ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumber.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(KeyID.self), keyID)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...], expectedClientRandomNumber)
    }

    func testKeyExchangeECDHConfirmationRandomNumberResponseP256() {
        // generate server key and calculate shared secret
        let keyID: KeyID = 0x0001
        guard var response = keyExchangeECDHResponseP256(keyID: keyID) else {
            return
        }

        let securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        securityManager.configuration.ellipticCurve = .p256
        securityManager.generateKeyPair()
        securityManager.configuration.ecdhKeyID = keyID
        let oobRandomNumber: UInt32 = 0x0000002A
        securityManager.configuration.oobRandomNumber = Data(bigEndian: oobRandomNumber)
        
        var opcode = ACControlPointOpcode.keyExchangeECDHResponse
        var result = KeyExchangeECDH.handleResponse(response, opcode: opcode, securityManager: securityManager)
        switch result {
        case .failure(_):
            XCTAssert(false)
        default:
            break
        }

        // calculate the confirmation key
        guard let confirmationKey = securityManager.calculateConfirmationKey() else {
            XCTAssert(false, "calculating the confirmation key failed")
            return
        }

        // create the ECDH confirmation code response
        let serverRandomNumberBigEndian: Data = Data((1...32).map { _ in UInt8.random(in: UInt8.min...UInt8.max) })
        let expectedServerRandomNumberLittleEndian = Data(serverRandomNumberBigEndian.reversed())

        opcode = ACControlPointOpcode.keyExchangeECDHConfirmationCodeResponse
        response = keyExchangeECDHConfirmationCodeResponse(confirmationKey: confirmationKey,
                                                           keyID: keyID,
                                                           randomNumberBigEndian: serverRandomNumberBigEndian)
        result = KeyExchangeECDH.handleResponse(response, opcode: opcode, securityManager: securityManager)
        switch result {
        case .failure(_):
            XCTAssert(false)
        default:
            break
        }

        // create the ECDH confirmation random number response
        opcode = ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumberResponse
        response = Data()
        response.append(opcode.rawValue)
        response.append(keyID)
        response.append(expectedServerRandomNumberLittleEndian)

        result = KeyExchangeECDH.handleResponse(response, opcode: opcode, securityManager: securityManager)
        switch result {
        case .failure(let error):
            print("error \(error)")
            XCTAssert(false)
        default:
            break
        }
    }
    
    func testKeyExchangeResponseFailure() {
        let keyID: KeyID = 0x0001
        let securityManager = SecurityManager()
        securityManager.configuration.ecdhKeyID = keyID
        let opcode = ACControlPointOpcode.keyExchangeResponse
        let expectedKeyExchangeResponseCode = KeyExchangeResponseCode.failed
        
        var response = Data()
        response.append(opcode.rawValue)
        response.append(keyID)
        response.append(expectedKeyExchangeResponseCode.rawValue)

        let result = KeyExchangeECDH.handleResponse(response, opcode: opcode, securityManager: securityManager)
        switch result {
        case .success:
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .authenticationFailed)
        }
    }
}

extension KeyExchangeECDHTests {
    func generateServerKeyP256() -> SecKey? {
        generateServerKey(forCurve: .p256)
    }

    func generateServerKey(forCurve curve: EllipticCurve) -> SecKey? {
        // Generate server key
        let attributes: [CFString: Any] = [kSecAttrKeySizeInBits: curve.keySizeInBits,
                                              kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                                              kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]]
        var error: Unmanaged<CFError>?
        let serverPrivateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error)!
        guard error == nil else {
            XCTAssert(false, "error generating server key \(error.debugDescription) for curve \(curve)")
            return nil
        }
        return serverPrivateKey
    }
    
    func publicKeyXAndY(_ publicKey: SecKey) -> (x: Data, y: Data)? {
        // Get X Y representatiob of server public key
        var error: Unmanaged<CFError>?
        let publicKeyRep04XY = SecKeyCopyExternalRepresentation(publicKey, &error)
        guard error == nil else {
            XCTAssert(false, "error getting server public key data \(error.debugDescription)")
            return nil
        }
        let publicKeyData = (publicKeyRep04XY! as Data)
        let xBound = (publicKeyData.count - 1)/2
        let serverPublicKeyX = (publicKeyData as Data).subdata(in: 1..<xBound)
        let serverPublicKeyY = (publicKeyData as Data).subdata(in: xBound..<publicKeyData.count)
        
        return (serverPublicKeyX, serverPublicKeyY)
    }
    
    func keyExchangeECDHResponse(keyID: KeyID, publicKeyX: Data, publicKeyY: Data) -> Data {
        let opcode = ACControlPointOpcode.keyExchangeECDHResponse
        
        var response = Data()
        response.append(opcode.rawValue)
        response.append(keyID)
        response.append(UInt8(publicKeyX.count))
        response.append(contentsOf: publicKeyX)
        response.append(UInt8(publicKeyY.count))
        response.append(contentsOf: publicKeyY)
        
        return response
    }
    
    func keyExchangeECDHResponseP256(keyID: KeyID) -> Data? {
        guard let serverPrivateKeyP256 = generateServerKeyP256(),
            let serverPublicKeyP256 = SecKeyCopyPublicKey(serverPrivateKeyP256) else {
                return nil
        }

        guard var expectedPublicKey = publicKeyXAndY(serverPublicKeyP256) else {
            return nil
        }
        expectedPublicKey.x.reverse()
        expectedPublicKey.y.reverse()

        return keyExchangeECDHResponse(keyID: keyID, publicKeyX: expectedPublicKey.x, publicKeyY: expectedPublicKey.y)
    }
    
    func keyExchangeECDHConfirmationCodeResponse(confirmationKey: Data, keyID: KeyID, randomNumberBigEndian: Data) -> Data {
        let message = randomNumberBigEndian
        
        let key = SymmetricKey(data: confirmationKey)
        var expectedServerKeyConfirmationCode = Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        expectedServerKeyConfirmationCode.reverse()
        
        var response = Data()
        response.append(ACControlPointOpcode.keyExchangeECDHConfirmationCodeResponse.rawValue)
        response.append(keyID)
        response.append(expectedServerKeyConfirmationCode)
        
        return response
    }

    func testSetClientFixedNonce() throws {
        let securityManager = SecurityManager()
        let keyID: KeyID = 1
        securityManager.configuration.algorithmKeyID = keyID
        let request = KeyExchangeECDH.setClientFixedNonce(securityManager: securityManager)

        guard let clientIVFixedField = securityManager.configuration.generatedIVFixedField else {
            XCTAssert(false)
            return
        }
        var expectedRequest = Data(ACControlPointOpcode.setClientNonceFixed.rawValue)
        expectedRequest.append(keyID)
        expectedRequest.append(contentsOf: clientIVFixedField.reversed())

        XCTAssertEqual(request, expectedRequest)
    }
}
