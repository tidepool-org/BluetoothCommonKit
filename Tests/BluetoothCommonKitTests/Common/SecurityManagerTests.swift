//
//  SecurityManagerTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CryptoKit
import CryptoSwift
@testable import BluetoothCommonKit

class SecurityManagerTests: XCTestCase {
    
    private var mockKeychainManager: MockKeychainManager!
    private var securityManager: SecurityManager!
    private var securityEstablished = false
    private var updatedConfiguration: SecurityManager.Configuration!
    var sharedKeyData: Data?

    override func setUp() {
        mockKeychainManager = MockKeychainManager()
        securityManager = SecurityManager()
        securityManager.delegate = self
    }

    func testGCMEncryptWithNISTTestVector() {
        // NIST GCM Test Vector
        // from file cgmEncryptExtIV128.rsp
        //
        // [Keylen = 128]
        // [IVlen = 96]
        // [PTlen = 128]
        // [AADlen = 0]
        // [Taglen = 128]
        //
        // Count = 0
        // Key = 7fddb57453c241d03efbed3ac44e371c
        // IV = ee283a3fc75575e33efd4887
        // PT = d5de42b461646c255c87bd2962d3b9a2
        // AAD =
        // CT = 2ccda4a5415cb91e135c2a0f78c9b2fd
        // Tag = b36d1df9b9d5e596f83e8b7f52971cb3

        let keyDataBigEndian = Data([0x7f, 0xdd, 0xb5, 0x74, 0x53, 0xc2, 0x41, 0xd0, 0x3e, 0xfb, 0xed, 0x3a, 0xc4, 0x4e, 0x37, 0x1c])
        let keyDataLittleEndian = Data([0x1c, 0x37, 0x4e, 0xc4, 0x3a, 0xed, 0xfb, 0x3e, 0xd0, 0x41, 0xc2, 0x53, 0x74, 0xb5, 0xdd, 0x7f])
        let ivBigEndian = Data([0xee, 0x28, 0x3a, 0x3f, 0xc7, 0x55, 0x75, 0xe3, 0x3e, 0xfd, 0x48, 0x87])
        let ivLittleEndian = Data([0x87, 0x48, 0xfd, 0x3e, 0xe3, 0x75, 0x55, 0xc7, 0x3f, 0x3a, 0x28, 0xee])
        let plaintextBigEndian = Data([0xd5, 0xde, 0x42, 0xb4, 0x61, 0x64, 0x6c, 0x25, 0x5c, 0x87, 0xbd, 0x29, 0x62, 0xd3, 0xb9, 0xa2])
        let plaintextLittleEndian = Data([0xa2, 0xb9, 0xd3, 0x62, 0x29, 0xbd, 0x87, 0x5c, 0x25, 0x6c, 0x64, 0x61, 0xb4, 0x42, 0xde, 0xd5])
        let associateData = Data() // empty so no endianness
        let expectedCiphertextBigEndian = Data([0x2c, 0xcd, 0xa4, 0xa5, 0x41, 0x5c, 0xb9, 0x1e, 0x13, 0x5c, 0x2a, 0x0f, 0x78, 0xc9, 0xb2, 0xfd])
        let expectedCiphertextLittleEndian = Data([0xfd, 0xb2, 0xc9, 0x78, 0x0f, 0x2a, 0x5c, 0x13, 0x1e, 0xb9, 0x5c, 0x41, 0xa5, 0xa4, 0xcd, 0x2c])
        let expectedTagBigEndian = Data([0xb3, 0x6d, 0x1d, 0xf9, 0xb9, 0xd5, 0xe5, 0x96, 0xf8, 0x3e, 0x8b, 0x7f, 0x52, 0x97, 0x1c, 0xb3])
        let expectedTagLittleEndian = Data([0xb3, 0x1c, 0x97, 0x52, 0x7f, 0x8b, 0x3e, 0xf8, 0x96, 0xe5, 0xd5, 0xb9, 0xf9, 0x1d, 0x6d, 0xb3])
        
        let keyBigEndian = SymmetricKey(data: keyDataBigEndian)
        let nonceBigEndian = try? AES.GCM.Nonce(data: ivBigEndian)
        let encryptedContentBigEndian = try? AES.GCM.seal(plaintextBigEndian, using: keyBigEndian, nonce: nonceBigEndian, authenticating: associateData)
        XCTAssertNotNil(encryptedContentBigEndian)
        if let encryptedContentBigEndian = encryptedContentBigEndian {
            XCTAssertEqual(expectedCiphertextBigEndian, encryptedContentBigEndian.ciphertext)
            XCTAssertEqual(expectedTagBigEndian, encryptedContentBigEndian.tag)
        }
        
        // proof that endianness matters
        let keyLittleEndian = SymmetricKey(data: keyDataLittleEndian)
        let nonceLittleEndian = try? AES.GCM.Nonce(data: ivLittleEndian)
        let encryptedContentLittleEndian = try? AES.GCM.seal(plaintextLittleEndian, using: keyLittleEndian, nonce: nonceLittleEndian, authenticating: associateData)
        XCTAssertNotNil(encryptedContentLittleEndian)
        if let encryptedContentLittleEndian = encryptedContentLittleEndian {
            XCTAssertNotEqual(expectedCiphertextBigEndian, encryptedContentLittleEndian.ciphertext)
            XCTAssertNotEqual(expectedCiphertextLittleEndian, encryptedContentLittleEndian.ciphertext)
            XCTAssertNotEqual(expectedTagBigEndian, encryptedContentLittleEndian.tag)
            XCTAssertNotEqual(expectedTagLittleEndian, encryptedContentLittleEndian.tag)
        }
    }
    
