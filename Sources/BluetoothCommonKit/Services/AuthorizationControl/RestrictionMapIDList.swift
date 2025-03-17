//
//  RestrictionMapIDList.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct RestrictionMapIDList: RequestHandler {

    static let mappingHeaderSize = 4

    static var request: Data {
        return RestrictionMapIDList.buildControlPointRequest(opcode: ACControlPointOpcode.getRestrictionMapIDList)
    }
    
    static func handleResponse(_ response: Data) -> DeviceCommResult<Void> {
        var restrictionMapIDs = Array<UInt16>()
        var securityIDs = Array<UInt16>()
        var index = 1 // skip opcode
        
        while (index < response.count) {
            guard index + mappingHeaderSize <= response.count else { return .failure(.invalidFormat)}
            restrictionMapIDs.append(response[response.startIndex.advanced(by: index)...].to(UInt16.self))
            index += 2
            securityIDs.append(response[response.startIndex.advanced(by: index)...].to(UInt16.self))
            index += 2
        }
        
        return .success
    }
    
}
