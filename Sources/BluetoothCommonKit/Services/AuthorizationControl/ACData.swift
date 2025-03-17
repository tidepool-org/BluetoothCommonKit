//
//  ACData.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import os.log

public protocol ACDataDelegate: AnyObject {
    func didEncounterE2ECounterError()
    func didEncounterSegmentCounterError()
}

public class ACData: SegmentationHandler {
    
    private let log = OSLog(category: "ACData")
    
    private let securityManager: SecurityManager
    
    public weak var delegate: ACDataDelegate?
    
    private(set) public var maxRequestSize: Int

    public func updateMaxRequestSize(_ newValue: Int) {
        maxRequestSize = newValue
    }
    
    public var storedResponses: [Data] = []
    
    public var lockedSegmentCounter: Locked<UInt8> = Locked(0)
    
    public init(securityManager: SecurityManager, maxRequestSize: Int) {
        self.securityManager = securityManager
        self.maxRequestSize = maxRequestSize
    }
    
    public func sendRequest(_ request: Data?,
                            resourceHandle: ResourceHandle,
                            peripherialManager: PeripheralManager,
                            timeout: TimeInterval) -> DeviceCommResult<Void>
    {
        let result = prepareSecureRequestSegments(request, resourceHandle: resourceHandle)
        switch result {
        case .success(let secureRequestSegments):
            var commError: DeviceCommError? = nil
            secureRequestSegments.forEach { requestSegment in
                do {
                    try writeACDataRequest(peripherialManager, request: requestSegment, timeout: timeout)
                } catch let error {
                    log.error("%{public}@", String(describing: error))
                    if let peripheralManagerError = error as? PeripheralManagerError {
                        switch peripheralManagerError {
                        case let .cbPeripheralError(error):
                            guard let cbAttError = (error as? CBATTError) else { return }
                            if cbAttError.isE2ECounterError() {
                                delegate?.didEncounterE2ECounterError()
                                commError = .commandFailed("E2E Counter Error")
                            } else if cbAttError.isSegmentCounterError() {
                                delegate?.didEncounterSegmentCounterError()
                                commError = .commandFailed("Segment Counter Error")
                            } else if cbAttError.isProcedureAlreadyInProgress() {
                                commError = .procedureInProgress
                            }
                        default:
                            return
                        }
                    }
                }
            }
            guard let commError = commError else {
                return .success
            }
            return .failure(commError)
        case .failure(let error):
            return .failure(.securityManagerError(error))
        }
    }

    func writeACDataRequest(_ peripherialManager: PeripheralManager, request: Data, timeout: TimeInterval) throws {
        try peripherialManager.writeACDataRequest(request, timeout: timeout)
    }
    
    func prepareSecureRequestSegments(_ request: Data?,
                                      resourceHandle: ResourceHandle) -> Result<[Data], SecurityManagerError>
    {
        var requestToProtectedResource = Data(resourceHandle)
        if let request = request {
            requestToProtectedResource.append(request)
        }
        let result = securityManager.protectRequest(requestToProtectedResource)
        switch result {
        case .success(let secureRequest):
            let secureRequestSegments = segmentRequest(secureRequest)
            return .success(secureRequestSegments)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func handleSecureResponse(_ secureResponse: Data) -> Result<ResourceResponse, DeviceCommError> {
        let result = checkResponseSegment(secureResponse)
        switch result {
        case .success(let completeSecureResponse):
            log.debug("complete secure response %{public}@", completeSecureResponse.hexadecimalString)

            let decryptionResult = securityManager.decryptSecureResponse(completeSecureResponse)
            switch decryptionResult {
            case .success(let response):
                log.debug("response %{public}@", response.toHexString())

                let resourceHandle: ResourceHandle = response[response.startIndex...].to(UInt16.self)
                return .success(ResourceResponse(resourceHandle: resourceHandle, response: response.dropFirst(2)))
            case .failure(let error):
                return .failure(.securityManagerError(error))
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

//MARK: - Write Authorization Control Control Point Request
extension PeripheralManager {
    func writeACDataRequest(_ request: Data, type: CBCharacteristicWriteType = .withResponse, timeout: TimeInterval) throws {
        guard let characteristic = peripheral?.getACSCharacteristicWithUUID(.dataIn) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            try writeValue(request, for: characteristic, type: type, timeout: timeout)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}