    func testGCMDecryptWithNISTTestVector() {
        // NIST GCM Test Vector
        // from file gcmDecrypt128.rsp
        //
        // [Keylen = 128]
        // [IVlen = 96]
        // [PTlen = 128]
        // [AADlen = 0]
        // [Taglen = 128]
        //
        // Count = 0
        // Key = e98b72a9881a84ca6b76e0f43e68647a
        // IV = 8b23299fde174053f3d652ba
        // CT = 5a3c1cf1985dbb8bed818036fdd5ab42
        // AAD =
        // Tag = 23c7ab0f952b7091cd324835043b5eb5
        // PT = 28286a321293253c3e0aa2704a278032

        let keyData = Data([0xe9, 0x8b, 0x72, 0xa9, 0x88, 0x1a, 0x84, 0xca, 0x6b, 0x76, 0xe0, 0xf4, 0x3e, 0x68, 0x64, 0x7a])
        let iv = Data([0x8b, 0x23, 0x29, 0x9f, 0xde, 0x17, 0x40, 0x53, 0xf3, 0xd6, 0x52, 0xba])
        let ciphertext = Data([0x5a, 0x3c, 0x1c, 0xf1, 0x98, 0x5d, 0xbb, 0x8b, 0xed, 0x81, 0x80, 0x36, 0xfd, 0xd5, 0xab, 0x42])
        let associateData = Data()
        let tag = Data([0x23, 0xc7, 0xab, 0x0f, 0x95, 0x2b, 0x70, 0x91, 0xcd, 0x32, 0x48, 0x35, 0x04, 0x3b, 0x5e, 0xb5])
        let expectedPlaintext = Data([0x28, 0x28, 0x6a, 0x32, 0x12, 0x93, 0x25, 0x3c, 0x3e, 0x0a, 0xa2, 0x70, 0x4a, 0x27, 0x80, 0x32])
        
        let key = SymmetricKey(data: keyData)
        let nonce = try! AES.GCM.Nonce(data: iv)
        let sealedBox = try! AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        
        let plaintext = try? AES.GCM.open(sealedBox, using: key, authenticating: associateData)
        XCTAssertNotNil(plaintext)
        if let plaintext = plaintext {
            XCTAssertEqual(expectedPlaintext, plaintext)
        }
    }

