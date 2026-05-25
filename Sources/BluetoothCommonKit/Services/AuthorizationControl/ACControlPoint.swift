//
//  ACControlPoint.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import os.log

public typealias SecurityConfigurationID = UInt16

// MARK: - Support Server Implementation
public protocol ACControlPointDelegate: AnyObject {
    var ecdhKeyID: KeyID { get }
    var algorithmKeyID: KeyID { get }
    var currentKeyID: KeyID? { get }
    func getAuthorizationFeatures() -> Data
    func getRestrictionMap(for restrictionMapID: RestrictionMapID, handleFilter: ResourceHandle) -> Data
    func getRestrictionMapIDList() -> Data
    func getInformationSecurityConfiguration(filter: SecurityConfigurationID) -> Data
    func getKeyDescriptor(filter: KeyID) -> Data
    func resourceHandleToUUIDMap() -> [[CBUUID: ResourceHandle]]
    func invalidateKey()
}

public class ACControlPointCharacteristic: WritableCharacteristic, SegmentationHandler {
    private let log = OSLog(category: "ACControlPointCharacteristic")
    
    var messageQueue: MessagingQueue
    
    public weak var delegate: ACControlPointDelegate?
    
    public var securityManager: SecurityManager!
    
    public var maxRequestSize: Int = 19
    
    public var storedPayloads: [Data] = []
    
    public var lockedSegmentCounter: Locked<UInt8> = Locked(0)
    
