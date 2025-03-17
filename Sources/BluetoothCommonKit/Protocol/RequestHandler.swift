//
//  RequestHandler.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

protocol RequestHandler {
    static func buildControlPointRequest<O: RawRepresentable>(opcode: O, operand: Data?) -> Data where O.RawValue: FixedWidthInteger

    func responseOpcode<O: RawRepresentable>(_ response: Data) -> O? where O.RawValue: FixedWidthInteger
}

extension RequestHandler {
    static func buildControlPointRequest<O: RawRepresentable>(opcode: O, operand: Data? = nil) -> Data where O.RawValue: FixedWidthInteger {
        var request = Data(opcode.rawValue)
        
        if let operand = operand {
            request.append(operand)
        }
        return request
    }

    func responseOpcode<O: RawRepresentable>(_ response: Data) -> O? where O.RawValue: FixedWidthInteger {
        O(rawValue: response[response.startIndex...].to(O.RawValue.self))
    }
}
