//
//  ResourceHandleToUUIDMap.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import os.log

struct ResourceHandleToUUIDMap: RequestHandler {
    private static let log = OSLog(category: "ResourceHandleToUUIDMap")

    static let recordHeaderSize = 4
    static let subattributesHeaderSize = 1
    static let attributesHeaderSize = 1
    static let secondaryServiceHeaderSize = 3
    static let secondaryServiceAttributesHeaderSize = 4
    static let characteristicValueHeaderSize = 3

    static var request: Data {
        return ResourceHandleToUUIDMap.buildControlPointRequest(opcode: ACControlPointOpcode.getResourceHandleToUUIDMap)
    }
    
    static func handleResponse(_ response: Data) -> DeviceCommResult<[CBUUID: UInt16]> {
        var uuidStringToHandleMap: [CBUUID: UInt16] = [:]
        var index = 1 // skip the opcode
        
        while (index < response.count) {
            guard index + recordHeaderSize <= response.count else { return .failure(.invalidFormat) }
            let _ = AttributeType(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self))
            index += 1
            
            let handle = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
            
            let uuidSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
            index += 1

            guard index + uuidSize <= response.count else { return .failure(.invalidFormat) }
            let uuidString = parseUUIDString(uuidSize: uuidSize, index: index, data: response)
            uuidStringToHandleMap[CBUUID(string: uuidString)] = handle
            index += Int(uuidSize)

            guard index + subattributesHeaderSize <= response.count else { return .failure(.invalidFormat) }
            let numberOfSubAttributes = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            
            for _ in 0..<numberOfSubAttributes {
                guard index + attributesHeaderSize <= response.count else { return .failure(.invalidFormat) }
                let attributeType = AttributeType(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self))
                index += 1
                
                if attributeType == AttributeType.secondaryService {
                    guard index + secondaryServiceHeaderSize <= response.count else { return .failure(.invalidFormat) }
                    // parse secondary service handle, uuid, and sub attributes
                    let handle = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
                    index += 2
                    
                    let uuidSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
                    index += 1

                    guard index + uuidSize <= response.count else { return .failure(.invalidFormat) }
                    let uuidString = parseUUIDString(uuidSize: uuidSize, index: index, data: response)
                    uuidStringToHandleMap[CBUUID(string: uuidString)] = handle
                    index += Int(uuidSize)

                    guard index + subattributesHeaderSize <= response.count else { return .failure(.invalidFormat) }
                    let numberOfSubAttributes = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
                    index += 1
                    
                    for _ in 0..<numberOfSubAttributes {
                        guard index + secondaryServiceAttributesHeaderSize <= response.count else { return .failure(.invalidFormat) }
                        let _ = AttributeType(rawValue: response[response.startIndex.advanced(by: index)...].to(UInt8.self))
                        index += 1
                        
                        let handle = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
                        index += 2
            
                        let uuidSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
                        index += 1

                        guard index + uuidSize <= response.count else { return .failure(.invalidFormat) }
                        let uuidString = parseUUIDString(uuidSize: uuidSize, index: index, data: response)
                        uuidStringToHandleMap[CBUUID(string: uuidString)] = handle
                        index += Int(uuidSize)
                    }
                } else {
                    guard index + characteristicValueHeaderSize <= response.count else { return .failure(.invalidFormat) }
                    let handle = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
                    index += 2
                    
                    let uuidSize = Int(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
                    index += 1

                    guard index + uuidSize <= response.count else { return .failure(.invalidFormat) }
                    let uuidString = parseUUIDString(uuidSize: uuidSize, index: index, data: response)
                    uuidStringToHandleMap[CBUUID(string: uuidString)] = handle
                    index += Int(uuidSize)
                }
            }
        }
            
        return .success(uuidStringToHandleMap)
    }

    static func parseUUIDString(uuidSize: Int, index: Int, data: Data) -> String {
        var uuidString = Data(data[data.startIndex.advanced(by: index)..<(index+uuidSize)].reversed()).hexadecimalString
        if uuidSize == 16 {
            // include '-'
            uuidString.insert("-", at: uuidString.index(uuidString.startIndex, offsetBy: 8))
            uuidString.insert("-", at: uuidString.index(uuidString.startIndex, offsetBy: 13))
            uuidString.insert("-", at: uuidString.index(uuidString.startIndex, offsetBy: 18))
            uuidString.insert("-", at: uuidString.index(uuidString.startIndex, offsetBy: 23))
        }
        return uuidString
    }
}

enum AttributeType: UInt8 {
    case primaryService
    case secondaryService
    case characteristicValue
}
