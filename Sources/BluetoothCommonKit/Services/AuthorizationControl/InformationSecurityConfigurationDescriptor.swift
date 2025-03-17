//
//  InformationSecurityConfigurationDescriptor.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct InformationSecurityConfigurationDescriptor: RequestHandler {
    static let recordHeaderSize = 4
    static let keyIDSize = 2

    static var request: Data {
        return InformationSecurityConfigurationDescriptor.buildControlPointRequest(opcode: ACControlPointOpcode.getInformationSecurityConfigurationDescriptor)
    }
    
    static func handleResponse(_ response: Data, securityManager: SecurityManager) -> DeviceCommResult<Void> {
        var index = 1 // skip opcode
        
        while index < response.count {
            guard index + recordHeaderSize <= response.count else { return .failure(.invalidFormat) }
            let recordType = RecordTypeSecurityConfiguration(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self))
            index += 1
            
            let recordValue = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
            
            let dataSize = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            
            if dataSize > 0 {
                guard index + Int(dataSize) <= response.count else { return .failure(.invalidFormat) }
                if recordType == RecordTypeSecurityConfiguration.informationSecurityConfigurationID {
                    // parse security configuration
                    let numOfControls = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
                    index += 1;
                    
                    var expectKeyID = false
                    var securityControls: [SecurityControlType] = []
                    for _ in 0..<numOfControls {
                        guard index + Int(numOfControls) <= response.count else { return .failure(.invalidFormat) }
                        guard let securityControlType = SecurityControlType(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self)) else {
                            return .failure(.invalidOperand)
                        }
                        index += 1
                        securityControls.append(securityControlType)
                        
                        if securityControlType == SecurityControlType.authenticatedATTPacket
                            || securityControlType == SecurityControlType.authenticatedEncryptedATTPacket
                            || securityControlType == SecurityControlType.authenticatedEncryptedATTPacketWithAssociatedData
                            || securityControlType == SecurityControlType.encryptedATTPacket
                        {
                            expectKeyID = true;
                        }
                    }
                    if expectKeyID {
                        guard index + keyIDSize <= response.count else { return .failure(.invalidFormat) }
                        _ = response[response.startIndex.advanced(by: index)...].to(KeyID.self)
                        index += 2
                    }
                    securityManager.configuration.securityConfigurationID = recordValue
                    securityManager.configuration.securityControls = securityControls
                }
            }
        }
        
        return .success
    }
    
}

enum RecordTypeSecurityConfiguration: UInt8 {
    case informationSecurityConfigurationID
}

enum SecurityControlType: UInt8, Codable {
    case nonce
    case authenticatedATTPacket
    case encryptedATTPacket
    case authenticatedEncryptedATTPacket
    case authenticatedEncryptedATTPacketWithAssociatedData
    case unencryptedATTPacket
    case mac
}
