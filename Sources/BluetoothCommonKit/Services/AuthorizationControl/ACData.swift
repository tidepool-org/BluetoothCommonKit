//
//  ACData.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import os.log

// MARK: - Support Server Implementation
public protocol ACDataCharacteristicDelegate: AnyObject {
    func processRequest(_ request: Data, for resourceHandle: ResourceHandle)
}

public class ACDataCharacteristic: SegmentationHandler {
    private let log = OSLog(category: "ACDataCharacteristic")
    
    public weak var delegate: ACDataCharacteristicDelegate?
    
    public var maxRequestSize: Int
    
    public var storedPayloads: [Data] = []
    
    public var lockedSegmentCounter: Locked<UInt8> = Locked(0)
    
    var messageQueue: MessagingQueue
    
    var securityManager: SecurityManager
    
    var status : ACStatusCharacteristic
    
    public init(messageQueue: MessagingQueue,
                securityManager: SecurityManager,
                status: ACStatusCharacteristic,
                maxRequestSize: Int)
    {
        self.messageQueue = messageQueue
        self.securityManager = securityManager
        self.status = status
        self.maxRequestSize = maxRequestSize
    }
 
    public func onWrite(_ secureRequest: Data?) -> CBATTError.Code {
        guard let secureRequest = secureRequest else {
            return .invalidPdu
        }
        
        guard messageQueue.gattServer.isCharacteristicSubscribed( ACCharacteristicUUID.dataOutIndicate.cbUUID) ?? false else {
            return .improperlyConfigured
        }
        
        guard status.currentRestrictionMapID != 0 else {
            log.debug("resources are not protected. No reason to use the data characteristic")
            return .requestNotSupported
        }
        
        let result = checkSegmentedPayload(secureRequest)
        switch result {
        case .success(let completeSecureRequest):
            log.debug("complete secure request %{public}@", completeSecureRequest.hexadecimalString)
            
            let decryptionResult = securityManager.decryptSecurePayload(completeSecureRequest)
            switch decryptionResult {
            case .success(let request):
                log.debug("request %{public}@", request.toHexString())
                
                let resourceHandle: ResourceHandle = request[request.startIndex...].to(UInt16.self)
                
                delegate?.processRequest(request.dropFirst(2), for: resourceHandle)
            case .failure(let error):
                guard error != .incorrectSecurityConfiguration else {
                    return .incorrectSecurityConfigurationCode
                }
                
                log.debug("decryption failed %{public}@", error.localizedDescription)
            }
        case .failure(let error):
            log.debug("segmentation error: %{public}@", error.localizedDescription)
        }
        return .success
    }
    
    func prepareSecureMessageSegments(_ message: Data?,
                                      resourceHandle: ResourceHandle) -> Result<[Data], SecurityManagerError>
    {
        var requestToProtectedResource = Data(resourceHandle)
        if let message = message {
            requestToProtectedResource.append(message)
        }
        let result = securityManager.protectRequest(requestToProtectedResource)
        switch result {
        case .success(let secureRequest):
            let secureRequestSegments = segmentPayload(secureRequest)
            return .success(secureRequestSegments)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func sendSecureIndication(_ message: Data, to resourceHandle: ResourceHandle) {
        if messageQueue.gattServer.isCharacteristicSubscribed(ACCharacteristicUUID.dataOutIndicate.cbUUID) ?? false {
            let result = prepareSecureMessageSegments(message, resourceHandle: resourceHandle)
            switch result {
            case .success(let secureSegments):
                for secureSegment in secureSegments {
                    let valuepair = UUIDValuePair(
                        uuid: ACCharacteristicUUID.dataOutIndicate.cbUUID,
                        value: secureSegment
                    )
                    log.debug("%{public}@", valuepair.description)
                    messageQueue.addQueueItem(valuepair)
                }
            case .failure(let error):
                log.error("Could not prepare secure messages %{public}@", String(describing: error))
            }
        } else {
            log.debug("AC Data Out Indicate characteristic is not configured for indications")
        }
    }
    
    public func sendSecureNotification(_ message: Data, to resourceHandle: ResourceHandle) {
        if messageQueue.gattServer.isCharacteristicSubscribed(ACCharacteristicUUID.dataOutNotify.cbUUID) ?? false {
            let result = prepareSecureMessageSegments(message, resourceHandle: resourceHandle)
            switch result {
            case .success(let secureSegments):
                for secureSegment in secureSegments {
                    let valuepair = UUIDValuePair(
                        uuid: ACCharacteristicUUID.dataOutNotify.cbUUID,
                        value: secureSegment
                    )
                    log.debug("%{public}@", valuepair.description)
                    messageQueue.addQueueItem(valuepair)
                }
            case .failure(let error):
                log.error("Could not prepare secure messages %{public}@", String(describing: error))
            }
        } else {
            log.debug("AC Data Out Notify characteristic is not configured for notifications")
        }
    }
}

// MARK: - Support Client Implementation
public protocol ACDataDataHandlerDelegate: AnyObject {
    func didEncounterE2ECounterError()
    func didEncounterSegmentCounterError()
}

public class ACDataDataHandler: SegmentationHandler {
    
    private let log = OSLog(category: "ACData")
    
    private let securityManager: SecurityManager
    
    public weak var delegate: ACDataDataHandlerDelegate?
    
    private(set) public var maxRequestSize: Int
    
    public func updateMaxRequestSize(_ newValue: Int) {
        maxRequestSize = newValue
    }
    
    public var storedPayloads: [Data] = []
    
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
    
    public func prepareSecureRequestSegments(_ request: Data?,
                                             resourceHandle: ResourceHandle) -> Result<[Data], SecurityManagerError>
    {
        var requestToProtectedResource = Data(resourceHandle)
        if let request = request {
            requestToProtectedResource.append(request)
        }
        let result = securityManager.protectRequest(requestToProtectedResource)
        switch result {
        case .success(let secureRequest):
            let secureRequestSegments = segmentPayload(secureRequest)
            return .success(secureRequestSegments)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func handleSecureResponse(_ secureResponse: Data) -> Result<ResourceResponse, DeviceCommError> {
        let result = checkSegmentedPayload(secureResponse)
        switch result {
        case .success(let completeSecureResponse):
            log.debug("complete secure response %{public}@", completeSecureResponse.hexadecimalString)
            
            let decryptionResult = securityManager.decryptSecurePayload(completeSecureResponse)
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
