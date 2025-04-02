//
//  RestrictionMapDescriptor.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import os.log

// TODO need to rework this

struct RestrictionMapDescriptor: RequestHandler {
    private static let log = OSLog(category: "RestrictionMapDescriptor")
    
    // dictionary keys
    static let opcodeArrayKey = "OpcodeArray"
    static let recordDataSizeKey = "RecordDataSize"
    static let recordsKey = "Records"
    static let recordTypeKey = "RecordType"
    static let recordValueKey = "RecordValue"
    static let securityConfigIDArrayKey = "SecurityConfigIDArray"

    static let recordHeaderSize = 4
    static let mappingHeaderSize = 4

    static var request: Data {
        return RestrictionMapDescriptor.buildControlPointRequest(opcode: ACControlPointOpcode.getRestrictionMapDescriptor)
    }
    
    static func handleResponse(_ response: Data) -> DeviceCommResult<Any?> {
        var records = Array<Dictionary<String, Any>>()
        var index = 1 // skip the opcode
        
        while (index < response.count) {
            guard index + recordHeaderSize <= response.count else { return .failure(.invalidFormat)}
            var record = Dictionary<String, Any>()
            let recordType = RecordTypeRestrictionMap(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self))
            index += 1
            record[recordTypeKey] = recordType
            
            let recordValue = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
            record[recordValueKey] = recordValue
            
            let dataSize = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            record[recordDataSizeKey] = dataSize
            
            if (dataSize > 0) {
                guard index + Int(dataSize) <= response.count else { return .failure(.invalidFormat)}
                var counter = 0;
                var opcodes: [UInt16] = Array()
                var securityIDs: [UInt16] = Array()
                while (dataSize > counter) {
                    guard index + mappingHeaderSize <= response.count else { return .failure(.invalidFormat)}
                    opcodes.append(response[response.startIndex.advanced(by: index + counter)...].to(UInt16.self))
                    counter += 2
                    securityIDs.append(response[response.startIndex.advanced(by: index + counter)...].to(UInt16.self))
                    counter += 2
                }
                index += counter
                record[opcodeArrayKey] = opcodes
                record[securityConfigIDArrayKey] = securityIDs
            }
            records.append(record)
        }
        
        // create response
        let parsedResponse = [recordsKey: records]
        print("parsed response \(parsedResponse)")
        return .success(parsedResponse)
    }
    
}

public enum RecordTypeRestrictionMap: UInt8 {
    case restrictionMapID
    case defaultInformationSecurityConfiguration
    case protectedCharacteristic
    case protectedControlPointProcedures
}
