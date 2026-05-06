//
//  KeyExchangeECDH.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public typealias KeyID = UInt16

struct KeyExchangeECDH: RequestHandler {

    static func setClientFixedNonce(securityManager: SecurityManager) -> Data {
        let keyID: KeyID = securityManager.configuration.algorithmKeyID
        let clientIVFixedField = securityManager.generateNewNonceFixed()

        var operand = Data(keyID)
        // security manager stores client fixed nonce in big endianness, but transmission expects little endianness
        operand.append(contentsOf: clientIVFixedField.reversed())

        return KeyExchangeECDH.buildControlPointRequest(opcode: ACControlPointOpcode.setClientNonceFixed, operand: operand)
    }

    static func startKeyExchange(securityManager: SecurityManager) -> Data {
        var operand = Data(securityManager.configuration.ecdhKeyID)
        operand.append(StartKeyExchangeConfirmationMethod.noMethod.rawValue)
        operand.append(StartKeyExchangeConfirmationAction.staticAction.rawValue)
        
        return KeyExchangeECDH.buildControlPointRequest(opcode: ACControlPointOpcode.startKeyExchange, operand: operand)
    }

    static func ecdhRequestUncompressedPlain(securityManager: SecurityManager) -> Data? {
        let keyID: KeyID = securityManager.configuration.ecdhKeyID
        guard var publicKeyX = securityManager.getGeneratedPublicKeyX(),
              var publicKeyY = securityManager.getGeneratedPublicKeyY()
        else {
            return nil
        }
        
        // send in little endian
        publicKeyX.reverse()
        publicKeyY.reverse()
        
        let publicKeyXSize = UInt8(publicKeyX.count)
        let publicKeyYSize = UInt8(publicKeyY.count)

        var operand = Data(keyID)
        operand.append(publicKeyXSize)
        operand.append(publicKeyX)
        operand.append(publicKeyYSize)
        operand.append(publicKeyY)

        return KeyExchangeECDH.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeECDH, operand: operand)
    }
    
    static func ecdhRequestCertificate(securityManager: SecurityManager, certificateData: Data) -> Data {
        let keyID: KeyID = securityManager.configuration.ecdhKeyID
        let certificateSize = UInt16(certificateData.count)

        var operand = Data(keyID)
        operand.append(certificateSize)
        operand.append(contentsOf: certificateData)

        return KeyExchangeECDH.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeECDH, operand: operand)
    }
    
    static func ecdhConfirmationCodeRequest(securityManager: SecurityManager) -> Data? {
        let keyID: KeyID = securityManager.configuration.ecdhKeyID
        guard let confirmationCode = securityManager.calculateGeneratedConfirmationCodeInLittleEndianClient() else {
            return nil
        }
        
        var operand = Data()
        operand.append(keyID)
        operand.append(confirmationCode)
        
        return KeyExchangeECDH.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeECDHConfirmationCode, operand: operand)
    }
    
    static func ecdhConfirmationRandomNumberRequest(securityManager: SecurityManager) -> Data {
        let keyID: KeyID = securityManager.configuration.ecdhKeyID
        let generatedRandomNumberData = securityManager.generatedRandomNumberData
        
        var operand = Data()
        operand.append(keyID)
        operand.append(generatedRandomNumberData)
        
        return KeyExchangeECDH.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumber, operand: operand)
    }
    
    static func handleResponse(_ response: Data, opcode: ACControlPointOpcode, securityManager: SecurityManager) -> DeviceCommResult<Any?> {
        switch opcode {
        case .keyExchangeECDHResponse:
            return handleECDHResponse(response, securityManager: securityManager)
        case .keyExchangeECDHConfirmationCodeResponse:
            return handleECDHConfirmationCodeResponse(response, securityManager: securityManager)
        case .keyExchangeECDHConfirmationRandomNumberResponse:
            return handleECDHConfirmationRandomNumberResponse(response, securityManager: securityManager)
        case .keyExchangeResponse:
            return handleResponse(response, securityManager: securityManager)
        case .keyExchangeKDFResponse:
            return handleKDFResponse(response, securityManager: securityManager)
        default:
            return .failure(.opcodeUnknown("This is not a key exchange ECDH opcode: \(String(describing: opcode)). It was incorrectly routed."))
        }
    }
    
    static func handleECDHResponse(_ response: Data, securityManager: SecurityManager) -> DeviceCommResult<Any?> {
        let expectedResponseLength = securityManager.configuration.ellipticCurve.ecdhResponseLength
        guard response.count == expectedResponseLength else {
            return .failure(.invalidFormat)
        }
        
        var index = 1 // skip the opcode
        let keyID = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
        index += 2
        guard keyID == securityManager.configuration.ecdhKeyID else {
            // this is a response not related to the ECDH key exchange procedure
            return .failure(.invalidOperand)
        }
        
        // parse X and Y of received public key
        let coordinateXSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
        index += 1
        var receivedPublicKeyX = response.subdata(in: index..<index+coordinateXSize)
        index += coordinateXSize
        
        // change to big endian
        receivedPublicKeyX.reverse()
        
        let coordinateYSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
        index += 1
        var receivedPublicKeyY = response.subdata(in: index..<index+coordinateYSize)
        index += coordinateYSize
        
        // change to big endian
        receivedPublicKeyY.reverse()
        
        // put the coordinates together
        var receivedPublicKeyData: Data = receivedPublicKeyX
        receivedPublicKeyData.append(receivedPublicKeyY)
        
        securityManager.generateSharedSecret(receivedPublicKeyData: receivedPublicKeyData)
        return .success(nil)
    }
    
    static func handleECDHConfirmationCodeResponse(_ response: Data, securityManager: SecurityManager) -> DeviceCommResult<Any?> {
        let expectedResponseLength = 3
        guard response.count >= expectedResponseLength else {
            return .failure(.invalidFormat)
        }
        var index = 1 // skip the opcode
        
        let keyID = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
        index += 2
        guard keyID == securityManager.configuration.ecdhKeyID else {
            // this is a response not related to the ECDH key exchange procedure
            return .failure(.invalidOperand)
        }
        
        let confirmationCode = response.subdata(in: index..<response.count)
        securityManager.keyConfirmationCodeReceivedLittleEndian = confirmationCode
        
        return .success(nil)
    }
    
    static func handleECDHConfirmationRandomNumberResponse(_ response: Data, securityManager: SecurityManager) -> DeviceCommResult<Any?> {
        let expectedResponseLength = 3
        guard response.count >= expectedResponseLength else {
            return .failure(.invalidFormat)
        }
        var index = 1 // skip the opcode
        
        let keyID = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
        index += 2
        guard keyID == securityManager.configuration.ecdhKeyID else {
            // this is a response not related to the ECDH key exchange procedure
            return .failure(.invalidOperand)
        }

        let randomNumber = response.subdata(in: index..<response.count)
        let (_, validated) = securityManager.calculateKeyConfirmationReceivedLittleEndian(serverRandomNumberLittleEndian: randomNumber)

        return validated ? .success(nil) : .failure(.authenticationFailed)
    }
    
    static func handleResponse(_ response: Data, securityManager: SecurityManager) -> DeviceCommResult<Any?> {
        let expectedResponseLength = 4
        guard response.count == expectedResponseLength else {
            return .failure(.invalidFormat)
        }
        var index = 1 // skip the opcode
        
        let keyID = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
        index += 2
        guard keyID == securityManager.configuration.ecdhKeyID else {
            // this is a response not related to the ECDH key exchange procedure
            return .failure(.invalidOperand)
        }
        
        let responseCode = KeyExchangeResponseCode(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self))
        securityManager.keyExchangeResults(responseCode == KeyExchangeResponseCode.successful)
        return responseCode == KeyExchangeResponseCode.successful ? .success(nil) : .failure(.authenticationFailed)
    }

    static func handleKDFResponse(_ response: Data, securityManager: SecurityManager) -> DeviceCommResult<Any?> {
        let expectedResponseLengthMin = 4
        guard response.count >= expectedResponseLengthMin else {
            return .failure(.invalidFormat)
        }

        var index = 1 // skip the opcode

        _ = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
        index += 2

        let saltSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
        index += 1

        if saltSize > 0 {
            // key derivation function salt
            var salt = response.subdata(in: index..<index+saltSize)
            index += saltSize
            // BT transmits in little endian, but the sercurty manager uses big endian
            salt.reverse()
            securityManager.configuration.keyDerivationFunctionConfiguration?.salt = salt
        }

        let infoSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
        index += 1

        if infoSize > 0 {
            // key derivation function info
            var info = response.subdata(in: index..<index+infoSize)
            index += infoSize
            // BT transmits in little endian, but the sercurty manager uses big endian
            info.reverse()
            securityManager.configuration.keyDerivationFunctionConfiguration?.info = info
        }

        let success = securityManager.derivateSharedKey()
        if success {
            return .success(nil)
        } else {
            return .failure(.securityManagerError(.keyDerivationFailed))
        }
    }
}

public enum StartKeyExchangeConfirmationMethod: UInt8 {
    case noMethod
    case oobNumberOutput
    case oobNumberInput
    case oobNumberStatic
}

public enum StartKeyExchangeConfirmationAction: UInt8 {
    case push
    case beep
    case inputNumeric
    case outputNumeric
    case staticAction = 0xff
}

public enum KeyExchangeResponseCode: UInt8 {
    case successful
    case failed
}

public enum KeyDerivationFunction: UInt8, Codable {
    case hkdfSHA256
    case hkdfSHA384
    case hkdfSHA512

    var hashLengthOctets: Int {
        switch self {
        case .hkdfSHA256:
            return 32
        case .hkdfSHA384:
            return 48
        case .hkdfSHA512:
            return 64
        }
    }

    var outputByteCount: Int {
        return 16
    }
 }

public enum KeyFormat: UInt8, Codable {
    case plain
    case x509Encoded
}
