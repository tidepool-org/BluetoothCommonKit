//
//  ControlPoint.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

protocol ControlPoint: AnyObject, RequestHandler {
    /// an array of commands to send and completion handlers
    var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> { get set }

    var procedureRunning: Bool { get set }
    
    func completeProcedure<O: RawRepresentable>(_ opcode: O) -> Any? where O.RawValue: FixedWidthInteger
    
    func currentProcedureOpcode<O: RawRepresentable>() -> O? where O.RawValue: FixedWidthInteger

    func procedureIDForResponse(_ response: Data) -> ProcedureID?

    func procedureIDForRequest(_ request: Data) -> ProcedureID

    func isExpectedRequest<O: RawRepresentable>(_ request: Data, expectedOpcode: O) -> Bool where O.RawValue: FixedWidthInteger
    
    func nextRequestToSend() -> (Data, Any?)?
}

extension ControlPoint {
    func appendToRequestQueue(_ request: Data, completion: Any?) {
        lockedRequestQueue.mutate { requestQueue in
            requestQueue.append((request, completion))
        }
    }
    
    var hasRequestToSend: Bool {
        nextRequestToSend() != nil
    }
    
    func getPendingProceduresAndReset() ->  [(procedureID: ProcedureID, completion: Any?)] {
        var pendingProcedures:  [(procedureID: ProcedureID, completion: Any?)] = []
        lockedRequestQueue.mutate { requestQueue in
            pendingProcedures = requestQueue.map { (request, completion) in (procedureIDForRequest(request), completion) }
            requestQueue.removeAll()
            procedureRunning = false
        }
        return pendingProcedures
    }

    public func currentProcedureOpcode<O: RawRepresentable>() -> O? where O.RawValue: FixedWidthInteger {
        guard procedureRunning else { return nil }

        guard let currentRequest = lockedRequestQueue.value.first?.request,
              currentRequest.count >= O.RawValue.bitWidth/UInt8.bitWidth
        else { return nil }

        return O(rawValue: currentRequest[currentRequest.startIndex...].to(O.RawValue.self))
    }
    
    public func nextRequestToSend() -> (Data, Any?)? {
        lockedRequestQueue.value.first
    }
    
    public func completeProcedure<O: RawRepresentable>(_ opcode: O) -> Any? where O.RawValue: FixedWidthInteger {
        var completionToReturn: Any? = nil
        lockedRequestQueue.mutate { requestQueue in
            if let (currentRequest, completion) = requestQueue.first,
                isExpectedRequest(currentRequest, expectedOpcode: opcode)
            {
                requestQueue.removeFirst()
                procedureRunning = false
                completionToReturn = completion
            }
        }
        
        return completionToReturn
    }
    
    public func isExpectedRequest<O: RawRepresentable>(_ request: Data, expectedOpcode: O) -> Bool where O.RawValue: FixedWidthInteger {
        guard request.count >= Data(expectedOpcode.rawValue).count else {
            return false
        }
        
        let opcodeElement = request[request.startIndex...].to(O.RawValue.self)
        
        guard let opcode = O(rawValue: opcodeElement) else {
            return false
        }
        
        return expectedOpcode == opcode
    }
}