    public required init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    public func onWrite(_ request: Data?) -> CBATTError.Code {
        guard let request = request else {
            return .invalidPdu
        }
        
        log.debug("ACSCP request %{public}@", request.hexadecimalString)
        
        let result = checkSegmentedPayload(request)
        switch result {
        case .success(let completeRequest):
            log.debug("complete secure request %{public}@", completeRequest.hexadecimalString)
            
            var index = 0
            let opcode = ACControlPointOpcode(rawValue: completeRequest[completeRequest.startIndex.advanced(by: index)...].to(ACControlPointOpcode.RawValue.self))
            index += 1
            switch opcode {
            case .getAllActiveDescriptors:
                let noFilter: UInt16 = 0xffff
                guard let restrictionMap = delegate?.getRestrictionMap(for: 1, handleFilter: noFilter) else {
                    respond(to: .getAllActiveDescriptors, with: .procedureNotCompleted)
                    break
                }
                var response = Data(ACControlPointOpcode.restrictionMapDescriptorResponse.rawValue)
                response.append(contentsOf: restrictionMap)
                sendResponse(response)
                
                guard let securityConfiguration = delegate?.getInformationSecurityConfiguration(filter: noFilter) else {
                    respond(to: .getAllActiveDescriptors, with: .procedureNotCompleted)
                    break
                }
                response = Data(ACControlPointOpcode.informationSecurityConfigurationDescriptorResponse.rawValue)
                response.append(contentsOf: securityConfiguration)
                sendResponse(response)
                
                guard let keyDescriptor = delegate?.getKeyDescriptor(filter: noFilter) else {
                    respond(to: .getAllActiveDescriptors, with: .procedureNotCompleted)
                    break
                }
                response = Data(ACControlPointOpcode.keyDescriptorResponse.rawValue)
                response.append(contentsOf: keyDescriptor)
                sendResponse(response)
                
                respondWithSuccess(to: .getAllActiveDescriptors)
            case .getRestrictionMapDescriptor:
                guard completeRequest.count == 5 else {
                    respond(to: .getRestrictionMapDescriptor, with: .invalidOperand)
                    break
                }
                
                let restrictionMapID: RestrictionMapID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(RestrictionMapID.self)
                index += 2
                
                let handleFilter: ResourceHandle = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(ResourceHandle.self)
                
                guard restrictionMapID == 1 else {
                    respond(to: .getRestrictionMapDescriptor, with: .parameterOutOfRange)
                    break
                }
                
                guard let restrictionMap = delegate?.getRestrictionMap(for: restrictionMapID, handleFilter: handleFilter) else {
                    respond(to: .getRestrictionMapDescriptor, with: .procedureNotCompleted)
                    break
                }
                var response = Data(ACControlPointOpcode.restrictionMapDescriptorResponse.rawValue)
                response.append(contentsOf: restrictionMap)
                sendResponse(response)
            case .getRestrictionMapIDList:
                guard let restrictionMapIDList = delegate?.getRestrictionMapIDList() else {
                    respond(to: .getRestrictionMapIDList, with: .procedureNotCompleted)
                    break
                }
                var response = Data(ACControlPointOpcode.restrictionMapIDListResponse.rawValue)
                response.append(contentsOf: restrictionMapIDList)
                sendResponse(response)
            case .getResourceHandleToUUIDMap:
                guard let uuidMap = delegate?.resourceHandleToUUIDMap() else {
                    respond(to: .getResourceHandleToUUIDMap, with: .procedureNotCompleted)
                    break
                }
                var response = Data(ACControlPointOpcode.resourceHandleToUUIDMapResponse.rawValue)
                response.append(contentsOf: generateData(from: uuidMap))
                sendResponse(response)
            case .getInformationSecurityConfigurationDescriptor:
                guard completeRequest.count == 4 else {
                    respond(to: .getInformationSecurityConfigurationDescriptor, with: .invalidOperand)
                    break
                }
                
                let filter: SecurityConfigurationID = completeRequest[completeRequest.startIndex...].to(SecurityConfigurationID.self)
                guard let restrictionMap = delegate?.getInformationSecurityConfiguration(filter: filter) else {
                    respond(to: .getInformationSecurityConfigurationDescriptor, with: .procedureNotCompleted)
                    break
                }
                var response = Data(ACControlPointOpcode.informationSecurityConfigurationDescriptorResponse.rawValue)
                response.append(contentsOf: restrictionMap)
                sendResponse(response)
            case .getKeyDescriptor:
                guard completeRequest.count == 4 else {
                    respond(to: .getKeyDescriptor, with: .invalidOperand)
                    break
                }
                
                let filter: KeyID = completeRequest[completeRequest.startIndex...].to(KeyID.self)
                guard let keyDescriptor = delegate?.getKeyDescriptor(filter: filter) else {
                    respond(to: .getKeyDescriptor, with: .procedureNotCompleted)
                    break
                }
                var response = Data(ACControlPointOpcode.keyDescriptorResponse.rawValue)
                response.append(contentsOf: keyDescriptor)
                sendResponse(response)
            case .getCurrentKeyList:
                var response = Data(ACControlPointOpcode.currentKeyListResponse.rawValue)
                guard let keyID = delegate?.currentKeyID else {
                    response.append(UInt8(0))
                    sendResponse(response)
                    break
                }
                response.append(UInt8(1))
                response.append(keyID)
                sendResponse(response)
            case .startKeyExchange:
                guard completeRequest.count == 5 else {
                    respond(to: .startKeyExchange, with: .invalidOperand)
                    break
                }

                let keyID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(KeyID.self)
                index += 2
                let confirmationMethod = StartKeyExchangeConfirmationMethod(rawValue: completeRequest[completeRequest.startIndex.advanced(by: index)...].to(StartKeyExchangeConfirmationMethod.RawValue.self))
                index += 1
                let confirmationAction = StartKeyExchangeConfirmationAction(rawValue: completeRequest[completeRequest.startIndex.advanced(by: index)...].to(StartKeyExchangeConfirmationAction.RawValue.self))
                
                guard keyID == delegate?.ecdhKeyID,
                      (confirmationMethod == .oobNumberStatic || confirmationMethod == .noMethod),
                      confirmationAction == .staticAction
                else {
                    respond(to: .startKeyExchange, with: .procedureNotApplicable)
                    break
                }
                securityManager.generateKeyPair()
                respondWithSuccess(to: .startKeyExchange)
            case .invalidateKey:
                let keyID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(KeyID.self)
                index += 2
                guard keyID == delegate?.currentKeyID else {
                    respond(to: .invalidateKey, with: .procedureNotApplicable)
                    break
                }
                delegate?.invalidateKey()
                respondWithSuccess(to: .invalidateKey)
            case .getACSFeature:
                guard let features = delegate?.getAuthorizationFeatures() else {
                    respond(to: .getACSFeature, with: .procedureNotCompleted)
                    break
                }
                var response = Data(ACControlPointOpcode.acsFeatureResponse.rawValue)
                response.append(contentsOf: features)
                sendResponse(response)
            case .keyExchangeECDH:
                guard completeRequest.count == 69 else { // key size is 32 bytes
                    respond(to: .keyExchangeECDH, with: .invalidOperand)
                    break
                }
                
                let keyID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(KeyID.self)
                index += 2
                
                guard keyID == delegate?.ecdhKeyID else {
                    respond(to: .keyExchangeECDH, with: .procedureNotApplicable)
                    break
                }
                
                // get x-coordinate
                let xCoorSize = Int(completeRequest[completeRequest.startIndex.advanced(by: index)...].to(UInt8.self))
                index += 1
                var receivedPublicKeyDataX = completeRequest.subdata(in: index..<(index+xCoorSize))
                receivedPublicKeyDataX.reverse() // change to big endian
                index += xCoorSize
                
                // get y-coordinate
                let yCoorSize = Int(completeRequest[completeRequest.startIndex.advanced(by: index)...].to(UInt8.self))
                index += 1
                var receivedPublicKeyDataY = completeRequest.subdata(in: index..<(index+yCoorSize))
                receivedPublicKeyDataY.reverse() // change to big endian
                index += yCoorSize
                
                // put the coordinates together
                var receivedPublicKeyData = receivedPublicKeyDataX
                receivedPublicKeyData.append(receivedPublicKeyDataY)
                
                self.securityManager.generateSharedSecret(receivedPublicKeyData: receivedPublicKeyData)
                guard var publicKeyX = self.securityManager.getGeneratedPublicKeyX(),
                      var publicKeyY = self.securityManager.getGeneratedPublicKeyY()
                else {
                    respond(to: .keyExchangeECDH, with: .procedureNotApplicable)
                    break
                }
                
                publicKeyX.reverse() // send as little endian
                publicKeyY.reverse() // send as little endian
                
                var response = Data(ACControlPointOpcode.keyExchangeECDHResponse.rawValue)
                response.append(keyID)
                response.append(UInt8(publicKeyX.count))
                response.append(contentsOf: publicKeyX)
                response.append(UInt8(publicKeyY.count))
                response.append(contentsOf: publicKeyY)
                sendResponse(response)
            case .keyExchangeECDHConfirmationCode:
                guard completeRequest.count == 35 else {
                    respond(to: .keyExchangeECDHConfirmationCode, with: .invalidOperand)
                    break
                }
                
                let keyID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(KeyID.self)
                index += 2
                
                guard keyID == delegate?.ecdhKeyID else {
                    respond(to: .keyExchangeECDHConfirmationCode, with: .procedureNotApplicable)
                    break
                }
                
                let keyConfirmationCodeReceived = completeRequest.subdata(in: index..<completeRequest.count)
                
                self.securityManager.keyConfirmationCodeReceivedLittleEndian = keyConfirmationCodeReceived
                guard let keyConfirmationCode = self.securityManager.calculateGeneratedConfirmationCodeInLittleEndianServer() else {
                    respond(to: .keyExchangeECDHConfirmationCode, with: .procedureNotCompleted)
                    break
                }
                
                var response = Data(ACControlPointOpcode.keyExchangeECDHConfirmationCodeResponse.rawValue)
                response.append(keyID)
                response.append(keyConfirmationCode)
                sendResponse(response)
            case .keyExchangeECDHConfirmationRandomNumber:
                guard completeRequest.count == 35 else {
                    respond(to: .keyExchangeECDHConfirmationRandomNumber, with: .invalidOperand)
                    break
                }

                let keyID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(KeyID.self)
                index += 2
                
                guard keyID == delegate?.ecdhKeyID else {
                    respond(to: .keyExchangeECDHConfirmationRandomNumber, with: .procedureNotApplicable)
                    break
                }
                
                let confirmationRandomNumber = completeRequest.subdata(in: index..<completeRequest.count)
                let (_, validated) = self.securityManager.calculateKeyConfirmationReceivedLittleEndian(clientRandomNumberLittleEndian: confirmationRandomNumber)

                guard validated else {
                    respond(to: .keyExchangeECDHConfirmationRandomNumber, with: .invalidKeyExchangeConfirmationCode)
                    break
                }
                
                var response = Data(ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumberResponse.rawValue)
                response.append(keyID)
                response.append(contentsOf: securityManager.generatedRandomNumberData.reversed())
                sendResponse(response)
                
                // send key exchange successful response
                response = Data(ACControlPointOpcode.keyExchangeResponse.rawValue)
                response.append(keyID)
                response.append(KeyExchangeResponseCode.successful.rawValue)
                sendResponse(response)
            case .keyExchangeKDF:
                guard completeRequest.count == 3 else {
                    respond(to: .keyExchangeKDF, with: .invalidOperand)
                    break
                }
                
                let keyID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(KeyID.self)
                index += 2

                guard keyID == delegate?.ecdhKeyID else {
                    respond(to: .keyExchangeKDF, with: .procedureNotApplicable)
                    break
                }
                
                securityManager.configuration.keyDerivationFunctionConfiguration  = SecurityManager.Configuration.KeyDerivationFunctionConfiguration(keyDerivationFunction: .hkdfSHA256, info: "tidepool".data(using: .utf8)!)
                guard var salt = securityManager.configuration.keyDerivationFunctionConfiguration?.salt,
                      var info = securityManager.configuration.keyDerivationFunctionConfiguration?.info
                else {
                    respond(to: .keyExchangeKDF, with: .procedureNotCompleted)
                    break
                }
                
                let success = securityManager.derivateSharedKey()
                guard success else {
                    respond(to: .keyExchangeKDF, with: .procedureNotCompleted)
                    break
                }
                                
                let saltSize: UInt8 = UInt8(salt.count)
                salt.reverse() // send as little endian
                let infoSize: UInt8 = UInt8(info.count)
                info.reverse() // send as little endian
                
                var response = Data(ACControlPointOpcode.keyExchangeKDFResponse.rawValue)
                response.append(keyID)
                response.append(saltSize)
                response.append(salt)
                response.append(infoSize)
                response.append(info)
                sendResponse(response)
            case .setClientNonceFixed:
                guard completeRequest.count >= 4 else {
                    respond(to: .setClientNonceFixed, with: .invalidOperand)
                    break
                }
                
                let keyID = completeRequest[completeRequest.startIndex.advanced(by: index)...].to(KeyID.self)
                index += 2

                guard keyID == delegate?.algorithmKeyID else {
                    respond(to: .setClientNonceFixed, with: .procedureNotApplicable)
                    break
                }
                
                let fixedNonce = completeRequest.subdata(in: index..<completeRequest.count)
                
                securityManager.configuration.receivedIVFixedField = Data(fixedNonce.reversed())
                respondWithSuccess(to: .setClientNonceFixed)
            case .getATTMTU:
                var response = Data(ACControlPointOpcode.attMTUResponse.rawValue)
                response.append(UInt16(maxRequestSize+1)) // adding segmentation header
                sendResponse(response)
            default:
                log.debug("Command not supported")
                return CBATTError.Code.commandNotSupported
            }
        case .failure(let error):
            log.debug("segmentation error: %{public}@", error.localizedDescription)
        }
        return .success
    }
    
