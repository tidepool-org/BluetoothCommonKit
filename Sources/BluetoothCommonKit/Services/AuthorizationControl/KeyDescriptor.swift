//
//  KeyDescriptor.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct KeyDescriptor: RequestHandler {
    
    static let recordHeaderSize = 4
    static let ecdhRecordHeaderSize = 4
    static let oobRecordHeaderSize = 5
    static let aesRecordHeaderSizeMin = 7
    static let nonceHeaderSizeMin = 3
    static let kdfRecordHeaderSize = 3
    
    static var request: Data {
        return KeyDescriptor.buildControlPointRequest(opcode: ACControlPointOpcode.getKeyDescriptor)
    }
    
    static func handleResponse(_ response: Data, securityManager: SecurityManager) -> DeviceCommResult<Any?> {
        var index = 1 // skip opcode

        while index < response.count {
            guard index + recordHeaderSize <= response.count else { return .failure(.invalidFormat) }
            let recordType = KeyType(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyType.RawValue.self))
            index += 1
            
            let recordValue = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2

            let dataSize = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            
            if dataSize > 0 {
                guard index + Int(dataSize) <= response.count else { return .failure(.invalidFormat) }
                switch recordType {
                case .ecdh:
                    guard index + ecdhRecordHeaderSize <= response.count else { return .failure(.invalidFormat) }

                    securityManager.configuration.ecdhKeyID = recordValue

                    // key exchange parameter
                    _ = KeyFormat(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyFormat.RawValue.self))
                    index += 1

                    _ = KeyFormat(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyFormat.RawValue.self))
                    index += 1

                    let curve = EllipticCurve(rawValue: response[response.startIndex.advanced(by: index)...].to(EllipticCurve.RawValue.self))
                    index += 1
                    securityManager.configuration.ellipticCurve = curve ?? .p256

                    let keyDerivationFunction = KeyDerivationFunction(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyDerivationFunction.RawValue.self)) ?? .hkdfSHA256
                    index += 1

                    securityManager.configuration.keyDerivationFunctionConfiguration = SecurityManager.Configuration.KeyDerivationFunctionConfiguration(keyDerivationFunction: keyDerivationFunction)
                case .oobKey:
                    guard index + oobRecordHeaderSize <= response.count else { return .failure(.invalidFormat) }
                    // OOB key exchange parameter
                    _ = OOBMethod(rawValue: response[response.startIndex.advanced(by: index)...].to(OOBMethod.RawValue.self))
                    index += 1

                    _ = KeyFormat(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyFormat.RawValue.self))
                    index += 1

                    _ = KeyFormat(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyFormat.RawValue.self))
                    index += 1

                    _ = EllipticCurve(rawValue: response[response.startIndex.advanced(by: index)...].to(EllipticCurve.RawValue.self))
                    index += 1

                    _ = KeyDerivationFunction(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyDerivationFunction.RawValue.self))
                    index += 1
                case .aesCCM, .aesCMAC, .aesEAX, .aesGCM, .aesGMAC:
                    guard index + aesRecordHeaderSizeMin <= response.count else { return .failure(.invalidFormat) }
                    // algorithm parameters
                    // key ID
                    let keyID = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
                    index += 2
                    securityManager.configuration.algorithmKeyID = recordValue

                    _ = MessageType(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self))
                    index += 1

                    let macSize = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
                    index += 1
                    securityManager.configuration.macSize = Int(macSize)

                    if recordType != .aesCMAC {
                        guard index + nonceHeaderSizeMin <= response.count else { return .failure(.invalidFormat) }

                        let nonceType = NonceType(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self)) ?? .sequenceNumberEvenOdd
                        index += 1
                        securityManager.configuration.nonceType = nonceType

                        let nonceSizeOctetsVariable = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
                        index += 1
                        securityManager.configuration.nonceSizeOctetsVariable = Int(nonceSizeOctetsVariable)

                        let nonceSizeOctetsFixed = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
                        index += 1

                        if nonceSizeOctetsFixed > 0 {
                            guard index + nonceSizeOctetsFixed <= response.count else { return .failure(.invalidFormat) }
                            var receivedIVFixedField = response.subdata(in: index..<index+nonceSizeOctetsFixed)
                            index += nonceSizeOctetsFixed
                            // change to big endian to be used within the security manager
                            receivedIVFixedField.reverse()
                            securityManager.configuration.receivedIVFixedField = receivedIVFixedField
                        }
                    }
                case .kdfKeyExchange:
                    guard index + kdfRecordHeaderSize <= response.count else { return .failure(.invalidFormat) }
                    // key derivation key exchange parameters

                    // key ID
                    _ = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
                    index += 2

                    _ = KeyDerivationFunction(rawValue: response[response.startIndex.advanced(by: index)...].to(KeyDerivationFunction.RawValue.self))
                    index += 1
                default:
                    return .failure(.invalidFormat)
                }
            }
        }
        
        return .success(nil)
    }
}

public enum KeyType: UInt8 {
    case oobKey
    case ecdh
    case kdfKeyExchange
    case aesCMAC
    case aesCCM
    case aesEAX
    case aesGCM
    case aesGMAC
}

public enum EllipticCurve: UInt8, Codable {
    case p256
    case p384
    case p512
    case curve25519
    
    var keySizeInBits: Int {
        switch self {
        case .p256, .curve25519:
            return 256
        case .p384:
            return 384
        case .p512:
            return 512
        }
    }

    var ecdhResponseLength: Int {
        switch self {
        case .p256, .curve25519:
            return 69
        case .p384:
            return 101
        case .p512:
            return 133
        }
    }
}

public enum OOBMethod: UInt8 {
    case manufacturer
    case uri
    case machineReadableCode2D
    case barCode
    case nfc
}

public enum MessageType: UInt8 {
    case profileDefinedParameter
    case protectedResourceValue
}

public enum NonceType: UInt8, Codable {
    case profileDefinedParameter
    case sequenceNumberEvenOdd
    case sequenceNumberDifferentFixedParts
}