    func testGMACEncryptWithNISTTestVector() {
        // NIST GCM Test Vector
        let keyData = Data([0x77, 0xbe, 0x63, 0x70, 0x89, 0x71, 0xc4, 0xe2, 0x40, 0xd1, 0xcb, 0x79, 0xe8, 0xd7, 0x7f, 0xeb])
        let iv = Data([0xe0, 0xe0, 0x0f, 0x19, 0xfe, 0xd7, 0xba, 0x01, 0x36, 0xa7, 0x97, 0xf3])
        let plaintext = Data()
        let associateData = Data([0x7a, 0x43, 0xec, 0x1d, 0x9c, 0x0a, 0x5a, 0x78, 0xa0, 0xb1, 0x65, 0x33, 0xa6, 0x21, 0x3c, 0xab])
        let expectedCiphertext = Data()
        let expectedTag = Data([0x20, 0x9f, 0xcc, 0x8d, 0x36, 0x75, 0xed, 0x93, 0x8e, 0x9c, 0x71, 0x66, 0x70, 0x9d, 0xd9, 0x46])
        
        let key = SymmetricKey(data: keyData)
        let nonce = try? AES.GCM.Nonce(data: iv)
        let encryptedContent = try? AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: associateData)
        XCTAssertNotNil(encryptedContent)
        if let encryptedContent = encryptedContent {
            XCTAssertEqual(expectedCiphertext, encryptedContent.ciphertext)
            XCTAssertEqual(expectedTag, encryptedContent.tag)
        }
    }
    
    func testGMACDecryptWithNISTTestVector() {
        // NIST GCM Test Vector
        let keyData = Data([0x23, 0x70, 0xe3, 0x20, 0xd4, 0x34, 0x42, 0x08, 0xe0, 0xff, 0x56, 0x83, 0xf2, 0x43, 0xb2, 0x13])
        let iv = Data([0x04, 0xdb, 0xb8, 0x2f, 0x04, 0x4d, 0x30, 0x83, 0x1c, 0x44, 0x12, 0x28])
        let ciphertext = Data()
        let associateData = Data([0xd4, 0x3a, 0x8e, 0x50, 0x89, 0xee, 0xa0, 0xd0, 0x26, 0xc0, 0x3a, 0x85, 0x17, 0x8b, 0x27, 0xda])
        let tag = Data([0x2a, 0x04, 0x9c, 0x04, 0x9d, 0x25, 0xaa, 0x95, 0x96, 0x9b, 0x45, 0x1d, 0x93, 0xc3, 0x1c, 0x6e])
        let expectedPlaintext = Data()
        
        let key = SymmetricKey(data: keyData)
        let nonce = try! AES.GCM.Nonce(data: iv)
        let sealedBox = try! AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        
        let plaintext = try? AES.GCM.open(sealedBox, using: key, authenticating: associateData)
        XCTAssertNotNil(plaintext)
        if let plaintext = plaintext {
            XCTAssertEqual(expectedPlaintext, plaintext)
        }
    }
    
    func testCMACWithNISTTestVector() {
        // https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/mac/cmactestvectors.zip
        // CMACVerAES128.rsp
        // Count = 62
        // Klen = 16
        // Mlen = 32
        // Tlen = 16
        // Key = 7c0b7db9811f10d00e476c7a0d92f6e0
        // Msg = 1ee0ec466d46fd849b40c066b4fbbd22a20a4d80a008ac9af17e4fdfd106785e
        // Mac = baecdc91e9a1fc3572adf1e4232ae285
        // Result = P
        
        let keyDataBigEndian = Data(hexadecimalString: "7c0b7db9811f10d00e476c7a0d92f6e0")!
        let keyDataLittleEndian = Data(hexadecimalString: "e0f6920d7a6c470ed0101f81b97d0b7c")!
        let messageBigEndian = Data(hexadecimalString: "1ee0ec466d46fd849b40c066b4fbbd22a20a4d80a008ac9af17e4fdfd106785e")!
        let messageLittleEndian = Data(hexadecimalString: "5e7806d1df4f7ef19aac080a804d0aa222bdfbb466c0409b84fd466d46ece01e")!
        let expectedMACBigEndian = Data(hexadecimalString: "baecdc91e9a1fc3572adf1e4232ae285")!
        let expectedMACLittleEndian = Data(hexadecimalString: "85e22a23e4f1ad7235fca1e991dcecba")!
        
        var mac = try! CMAC(key: keyDataBigEndian.bytes).authenticate(messageBigEndian.bytes)
        XCTAssertEqual(expectedMACBigEndian, Data(mac))
        
        // proof that endianness matters
        mac = try! CMAC(key: keyDataLittleEndian.bytes).authenticate(messageLittleEndian.bytes)
        XCTAssertNotEqual(expectedMACBigEndian, Data(mac))
        XCTAssertNotEqual(expectedMACLittleEndian, Data(mac))
    }
    
    func testInitialization() {
        let securityManager = SecurityManager()
        securityManager.generateKeyPair()
        XCTAssertNotNil(securityManager.generatedPrivateKey)
        
        let privateKey = securityManager.generatedPrivateKey!
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        XCTAssertEqual(securityManager.getGeneratedPublicKey()!, publicKey)
        
        var error: Unmanaged<CFError>?
        var publicKeyAsData = SecKeyCopyExternalRepresentation(publicKey, &error)! as Data
        publicKeyAsData = publicKeyAsData.subdata(in: 1..<publicKeyAsData.count)
        XCTAssertEqual(securityManager.getGeneratedPublicKeyAsData()!, publicKeyAsData)
        
        let publicKeyX = publicKeyAsData.subdata(in: 0..<publicKeyAsData.count/2)
        XCTAssertEqual(securityManager.getGeneratedPublicKeyX()!, publicKeyX)
        
        let publicKeyY = publicKeyAsData.subdata(in: publicKeyAsData.count/2..<publicKeyAsData.count)
        XCTAssertEqual(securityManager.getGeneratedPublicKeyY()!, publicKeyY)
    }
    
    func testGenerateSharedKeyCurveP224() {
        // generate a key for server
        let attributes224 = [kSecAttrKeySizeInBits: 224,
                             kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                             kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as CFDictionary
        
        var error: Unmanaged<CFError>?
        let serverPrivateKey = SecKeyCreateRandomKey(attributes224, &error)
        let serverPublicKey = SecKeyCopyPublicKey(serverPrivateKey!)
        let serverPublicKeyRep04XY = SecKeyCopyExternalRepresentation(serverPublicKey!, &error)
        let receivedPublicKeyData = (serverPublicKeyRep04XY! as Data).subdata(in: 1..<(serverPublicKeyRep04XY! as Data).count)
        
        // calculating client shared secret
        securityManager.generateKeyPair()
        guard let clientPublicKey = securityManager.getGeneratedPublicKey() else {
            XCTAssert(false, "client key creation failed")
            return
        }
        securityManager.generateSharedSecret(receivedPublicKeyData: receivedPublicKeyData)
        let sharedKeyDataClient = securityManager.delegate?.sharedKeyData
        
        // calculating server shared secret
        let dict = [:] as CFDictionary
        let sharedKeyDataServer = SecKeyCopyKeyExchangeResult(serverPrivateKey!,
                                                              SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                              clientPublicKey,
                                                              dict,
                                                              &error) as Data?
        XCTAssertEqual(sharedKeyDataClient, sharedKeyDataServer)
    }

    func testGenerateSharedKeyCurveP256() {
        // generate a key for server
        let attributes256 = [kSecAttrKeySizeInBits: 256,
                             kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                             kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as CFDictionary

        var error: Unmanaged<CFError>?
        let serverPrivateKey = SecKeyCreateRandomKey(attributes256, &error)
        let serverPublicKey = SecKeyCopyPublicKey(serverPrivateKey!)
        let serverPublicKeyRep04XY = SecKeyCopyExternalRepresentation(serverPublicKey!, &error)
        let receivedPublicKeyData = (serverPublicKeyRep04XY! as Data).subdata(in: 1..<(serverPublicKeyRep04XY! as Data).count)

        // calculating client shared secret
        securityManager.generateKeyPair()
        guard let clientPublicKey = securityManager.getGeneratedPublicKey() else {
            XCTAssert(false, "client key creation failed")
            return
        }
        securityManager.generateSharedSecret(receivedPublicKeyData: receivedPublicKeyData)
        let sharedKeyDataClient = securityManager.delegate?.sharedKeyData

        // calculating server shared secret
        let dict = [:] as CFDictionary
        let sharedKeyDataServer = SecKeyCopyKeyExchangeResult(serverPrivateKey!,
                                                              SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                              clientPublicKey,
                                                              dict,
                                                              &error) as Data?
        XCTAssertEqual(sharedKeyDataClient, sharedKeyDataServer)
    }
    
    func testCalculateKeyConfirmationCodeWithTestVectorP192() {
        // Test vector from BT Authorization Control Service (P-192)
        // Zero = 00000000000000000000000000000000
        // PublicKeyACServer = PKsx || PKsy = 8de2e26adf72c582d6568ef638c4fd59b18da171bdf501f1d929e0484a68a1c2b0fb22930d120555c1ece50ea98dea8407f71be36efac0de
        // PublicKeyACClient = PKcx || PKcy = af33cd0629bc7e996320a3f40368f74de8704fa37b8fab69abaae280882092ccbba7930f419a8a4f9bb16978bbc3838729992559a6f2e2d7
        // ECDHSecret = 7d96f9a3bd3c05cf5cc37feb8b9d5209d5c2597464dec3e9983743e8
        // RandomNumberACServer = 0102030405060708
        // RandomNumberACClient = 090a0b0c0d0e0f10
        // RandomNumberOOB = 1a2b3c4d
        // Salt = a87032f5f3f599bcfcbec3bb431ada86
        // ConfirmationKey = 0a03d59994bef3c188f63c252183cd51
        // ConfirmationACServer = c6c9bffc4f80d1743722c48d8e350faa
        // ConfirmationACClient = 40f07f35e3d3579354d5c4906b60ac10

        let zero = Data(hexadecimalString: "00000000000000000000000000000000")!
        let publicKeyACServer = Data(hexadecimalString: "8de2e26adf72c582d6568ef638c4fd59b18da171bdf501f1d929e0484a68a1c2b0fb22930d120555c1ece50ea98dea8407f71be36efac0de")!
        let publicKeyACClient = Data(hexadecimalString: "af33cd0629bc7e996320a3f40368f74de8704fa37b8fab69abaae280882092ccbba7930f419a8a4f9bb16978bbc3838729992559a6f2e2d7")!
        var publicKeyACServerACClient = publicKeyACServer
        publicKeyACServerACClient.append(publicKeyACClient)
        let ecdhSecret = Data(hexadecimalString: "7d96f9a3bd3c05cf5cc37feb8b9d5209d5c2597464dec3e9983743e8")!
        let randomNumberACServer = Data(hexadecimalString: "0102030405060708")!
        let randomNumberACClient = Data(hexadecimalString: "090a0b0c0d0e0f10")!
        let randomNumberOOB = Data(hexadecimalString: "1a2b3c4d")!
        var randomNumberACServerOOB = randomNumberACServer
        randomNumberACServerOOB.append(randomNumberOOB)
        var randomNumberACClientOOB = randomNumberACClient
        randomNumberACClientOOB.append(randomNumberOOB)
        
        let expectedSalt = Data(hexadecimalString: "a87032f5f3f599bcfcbec3bb431ada86")
        let expectedConfirmationKey = Data(hexadecimalString: "0a03d59994bef3c188f63c252183cd51")
        let expectedConfirmationACServer = Data(hexadecimalString: "c6c9bffc4f80d1743722c48d8e350faa")
        let expectedConfirmationACClient = Data(hexadecimalString: "40f07f35e3d3579354d5c4906b60ac10")
        
        let salt = try! CMAC(key: zero.bytes).authenticate(publicKeyACServerACClient.bytes)
        XCTAssertEqual(Data(salt), expectedSalt)
        
        let confirmationKey = try! CMAC(key: salt).authenticate(ecdhSecret.bytes)
        XCTAssertEqual(Data(confirmationKey), expectedConfirmationKey)
        
        let confirmationACServer = try! CMAC(key: confirmationKey).authenticate(randomNumberACServerOOB.bytes)
        XCTAssertEqual(Data(confirmationACServer), expectedConfirmationACServer)
        
        let confirmationACClient = try! CMAC(key: confirmationKey).authenticate(randomNumberACClientOOB.bytes)
        XCTAssertEqual(Data(confirmationACClient), expectedConfirmationACClient)
    }
    
    func testCalculateKeyConfirmationCodeWithTestVectorP256() {
        // Test vector from BT Authorization Control Service (P-256)
        // Zero = 00000000000000000000000000000000
        // PublicKeyACServer = PKsx || PKsy = ead218590119e8876b29146ff89ca61770c4edbbf97d38ce385ed281d8a6b23028af61281fd35e2fa7002523acc85a429cb06ee6648325389f59edfce1405141

        // PublicKeyACClient = PKcx || PKcy = 700c48f77f56584c5cc632ca65640db91b6bacce3a4df6b42ce7cc838833d287db71e509e3fd9b060ddb20ba5c51dcc5948d46fbf640dfe0441782cab85fa4ac
        // ECDHKey = ec18d4bca430909ea71edc97a152ea2d
        // RandomNumberACServer = 0102030405060708
        // RandomNumberACClient = 090a0b0c0d0e0f10
        // RandomNumberOOB = 1a2b3c4d
        // Salt = e9467962219ac62d741de3b97b946dff
        // ConfirmationKey    = 0564450a943ea622802e4355901feace
        // ACServerConfirmationCode    = fb69d9f98bb0de09569bb0900763dac6
        // ACClientConfirmationCode    = 5e88fc3a1ba0a3de8fea2d02fdff8ece

        let zero = Data(hexadecimalString: "00000000000000000000000000000000")!
        let publicKeyACServer = Data(hexadecimalString: "ead218590119e8876b29146ff89ca61770c4edbbf97d38ce385ed281d8a6b23028af61281fd35e2fa7002523acc85a429cb06ee6648325389f59edfce1405141")!
        let publicKeyACClient = Data(hexadecimalString: "700c48f77f56584c5cc632ca65640db91b6bacce3a4df6b42ce7cc838833d287db71e509e3fd9b060ddb20ba5c51dcc5948d46fbf640dfe0441782cab85fa4ac")!
        var publicKeyACServerACClient = publicKeyACServer
        publicKeyACServerACClient.append(publicKeyACClient)
        let ecdhKey = Data(hexadecimalString: "ec18d4bca430909ea71edc97a152ea2d")!
        let randomNumberACServer = Data(hexadecimalString: "0102030405060708")!
        let randomNumberACClient = Data(hexadecimalString: "090a0b0c0d0e0f10")!
        let randomNumberOOB = Data(hexadecimalString: "1a2b3c4d")!
        var randomNumberACServerOOB = randomNumberACServer
        randomNumberACServerOOB.append(randomNumberOOB)
        var randomNumberACClientOOB = randomNumberACClient
        randomNumberACClientOOB.append(randomNumberOOB)

        let expectedSalt = Data(hexadecimalString: "e9467962219ac62d741de3b97b946dff")
        let expectedConfirmationKey = Data(hexadecimalString: "0564450a943ea622802e4355901feace")
        let expectedConfirmationACServer = Data(hexadecimalString: "fb69d9f98bb0de09569bb0900763dac6")
        let expectedConfirmationACClient = Data(hexadecimalString: "5e88fc3a1ba0a3de8fea2d02fdff8ece")

        let salt = try! CMAC(key: zero.bytes).authenticate(publicKeyACServerACClient.bytes)
        XCTAssertEqual(Data(salt), expectedSalt)

        let confirmationKey = try! CMAC(key: salt).authenticate(ecdhKey.bytes)
        XCTAssertEqual(Data(confirmationKey), expectedConfirmationKey)

        let confirmationACServer = try! CMAC(key: confirmationKey).authenticate(randomNumberACServerOOB.bytes)
        XCTAssertEqual(Data(confirmationACServer), expectedConfirmationACServer)

        let confirmationACClient = try! CMAC(key: confirmationKey).authenticate(randomNumberACClientOOB.bytes)
        XCTAssertEqual(Data(confirmationACClient), expectedConfirmationACClient)
    }
    
    func testCalculateKeyConfirmationCode() {
        // generate a key for server
        let attributes256 = [kSecAttrKeySizeInBits: 256,
                             kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                             kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as [CFString : Any] as CFDictionary
        var error: Unmanaged<CFError>?
        let serverPrivateKey = SecKeyCreateRandomKey(attributes256, &error)
        let serverPublicKey = SecKeyCopyPublicKey(serverPrivateKey!)
        let serverPublicKeyRep04XY = SecKeyCopyExternalRepresentation(serverPublicKey!, &error)
        let receivedPublicKeyData = (serverPublicKeyRep04XY! as Data).subdata(in: 1..<(serverPublicKeyRep04XY! as Data).count)
        
        // calculating shared secret
        securityManager.generateKeyPair()
        securityManager.generateSharedSecret(receivedPublicKeyData: receivedPublicKeyData)
        let sharedKeyData = securityManager.delegate?.sharedKeyData!
        
        // set the OOB number
        let expectedOOBRandomNumber: UInt32 = 0x0000002A
        securityManager.configuration.oobRandomNumber = Data(bigEndian: expectedOOBRandomNumber)
        
        // calculate confirmation key
        let zeroKeyData = Data(Array(repeating: 0x00, count: 16))
        var message = Data(securityManager.getCounterpartPublicKeyX()!)
        message.append(Data(securityManager.getCounterpartPublicKeyY()!))
        message.append(Data(securityManager.getGeneratedPublicKeyX()!))
        message.append(Data(securityManager.getGeneratedPublicKeyY()!))
        var key = SymmetricKey(data: zeroKeyData)
        let saltKey = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        var authValue = Data((1...32-securityManager.configuration.oobRandomNumber.count).map { _ in UInt8(0) })
        authValue.append(securityManager.configuration.oobRandomNumber)
        message = sharedKeyData!
        message.append(Data(authValue))
        key = SymmetricKey(data: saltKey)
        let expectedConfirmationKey = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        let confirmationKey = securityManager.calculateConfirmationKey()!
        XCTAssertEqual(Data(expectedConfirmationKey), confirmationKey)
        
        // calculate expected client confirmation code
        let clientRanNum = securityManager.generatedRandomNumberData
        let oobRanNum = securityManager.configuration.oobRandomNumber
        message = clientRanNum
        key = SymmetricKey(data: confirmationKey)
        var expectedClientConfirmationCode = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        expectedClientConfirmationCode.reverse()
        
        // calculate expected server confirmation code
        let serverRandomNumberBigEndian = Data([0x05, 0x04, 0x03, 0x02, 0x01])
        let serverRandomNumberLittleEndian = Data(serverRandomNumberBigEndian.reversed())
        message = Data(serverRandomNumberBigEndian)
        let expectedServerConfirmationCode = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        let expectedServerConfirmationCodeLittleEndian = Data(expectedServerConfirmationCode.reversed())
        
        let confirmationCodeClient = securityManager.calculateGeneratedConfirmationCodeInLittleEndian()
        let (confirmationCodeServerLittleEndian, _) = securityManager.calculateKeyConfirmationReceivedLittleEndian(receivedRandomNumberLittleEndian: serverRandomNumberLittleEndian)

        XCTAssertEqual(expectedClientConfirmationCode, confirmationCodeClient)
        XCTAssertEqual(expectedServerConfirmationCodeLittleEndian, confirmationCodeServerLittleEndian)
    }
    
    func testgetGeneratedPublicKeyXAndY() {
        securityManager.generateKeyPair()
        let clientPublicKey = securityManager.getGeneratedPublicKeyAsData()!
        XCTAssertEqual(securityManager.getGeneratedPublicKeyX(), clientPublicKey.subdata(in: 0..<clientPublicKey.count/2))
        XCTAssertEqual(securityManager.getGeneratedPublicKeyY(), clientPublicKey.subdata(in: clientPublicKey.count/2..<clientPublicKey.count))
    }
    
    func testProtectRequest() {
        let macSize = 8
        let nonceSizeOctetsVariable = 8
        let ivFixedField: Data = Data(UInt32(12345678))
        let keyData = Data(hexadecimalString: "7fddb57453c241d03efbed3ac44e371c")!
        let resourceHandle: ResourceHandle = 1234
        let securityConfigurationID: UInt16 = 1
        sharedKeyData = keyData
        securityManager.configuration.macSize = macSize
        securityManager.configuration.nonceSizeOctetsVariable = nonceSizeOctetsVariable
        securityManager.configuration.receivedIVFixedField = ivFixedField
        securityManager.configuration.generatedIVFixedField = ivFixedField
        securityManager.configuration.securityControls = [SecurityControlType.nonce, SecurityControlType.mac, SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData]
        securityManager.configuration.securityConfigurationID = securityConfigurationID
        
        var request = Data(resourceHandle)
        request.append(Data([0x01, 0x02, 0x03, 0x04]))
        var result = securityManager.protectRequest(request)
        switch result {
        case .success(let protectedRequest):
            let plaintext = Data(request.reversed())
            let key = SymmetricKey(data: keyData)
            let expectedSequenceNumber: UInt64 = 1
            var expectedNonce = ivFixedField
            expectedNonce.appendBigEndian(expectedSequenceNumber)
            let nonce = try! AES.GCM.Nonce(data: expectedNonce)
            let encryptedContent = try! AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: Data())

            XCTAssertEqual(protectedRequest.count, 24)
            XCTAssertEqual(protectedRequest.subdata(in: 0..<2), Data(securityConfigurationID))
            XCTAssertEqual(protectedRequest.subdata(in: 2..<10), Data(expectedSequenceNumber))
            XCTAssertEqual(protectedRequest.subdata(in: 10..<18), Data(Data(encryptedContent.tag).subdata(in: 0..<macSize).reversed()))
            XCTAssertEqual(protectedRequest.subdata(in: 18..<24), Data(encryptedContent.ciphertext.reversed()))
        case .failure(_):
            XCTAssert(false)
        }

        // now reorder the controls and ensure the protected request changes as well
        securityManager.configuration.securityControls = [SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData, SecurityControlType.nonce, SecurityControlType.mac]
        
        result = securityManager.protectRequest(request)
        switch result {
        case .success(let protectedRequest):
            let plaintext = Data(request.reversed())
            let key = SymmetricKey(data: keyData)
            let expectedSequenceNumber: UInt64 = 2
            var expectedNonce = ivFixedField
            expectedNonce.appendBigEndian(expectedSequenceNumber)
            let nonce = try! AES.GCM.Nonce(data: expectedNonce)
            let encryptedContent = try! AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: Data())

            XCTAssertEqual(protectedRequest.subdata(in: 0..<2), Data(securityConfigurationID))
            XCTAssertEqual(protectedRequest.subdata(in: 2..<8), Data(encryptedContent.ciphertext.reversed()))
            XCTAssertEqual(protectedRequest.subdata(in: 8..<16), Data(expectedSequenceNumber))
            XCTAssertEqual(protectedRequest.subdata(in: 16..<24), Data(Data(encryptedContent.tag).subdata(in: 0..<macSize).reversed()))
        case .failure(_):
            XCTAssert(false)
        }
    }
    
    func testDecryptSecureResponse() {
        let macSize = 8
        let nonceSizeOctetsVariable = 8
        let ivFixedField: Data = Data(UInt32(12345678))
        let keyData = Data(hexadecimalString: "7fddb57453c241d03efbed3ac44e371c")!
        let securityConfigurationID: UInt16 = 2
        sharedKeyData = keyData
        securityManager.configuration.macSize = macSize
        securityManager.configuration.nonceSizeOctetsVariable = nonceSizeOctetsVariable
        securityManager.configuration.receivedIVFixedField = ivFixedField
        securityManager.configuration.generatedIVFixedField = ivFixedField
        securityManager.configuration.securityControls = [SecurityControlType.nonce, SecurityControlType.mac, SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData]
        securityManager.configuration.securityConfigurationID = securityConfigurationID
        
        let expectedResponse = Data([0x01, 0x02, 0x03, 0x04])
        let plaintext = Data(expectedResponse.reversed())
        let key = SymmetricKey(data: keyData)
        let sequenceNumber: UInt64 = 1
        var nonceData = ivFixedField
        nonceData.appendBigEndian(sequenceNumber)
        let nonce = try! AES.GCM.Nonce(data: nonceData)
        let encryptedContent = try! AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: Data())
        
        // secure response fields are in little endian byte order
        var secureResponse = Data(securityConfigurationID)
        secureResponse.append(sequenceNumber)
        secureResponse.append(Data(Data(encryptedContent.tag).subdata(in: 0..<macSize).reversed()))
        secureResponse.append(Data(encryptedContent.ciphertext.reversed()))

        let result = securityManager.decryptSecurePayload(secureResponse)
        switch result {
        case .success(let response):
            XCTAssertEqual(response, expectedResponse)
        case .failure(_):
            XCTAssert(false)
        }
    }
    
    func testNextIV() {
        let ivFixedField: Data = Data(UInt32(12345678))
        let sequenceNumber: UInt64 = 1234567890
        var expectedNextIV = ivFixedField
        expectedNextIV.appendBigEndian(sequenceNumber+1)
        
        let securityManager = SecurityManager(sequenceNumber: sequenceNumber)
        securityManager.configuration.receivedIVFixedField = ivFixedField
        securityManager.configuration.generatedIVFixedField = ivFixedField
        
        XCTAssertEqual(securityManager.nextIV(), expectedNextIV)
    }
    
    func testKeySizing() {
        // AES-128 restricts the key to 128 bits (16 octets). encryption and decryption will fail if the key isn't the correct size.
        let largeKey = Data(hexadecimalString: "0102030405060708090a0b0c0d0e0f10111213141516171819")!
        let macSize = 8
        let nonceSizeOctetsVariable = 8
        let ivFixedField: Data = Data(UInt32(12345678))
        let resourceHandle: ResourceHandle = 1234
        sharedKeyData = largeKey
        securityManager.configuration.macSize = macSize
        securityManager.configuration.nonceSizeOctetsVariable = nonceSizeOctetsVariable
        securityManager.configuration.receivedIVFixedField = ivFixedField
        securityManager.configuration.generatedIVFixedField = ivFixedField
        securityManager.configuration.securityControls = [SecurityControlType.nonce, SecurityControlType.mac, SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData]
        
        var request = Data(resourceHandle)
        request.append(Data([0x01, 0x02, 0x03, 0x04]))

        var result = securityManager.protectRequest(request)
        switch result {
        case .success(let protected):
            result = securityManager.decryptSecurePayload(protected)
            switch result {
            case .success(let final):
                XCTAssertEqual(request, final)
            case .failure(_):
                XCTAssert(false)
            }
        case .failure(_):
            XCTAssert(false)
        }
    }
    
    func testDelegationConfigurationUpdate() {
        XCTAssertFalse(securityManager.configuration.hasOOBRandomNumber)

        securityManager.configuration.oobRandomNumber = Data([0x02])
        XCTAssertEqual(updatedConfiguration.oobRandomNumber, Data([0x02]))
        XCTAssertTrue(updatedConfiguration.hasOOBRandomNumber)
        
        securityManager.configuration.ecdhKeyID = 3
        XCTAssertEqual(updatedConfiguration.ecdhKeyID, 3)
        
        securityManager.configuration.securityControls = [.mac]
        XCTAssertEqual(updatedConfiguration.securityControls, [.mac])
        
        securityManager.configuration.macSize = 16
        XCTAssertEqual(updatedConfiguration.macSize, 16)
        
        securityManager.configuration.nonceSizeOctetsVariable = 32
        XCTAssertEqual(updatedConfiguration.nonceSizeOctetsVariable, 32)
        
        securityManager.configuration.receivedIVFixedField = Data(UInt32(0xffffffff))
        XCTAssertEqual(updatedConfiguration.receivedIVFixedField, Data(UInt32(0xffffffff)))

        securityManager.configuration.generatedIVFixedField = Data(UInt32(0xffffffff))
        XCTAssertEqual(updatedConfiguration.generatedIVFixedField, Data(UInt32(0xffffffff)))

        securityManager.configuration.sequenceNumber = 100
        XCTAssertEqual(updatedConfiguration.sequenceNumber, 100)

        securityManager.configuration.securityConfigurationID = 4
        XCTAssertEqual(updatedConfiguration.securityConfigurationID, 4)
    }
    
    func testDelegationSecurityEstablished() {
        securityManager.keyExchangeResults(true)
        XCTAssertTrue(securityEstablished)
    }

    func testSecurityManagerErrorMissKey() {
        let result = securityManager.encrypt(plaintext: Data(0x01020304))
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .missingKey)
        }
    }

    func testSecurityManagerErrorDecryptionFailed() {
        let macSize = 8
        let nonceSizeOctetsVariable = 8
        let ivFixedField: Data = Data(UInt32(12345678))
        let keyData = Data(hexadecimalString: "7fddb57453c241d03efbed3ac44e371c")!
        let securityConfigurationID: UInt16 = 2
        sharedKeyData = keyData
        securityManager.configuration.macSize = macSize
        securityManager.configuration.nonceSizeOctetsVariable = nonceSizeOctetsVariable
        securityManager.configuration.receivedIVFixedField = ivFixedField
        securityManager.configuration.generatedIVFixedField = ivFixedField
        securityManager.configuration.securityControls = [SecurityControlType.nonce, SecurityControlType.mac, SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData]
        securityManager.configuration.securityConfigurationID = securityConfigurationID

        // secure response fields are in little endian byte order
        var secureResponse = Data(securityConfigurationID)
        secureResponse.append(UInt64(1))
        secureResponse.append(Data(0x01020304))

        let result = securityManager.decryptSecurePayload(secureResponse)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .decryptionFailed)
        }
    }

    func testSecurityManagerErrorEncryptionFailed() {
        let macSize = 8
        let nonceSizeOctetsVariable = 8
        let ivFixedField: Data = Data(UInt32(12345678))
        let tooShortKeyData = Data([0x7f, 0xdd, 0xb5, 0x74, 0x53, 0xc2, 0x41, 0xd0, 0x3e, 0xfb, 0xed, 0x3a, 0xc4, 0x4e, 0x37])
        let securityConfigurationID: UInt16 = 2
        sharedKeyData = tooShortKeyData
        securityManager.configuration.macSize = macSize
        securityManager.configuration.nonceSizeOctetsVariable = nonceSizeOctetsVariable
        securityManager.configuration.receivedIVFixedField = ivFixedField
        securityManager.configuration.generatedIVFixedField = ivFixedField
        securityManager.configuration.securityControls = [SecurityControlType.nonce, SecurityControlType.mac, SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData]
        securityManager.configuration.securityConfigurationID = securityConfigurationID

        let result = securityManager.encrypt(plaintext: Data(0x01020304), keyData: tooShortKeyData, nonceData: securityManager.nextIV())
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .encryptionFailed)
        }
    }

    func testSecurityManagerErrorIncorrectSecurityConfiguration() {
        let macSize = 8
        let nonceSizeOctetsVariable = 8
        let ivFixedField: Data = Data(UInt32(12345678))
        let keyData = Data(hexadecimalString: "7fddb57453c241d03efbed3ac44e371c")!
        let securityConfigurationID: UInt16 = 2
        let wrongSecurityConfigurationID: UInt16 = 3
        sharedKeyData = keyData
        securityManager.configuration.macSize = macSize
        securityManager.configuration.nonceSizeOctetsVariable = nonceSizeOctetsVariable
        securityManager.configuration.receivedIVFixedField = ivFixedField
        securityManager.configuration.generatedIVFixedField = ivFixedField
        securityManager.configuration.securityControls = [SecurityControlType.nonce, SecurityControlType.mac, SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData]
        securityManager.configuration.securityConfigurationID = securityConfigurationID

        // secure response fields are in little endian byte order
        var secureResponse = Data(wrongSecurityConfigurationID)
        secureResponse.append(UInt64(1))
        secureResponse.append(Data(0x01020304))

        let result = securityManager.decryptSecurePayload(secureResponse)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .incorrectSecurityConfiguration)
        }
    }

    func testHKDFWithRFCTestVestor() {
        // RFC 5869 - Basic test case with SHA-256

        // Hash = SHA-256
        // IKM  = 0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b (22 octets)
        // salt = 0x000102030405060708090a0b0c (13 octets)
        // info = 0xf0f1f2f3f4f5f6f7f8f9 (10 octets)
        // L    = 42
        //
        // PRK  = 0x077709362c2e32df0ddc3f0dc47bba63
        //        90b6c73bb50f9c3122ec844ad7c2b3e5 (32 octets)
        // OKM  = 0x3cb25f25faacd57a90434f64d0362f2a
        //        2d2d0a90cf1a5a4c5db02d56ecc4c5bf
        //        34007208d5b887185865 (42 octets)

        let inputKeyMaterialData = Data(hexadecimalString: "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b")!
        let salt = Data(hexadecimalString: "000102030405060708090a0b0c")!
        let info = Data(hexadecimalString: "f0f1f2f3f4f5f6f7f8f9")!
        let outputByteCount = 42
        let expectedResultingKeyData = Data(hexadecimalString: "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865")!
        let expectedResultingKey = SymmetricKey(data: expectedResultingKeyData)

        let resultingKey = CryptoKit.HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: inputKeyMaterialData), salt: salt, info: info, outputByteCount: outputByteCount)
        XCTAssertEqual(expectedResultingKey, resultingKey)
    }

    func testKDFWithTestVectorSHA256() {
        // IKM = ECDHSecret =
        // 46FC62106420FF012E54A434FBDD2D25CCC5852060561E68040DD7778997BD7B
        // KDF    = HKDF
        // Hash    = SHA-256
        // Salt    = 0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20
        // Info    = 414353
        // L    = 16
        // OKM = ECDHKey = EC18D4BCA430909EA71EDC97A152EA2D

        let inputKeyMaterialData = Data(hexadecimalString: "46FC62106420FF012E54A434FBDD2D25CCC5852060561E68040DD7778997BD7B")!
        let salt = Data(hexadecimalString: "0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20")!
        let info = Data(hexadecimalString: "414353")!
        let outputByteCount = 16
        let expectedResultingKeyData = Data(hexadecimalString: "EC18D4BCA430909EA71EDC97A152EA2D")!
        let expectedResultingKey = SymmetricKey(data: expectedResultingKeyData)

        let resultingKey = CryptoKit.HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: inputKeyMaterialData), salt: salt, info: info, outputByteCount: outputByteCount)
        XCTAssertEqual(expectedResultingKey, resultingKey)
    }

    func testDerivedKeyP256() {
        // generate a key for server
        let attributes256 = [kSecAttrKeySizeInBits: 256,
                             kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                             kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as CFDictionary

        var error: Unmanaged<CFError>?
        let serverPrivateKey = SecKeyCreateRandomKey(attributes256, &error)
        let serverPublicKey = SecKeyCopyPublicKey(serverPrivateKey!)
        let serverPublicKeyRep04XY = SecKeyCopyExternalRepresentation(serverPublicKey!, &error)
        let receivedPublicKeyData = (serverPublicKeyRep04XY! as Data).subdata(in: 1..<(serverPublicKeyRep04XY! as Data).count)

        // calculating client shared secret
        securityManager.configuration.ellipticCurve = .p256
        securityManager.generateKeyPair()
        guard let clientPublicKey = securityManager.getGeneratedPublicKey() else {
            XCTAssert(false, "client key creation failed")
            return
        }

        let keyDerivationFunctionConfiguration = SecurityManager.Configuration.KeyDerivationFunctionConfiguration(keyDerivationFunction: .hkdfSHA256)
        securityManager.configuration.keyDerivationFunctionConfiguration = keyDerivationFunctionConfiguration

        securityManager.generateSharedSecret(receivedPublicKeyData: receivedPublicKeyData)
        let success = securityManager.derivateSharedKey()
        XCTAssertTrue(success)
        
        let sharedKeyDataClient = securityManager.delegate?.sharedKeyData

        // calculating server shared secret
        let dict = [:] as CFDictionary
        let sharedKeyDataServer = SecKeyCopyKeyExchangeResult(serverPrivateKey!,
                                                              SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                              clientPublicKey,
                                                              dict,
                                                              &error) as Data?

        let derivedKey = CryptoKit.HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: sharedKeyDataServer!), salt: keyDerivationFunctionConfiguration.salt, info: keyDerivationFunctionConfiguration.info, outputByteCount: keyDerivationFunctionConfiguration.keyDerivationFunction.outputByteCount)
        let derivedKeyData = derivedKey.withUnsafeBytes { Data(Array($0)) }

        XCTAssertEqual(sharedKeyDataClient, derivedKeyData)
    }
}

extension SecurityManagerTests: RequestHandler { }

extension SecurityManagerTests: SecurityManagerDelegate {
    func securityManagerDidEstablishedSecurity(_ securityManager: SecurityManager) {
        securityEstablished = true
    }
    
    func securityManagerDidUpdateConfiguration(_ securityManager: SecurityManager) {
        updatedConfiguration = securityManager.configuration
    }
}