    func generateData(from uuidMap: [[CBUUID: ResourceHandle]]) -> Data {
        var data = Data()
        
        for serviceMap in uuidMap {
            guard let serviceDetails = serviceMap.first else { continue }
            
            data.append(AttributeType.primaryService.rawValue)
            data.append(serviceDetails.value)
            let cbUUID = serviceDetails.key
            let length: UInt8 = UInt8(cbUUID.uuidString.count)/2
            
            guard length == 2,
                  let uuidValue = UInt16(cbUUID.uuidString, radix: 16)
            else {
                fatalError("cbUUID greater than 16 bits not supported")
            }
            data.append(length)
            data.append(uuidValue)
            
            let serviceMap = serviceMap.dropFirst(1)
            guard !serviceMap.isEmpty else { continue }
            
            data.append(UInt8(serviceMap.count))
            for characteristicDetails in serviceMap {
                data.append(AttributeType.characteristicValue.rawValue)
                data.append(characteristicDetails.value)
                
                let cbUUID = characteristicDetails.key
                let length: UInt8 = UInt8(cbUUID.uuidString.count)/2
                guard length == 2,
                      let uuidValue = UInt16(cbUUID.uuidString, radix: 16)
                else {
                    fatalError("cbUUID greater than 16 bits not supported")
                }
                data.append(length)
                data.append(uuidValue)
            }
        }
        
        return data
    }
        
    public func respondWithSuccess(to requestOpcode: ACControlPointOpcode) {
        respond(to: requestOpcode, with: .success)
    }
    
    public func respond(to requestOpcode: ACControlPointOpcode, with responseCode: ACControlPointResponseCode) {
        ConsoleOut.shared.logMessage(message: "\(#function) requestOpcode: \(requestOpcode) responseCode: \(responseCode)")
        var response = Data(ACControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        sendResponse(response)
    }
    
    public func sendResponse(_ response: Data) {
        let responseArray = segmentPayload(response)

        for response in responseArray {
            messageQueue.addQueueItem(
                UUIDValuePair(
                    uuid: ACCharacteristicUUID.controlPoint.cbUUID,
                    value: response
                )
            )
        }
    }
}

// MARK: - Support Client Implementation
public class ACControlPointDataHandler: SegmentationHandler, ControlPoint {
    private let log = OSLog(category: "ACControlPoint")
    
    private(set) public var maxRequestSize: Int

    public func updateMaxRequestSize(_ newValue: Int) {
        maxRequestSize = newValue
    }

    public var maxRequestSizeUpdatedHandler: ((Int) -> Void)?

    public var certificateHandler: ((_ certificateNonce: Int) -> Void)?
    
    public var storedPayloads: [Data] = []
    
    public var lockedSegmentCounter: Locked<UInt8> = Locked(0)

    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])
    
    public private(set) var uuidToHandleMap: [CBUUID: UInt16] = [:]
    
    public var procedureRunning: Bool = false
    
    let securityManager: SecurityManager
    
    var features: FeaturesFlag = []

    public var skipConfirmationCodeAfterKDF = false

    public var willExchangeParentKey = true

    public init(securityManager: SecurityManager, maxRequestSize: Int) {
        self.securityManager = securityManager
        self.maxRequestSize = maxRequestSize
    }
    
    //MARK: - Authorization Control Control Point Responses
    public func handleSegmentedResponse(_ response: Data) -> (result: DeviceCommResult<Any?>, completion: Any?) {
        let result = checkSegmentedPayload(response)
        switch result {
        case .success(let completeResponse):
            log.debug("complete control point response %{public}@", completeResponse.hexadecimalString)
            return handleCompleteResponse(completeResponse)
        case .failure(let error):
            return (.failure(error), nil)
        }
    }

    public func handleCompleteResponse(_ completeResponse: Data) -> (result: DeviceCommResult<Any?>, completion: Any?) {
        // extract opcode
        guard let opcode = ACControlPointOpcode(rawValue: completeResponse[completeResponse.startIndex...].to(ACControlPointOpcode.RawValue.self)) else {
            return (.failure(.opcodeUnknown(completeResponse.hexadecimalString)), nil)
        }

        log.debug("accp parsing %{public}@", String(reflecting: opcode))
        switch opcode {
        case .responseCode:
            guard completeResponse.count == 3,
                  let requestOpcode = ACControlPointOpcode(rawValue: completeResponse[completeResponse.startIndex.advanced(by: 1)...].to(ACControlPointOpcode.RawValue.self)),
                  let responseCode = ACControlPointResponseCode(rawValue: completeResponse[completeResponse.startIndex.advanced(by: 2)...].to(ACControlPointResponseCode.RawValue.self)) else
            {
                return (.failure(.invalidFormat), nil)
            }
            log.debug("request code %{public}@, response code %{public}@", String(describing: requestOpcode) , String(describing: responseCode))
            let completion = completeProcedure(requestOpcode)
            switch responseCode {
            case .success:
                if requestOpcode == .invalidateKey || requestOpcode == .invalidateAllEstablishedSecurity {
                    securityManager.deleteStoredKey()
                }
                return (.success(nil), completion)
            case .opcodeNotSupported:
                return (.failure(.opcodeNotSupported), completion)
            case .invalidOperand:
                return (.failure(.invalidOperand), completion)
            case .procedureNotCompleted:
                return (.failure(.procedureNotCompleted), completion)
            case .parameterOutOfRange:
                return (.failure(.parameterOutOfRange), completion)
            case .procedureNotApplicable:
                return (.failure(.procedureNotApplicable), completion)
            case .abortUnsuccessful:
                return (.failure(.commandFailed("about unsuccessful")), completion)
            case .noRecordsFound:
                return (.failure(.commandFailed("no records found")), completion)
            case .invalidKeyExchangeConfirmationCode:
                return (.failure(.authenticationFailed), completion)
            case .invalidPublicKey:
                return (.failure(.commandFailed("invalid public key")), completion)
            }
        case .acsFeatureResponse:
            let completion = completeProcedure(ACControlPointOpcode.getACSFeature)
            let result = ACFeatureDataHandler.handleResponse(completeResponse)
            switch result {
            case .success(let features):
                self.features = features
                return (.success(features), completion)
            case .failure(let error):
                return (.failure(error), completion)
            }
        case .resourceHandleToUUIDMapResponse:
            let completion = completeProcedure(ACControlPointOpcode.getResourceHandleToUUIDMap)
            let result = ResourceHandleToUUIDMap.handleResponse(completeResponse)
            switch result {
            case .success(let uuidToHandleMap):
                self.uuidToHandleMap = uuidToHandleMap
                return (.success(uuidToHandleMap), completion)
            case .failure(let error):
                return (.failure(error), completion)
            }
        case .restrictionMapIDListResponse:
            let completion = completeProcedure(ACControlPointOpcode.getRestrictionMapIDList)
            return (RestrictionMapIDList.handleResponse(completeResponse), completion)
        case .restrictionMapDescriptorResponse:
            let completion = completeProcedure(ACControlPointOpcode.getRestrictionMapDescriptor)
            return (RestrictionMapDescriptor.handleResponse(completeResponse), completion)
        case .informationSecurityConfigurationDescriptorResponse:
            let completion = completeProcedure(ACControlPointOpcode.getInformationSecurityConfigurationDescriptor)
            return (InformationSecurityConfigurationDescriptor.handleResponse(completeResponse, securityManager: self.securityManager), completion)
        case .keyDescriptorResponse:
            let completion = completeProcedure(ACControlPointOpcode.getKeyDescriptor)
            let result = KeyDescriptor.handleResponse(completeResponse, securityManager: self.securityManager)
            switch result {
            case .success:
                queueSetClientFixedNonceRequest()
                if willExchangeParentKey {
                    if features.contains(.keyFormatClientX509Supported) {
                        // take the x509 path
                        queueGetPHDCertificateNonce()
                    } else {
                        // take the uncompressed key path
                        let keyID = securityManager.configuration.ecdhKeyID
                        securityManager.generateKeyPair()
                        queueStartKeyExchangeRequest(keyID: keyID)
                        queueECDHPublicKeyRequest()
                        queueKeyExchangeKDFRequest(keyID: keyID)
                    }
                }
                willExchangeParentKey = false
                return (.success(nil), completion)
            default:
                return (result, completion)
            }
        case .keyExchangeECDHResponse:
            let completion = completeProcedure(ACControlPointOpcode.keyExchangeECDH)
            return (KeyExchangeECDH.handleResponse(completeResponse, opcode: opcode, securityManager: self.securityManager), completion)
        case .keyExchangeECDHConfirmationCodeResponse:
            let completion = completeProcedure(ACControlPointOpcode.keyExchangeECDHConfirmationCode)
            let result = KeyExchangeECDH.handleResponse(completeResponse, opcode: opcode, securityManager: self.securityManager)
            switch result {
            case .success:
                queueECDHConfirmationRandomNumberRequest()
                return (.success(nil), completion)
            default:
                return (result, completion)
            }
        case .keyExchangeECDHConfirmationRandomNumberResponse:
            let completion = completeProcedure(ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumber)
            return (KeyExchangeECDH.handleResponse(completeResponse, opcode: opcode, securityManager: self.securityManager), completion)
        case .keyExchangeResponse:
            let completion = completeProcedure(ACControlPointOpcode.startKeyExchange)
            return (KeyExchangeECDH.handleResponse(completeResponse, opcode: opcode, securityManager: self.securityManager), completion)
        case .keyExchangeKDFResponse:
            let completion = completeProcedure(ACControlPointOpcode.keyExchangeKDF)
            let result = KeyExchangeECDH.handleResponse(completeResponse, opcode: opcode, securityManager: self.securityManager)
            switch result {
            case .success:
                if skipConfirmationCodeAfterKDF {
                    skipConfirmationCodeAfterKDF = false
                    return (.success(nil), completion)
                }
                guard didQueueECDHConfirmationCodeRequest() else { return (.failure(.deviceNotReady), completion) }
                return (.success(nil), completion)
            default:
                return (result, completion)
            }
        case .attMTUResponse:
            let completion = completeProcedure(ACControlPointOpcode.getATTMTU)
            guard completeResponse.count == 3 else {
                return (.failure(.invalidFormat), completion)
            }
            let attMTU = Int(completeResponse[completeResponse.startIndex.advanced(by: 1)...].to(UInt16.self))
            let newMaxRequestSize = (attMTU - 1) // Minus 1 for segmentation header
            maxRequestSizeUpdatedHandler?(newMaxRequestSize)
            return (.success(attMTU), completion)
        case .phdCertificateNonceResponse:
            let completion = completeProcedure(ACControlPointOpcode.getPHDCertificateNonce)
            guard completeResponse.count == 3 else {
                return (.failure(.invalidFormat), completion)
            }
            let certificateNonce = Int(completeResponse[completeResponse.startIndex.advanced(by: 1)...].to(UInt16.self))
            certificateHandler?(certificateNonce)
            return (.success(nil), completion)
        default:
            log.error("control point response not currently implemented")
            return (.failure(.opcodeNotSupported), nil)
        }
    }
}

//MARK: - Authorization Control Control Point Requests
extension ACControlPointDataHandler: RequestHandler {
    public func sendNextRequest(_ peripherialManager: PeripheralManager, timeout: TimeInterval) {
        guard !procedureRunning else {
            return
        }
        procedureRunning = true
        
        guard !lockedRequestQueue.value.isEmpty else {
            procedureRunning = false
            return
        }
        
        guard let (request, _) = lockedRequestQueue.value.first else {
            procedureRunning = false
            sendNextRequest(peripherialManager, timeout: timeout)
            return
        }

        let requestSegments = segmentPayload(request)
        requestSegments.forEach { requestSegment in
            do {
                try writeACControlPointRequest(peripherialManager, requestSegment: requestSegment, timeout: timeout)
            } catch let error {
                log.error("%{public}@", String(describing: error))
                return
            }
        }
    }
    
    func writeACControlPointRequest(_ peripherialManager: PeripheralManager, requestSegment: Data, timeout: TimeInterval) throws {
        try peripherialManager.writeACControlPointRequest(requestSegment, timeout: timeout)
    }

    public func procedureIDForNextRequest() -> ProcedureID? {
        guard let (request, _) = lockedRequestQueue.value.first,
              request.count >= 1
        else { return nil }

        return procedureIDForRequest(request)
    }

    public func procedureIDForRequest(_ request: Data) -> ProcedureID {
        guard let procedureID = ACControlPointOpcode(rawValue: request[request.startIndex...].to(ACControlPointOpcode.RawValue.self))?.procedureID else {
            fatalError("Opcode does not have a procedure ID \(request.toHexString())")
        }
        return procedureID
    }

    public func procedureIDForResponse(_ response: Data, includesSegmentationHeader: Bool) -> ProcedureID? {
        procedureIDForResponse(includesSegmentationHeader ? response.subdata(in: response.startIndex+1..<response.count) : response)
    }
        
    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in ACControlPointOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    if let requestOpcode = ACControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 1)...].to(ACControlPointOpcode.RawValue.self)) {
                        return  requestOpcode.procedureID
                    }
                default:
                    if let requestOpcode = opcode.requestOpcode {
                        return requestOpcode.procedureID
                    } else {
                        log.error("Opcode does not have a procedure ID")
                        break
                    }
                }
            }
        }
        log.error("Authorization Control Control Point response does not have a procedure ID (raw response: %{public}@)", response.toHexString())
        return nil
    }

    private func isSpecificResponse(expectedOpcode: ACControlPointOpcode, response: Data) -> Bool {
        guard let opcode = ACControlPointOpcode(rawValue: response[response.startIndex...].to(ACControlPointOpcode.RawValue.self)),
              opcode == expectedOpcode else
        {
            return false
        }
        return true
    }

    //MARK: - Create Request
    public func createGetACSFeatureRequest() -> Data {
        ACFeatureDataHandler.request
    }

    public func createGetResourceHandleToUUIDMapRequest() -> Data {
        ResourceHandleToUUIDMap.request
    }

    public func createGetRestrictionMapIDListRequest() -> Data {
        RestrictionMapIDList.request
    }

    public func createGetAllActiveDescriptorsRequest() -> Data {
        ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.getAllActiveDescriptors)
    }
    
    public func createECDHPublicKeyRequest() -> Data? {
        KeyExchangeECDH.ecdhRequestUncompressedPlain(securityManager: securityManager)
    }
    
    public func createECDHPublicKeyRequest(certificateData: Data) -> Data {
        KeyExchangeECDH.ecdhRequestCertificate(securityManager: securityManager, certificateData: certificateData)
    }

    public func createECDHConfirmationCodeRequest() -> Data? {
        KeyExchangeECDH.ecdhConfirmationCodeRequest(securityManager: securityManager)
    }

    public func createGetATTMTURequest() -> Data {
        ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.getATTMTU)
    }

    public func createKeyExchangeKDFRequest(keyID: KeyID) -> Data {
        let operand = Data(keyID)
        return ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeKDF, operand: operand)
    }
    
    public func createSetClientNonceFixedRequest() -> Data {
        KeyExchangeECDH.setClientFixedNonce(securityManager: securityManager)
    }

    public func createGetPHDCertificateNonceRequest() -> Data {
        ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.getPHDCertificateNonce)
    }
    
    public func createInitiatePairingRequest() -> Data {
        return ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.initiatePairing)
    }

    public func createInvalidateKeyRequest() -> Data {
        let operand = Data(securityManager.configuration.ecdhKeyID)
        return ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.invalidateKey, operand: operand)
    }
    
    public func createInvalidateAllEstablishedSecurityRequest() -> Data {
        return ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.invalidateAllEstablishedSecurity)
    }
    
    public func createStartKeyExchangeRequest(keyID: KeyID) -> Data {
        var operand = Data(keyID)
        operand.append(StartKeyExchangeConfirmationMethod.noMethod.rawValue)
        operand.append(StartKeyExchangeConfirmationAction.staticAction.rawValue)

        return ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.startKeyExchange, operand: operand)
    }

    public func createECDHConfirmationRandomNumberRequest() -> Data {
        var operand = Data(securityManager.configuration.ecdhKeyID)
        // BT transmittion expects little endian byte order
        operand.append(Data(securityManager.generatedRandomNumberData.reversed()))

        return ACControlPointDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumber, operand: operand)
    }

    //MARK: - Queue Request
    public func queueConfigurationRequests(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetACSFeatureRequest(), completion: nil)
        appendToRequestQueue(createGetATTMTURequest(), completion: nil)
        appendToRequestQueue(createGetResourceHandleToUUIDMapRequest(), completion: nil)
        appendToRequestQueue(createGetRestrictionMapIDListRequest(), completion: nil)
        appendToRequestQueue(createGetAllActiveDescriptorsRequest(), completion: completion)
    }

    func didQueueECDHConfirmationCodeRequest(completion: ProcedureResultCompletion? = nil) -> Bool {
        guard let request = createECDHConfirmationCodeRequest() else { return false }
        appendToRequestQueue(request, completion: completion)
        return true
    }
    
    public func queueInitiatePairingRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createInitiatePairingRequest(), completion: completion)
    }

    public func queueInvalidateKeyRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createInvalidateKeyRequest(), completion: completion)
    }
    
    public func queueInvalidateAllEstablishedSecurityRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createInvalidateAllEstablishedSecurityRequest(), completion: completion)
    }

    public func queueKeyExchangeKDFRequest(keyID: KeyID? = nil, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createKeyExchangeKDFRequest(keyID: keyID ?? securityManager.configuration.ecdhKeyID), completion: completion)
    }

    public func queueSetClientFixedNonceRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createSetClientNonceFixedRequest(), completion: completion)
    }

    func queueGetPHDCertificateNonce(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetPHDCertificateNonceRequest(), completion: completion)
    }
    
    public func queueECDHPublicKeyRequest(completion: ProcedureResultCompletion? = nil) {
        guard let request = createECDHPublicKeyRequest() else {
            completion?(.failure(.deviceNotReady))
            return
        }
        appendToRequestQueue(request, completion: completion)
    }
    
    public func queueECDHPublicKeyRequest(certificateData: Data, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createECDHPublicKeyRequest(certificateData: certificateData), completion: completion)
    }

    public func queueStartKeyExchangeRequest(keyID: KeyID? = nil, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createStartKeyExchangeRequest(keyID: keyID ?? securityManager.configuration.ecdhKeyID), completion: completion)
    }

    func queueECDHConfirmationRandomNumberRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createECDHConfirmationRandomNumberRequest(), completion: completion)
    }
}

//MARK: - Write Authorization Control Control Point Request
extension PeripheralManager {
    func writeACControlPointRequest(_ request: Data, type: CBCharacteristicWriteType = .withResponse, timeout: TimeInterval) throws {
        guard let characteristic = peripheral?.getACSCharacteristicWithUUID(.controlPoint) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            try writeValue(request, for: characteristic, type: type, timeout: timeout)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}

//MARK: - Enumerations
public enum ACControlPointOpcode: UInt8, CaseIterable {
    case responseCode = 0x00
    case getAllActiveDescriptors = 0x01
    case getRestrictionMapDescriptor = 0x02
    case restrictionMapDescriptorResponse = 0x03
    case getRestrictionMapIDList = 0x04
    case restrictionMapIDListResponse = 0x05
    case activateRestrictionMap = 0x06
    case getResourceHandleToUUIDMap = 0x07
    case resourceHandleToUUIDMapResponse = 0x08
    case getServiceCharacteristicUUIDsCharacteristicResourceHandle = 0x09
    case serviceCharacteristicUUIDsCharacteristicResourceHandleResponse = 0x0a
    case getInformationSecurityConfigurationDescriptor = 0x0b
    case informationSecurityConfigurationDescriptorResponse = 0x0c
    case getKeyDescriptor = 0x0d
    case keyDescriptorResponse = 0x0e
    case getCurrentKeyList = 0x0f
    case currentKeyListResponse = 0x10
    case startKeyExchange = 0x11
    case keyExchangeResponse = 0x12
    case invalidateAllEstablishedSecurity = 0x13
    case invalidateKey = 0x14
    case abort = 0x15
    case setAvailabilityOfInformationSecurityControls = 0x16
    case getKeyURI = 0x17
    case keyURIResponse = 0x18
    case getACSFeature = 0x19
    case acsFeatureResponse = 0x1a
    case keyExchangeECDH = 0x1b
    case keyExchangeECDHResponse = 0x1c
    case keyExchangeECDHConfirmationCode = 0x1d
    case keyExchangeECDHConfirmationCodeResponse = 0x1e
    case keyExchangeECDHConfirmationRandomNumber = 0x1f
    case keyExchangeECDHConfirmationRandomNumberResponse = 0x20
    case keyExchangeKDF = 0x21
    case keyExchangeKDFResponse = 0x22
    case setClientNonceFixed = 0x23
    case getATTMTU = 0xdd
    case attMTUResponse = 0xde
    case initiatePairing = 0xdf
    case getPHDCertificateNonce = 0xe0
    case phdCertificateNonceResponse = 0xe1

    var procedureID: ProcedureID {
        String("AuthorizationControlControlPoint.\(self.debugDescription)")
    }

    var requestOpcode: ACControlPointOpcode? {
        switch self {
        case .restrictionMapDescriptorResponse: return .getRestrictionMapDescriptor
        case .restrictionMapIDListResponse: return .getRestrictionMapIDList
        case .resourceHandleToUUIDMapResponse: return .getResourceHandleToUUIDMap
        case .serviceCharacteristicUUIDsCharacteristicResourceHandleResponse: return .getServiceCharacteristicUUIDsCharacteristicResourceHandle
        case .informationSecurityConfigurationDescriptorResponse: return .getInformationSecurityConfigurationDescriptor
        case .keyDescriptorResponse: return .getKeyDescriptor
        case .currentKeyListResponse: return .getCurrentKeyList
        case .keyExchangeResponse: return .startKeyExchange
        case .keyURIResponse: return .getKeyURI
        case .acsFeatureResponse: return .getACSFeature
        case .keyExchangeECDHResponse: return .keyExchangeECDH
        case .keyExchangeECDHConfirmationCodeResponse: return .keyExchangeECDHConfirmationCode
        case .keyExchangeECDHConfirmationRandomNumberResponse: return .keyExchangeECDHConfirmationRandomNumber
        case .keyExchangeKDFResponse: return .keyExchangeKDF
        case .attMTUResponse: return .getATTMTU
        case .phdCertificateNonceResponse: return .getPHDCertificateNonce
        default:
            return nil
        }
    }

    static var responseOpcodes: [ACControlPointOpcode] {
        return [
            .responseCode,
            .restrictionMapDescriptorResponse,
            .restrictionMapIDListResponse,
            .resourceHandleToUUIDMapResponse,
            .serviceCharacteristicUUIDsCharacteristicResourceHandleResponse,
            .informationSecurityConfigurationDescriptorResponse,
            .keyDescriptorResponse,
            .currentKeyListResponse,
            .keyExchangeResponse,
            .keyURIResponse,
            .acsFeatureResponse,
            .keyExchangeECDHResponse,
            .keyExchangeECDHConfirmationCodeResponse,
            .keyExchangeECDHConfirmationRandomNumberResponse,
            .keyExchangeKDFResponse,
            .attMTUResponse,
            .phdCertificateNonceResponse,
        ]
    }

    private var debugDescription: String {
        switch self {
        case .responseCode: return "responseCode"
        case .getAllActiveDescriptors: return "getAllActiveDescriptors"
        case .getRestrictionMapDescriptor: return "getRestrictionMapDescriptor"
        case .restrictionMapDescriptorResponse: return "restrictionMapDescriptorResponse"
        case .getRestrictionMapIDList: return "getRestrictionMapIDList"
        case .restrictionMapIDListResponse: return "restrictionMapIDListResponse"
        case .activateRestrictionMap: return "activateRestrictionMap"
        case .getResourceHandleToUUIDMap: return "getResourceHandleToUUIDMap"
        case .resourceHandleToUUIDMapResponse: return "resourceHandleToUUIDMapResponse"
        case .getServiceCharacteristicUUIDsCharacteristicResourceHandle: return "getServiceCharacteristicUUIDsCharacteristicResourceHandle"
        case .serviceCharacteristicUUIDsCharacteristicResourceHandleResponse: return "serviceCharacteristicUUIDsCharacteristicResourceHandleResponse"
        case .getInformationSecurityConfigurationDescriptor: return "getInformationSecurityConfigurationDescriptor"
        case .informationSecurityConfigurationDescriptorResponse: return "informationSecurityConfigurationDescriptorResponse"
        case .getKeyDescriptor: return "getKeyDescriptor"
        case .keyDescriptorResponse: return "keyDescriptorResponse"
        case .getCurrentKeyList: return "getCurrentKeyList"
        case .currentKeyListResponse: return "currentKeyListResponse"
        case .startKeyExchange: return "startKeyExchange"
        case .keyExchangeResponse: return "keyExchangeResponse"
        case .invalidateAllEstablishedSecurity: return "invalidateAllEstablishedSecurity"
        case .invalidateKey: return "invalidateKey"
        case .abort: return "abort"
        case .setAvailabilityOfInformationSecurityControls: return "setAvailabilityOfInformationSecurityControls"
        case .getKeyURI: return "getKeyURI"
        case .keyURIResponse: return "keyURIResponse"
        case .getACSFeature: return "getACSFeature"
        case .acsFeatureResponse: return "acsFeatureResponse"
        case .keyExchangeECDH: return "keyExchangeECDH"
        case .keyExchangeECDHResponse: return "keyExchangeECDHResponse"
        case .keyExchangeECDHConfirmationCode: return "keyExchangeECDHConfirmationCode"
        case .keyExchangeECDHConfirmationCodeResponse: return "keyExchangeECDHConfirmationCodeResponse"
        case .keyExchangeECDHConfirmationRandomNumber: return "keyExchangeECDHConfirmationRandomNumber"
        case .keyExchangeECDHConfirmationRandomNumberResponse: return "keyExchangeECDHConfirmationRandomNumberResponse"
        case .keyExchangeKDF: return "keyExchangeKDF"
        case .keyExchangeKDFResponse: return "keyExchangeKDFResponse"
        case .setClientNonceFixed: return "setClientNonceFixed"
        case .getATTMTU: return "getATTMTU"
        case .attMTUResponse: return "attMTUResponse"
        case .initiatePairing: return "initiatePairing"
        case .getPHDCertificateNonce: return "getPHDCertificateNonce"
        case .phdCertificateNonceResponse: return "phdCertificateNonceResponse"
        }
    }
}

public enum ACControlPointResponseCode: UInt8 {
    case success = 0x01
    case opcodeNotSupported = 0x02
    case invalidOperand = 0x03
    case procedureNotCompleted = 0x04
    case parameterOutOfRange = 0x05
    case procedureNotApplicable = 0x06
    case abortUnsuccessful = 0x07
    case noRecordsFound = 0x08
    case invalidKeyExchangeConfirmationCode = 0x09
    case invalidPublicKey = 0x0a
}
