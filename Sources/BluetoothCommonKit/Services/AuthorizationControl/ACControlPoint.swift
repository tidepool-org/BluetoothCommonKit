//
//  ACControlPoint.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import os.log

public class ACControlPoint: SegmentationHandler, ControlPoint {
    
    private let log = OSLog(category: "ACControlPoint")
    
    private(set) public var maxRequestSize: Int

    public func updateMaxRequestSize(_ newValue: Int) {
        maxRequestSize = newValue
    }

    public var maxRequestSizeUpdatedHandler: ((Int) -> Void)?

    public var certificateHandler: ((_ certificateNonce: Int) -> Void)?
    
    public var storedResponses: [Data] = []
    
    public var lockedSegmentCounter: Locked<UInt8> = Locked(0)

    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])
    
    public private(set) var uuidToHandleMap: [CBUUID: UInt16] = [:]
    
    public var procedureRunning: Bool = false
    
    let securityManager: SecurityManager
    
    public init(securityManager: SecurityManager, maxRequestSize: Int) {
        self.securityManager = securityManager
        self.maxRequestSize = maxRequestSize
    }
    
    //MARK: - Authorization Control Control Point Responses
    public func handleSegmentedResponse(_ response: Data) -> (result: DeviceCommResult<Void>, completion: Any?) {
        let result = checkResponseSegment(response)
        switch result {
        case .success(let completeResponse):
            log.debug("complete control point response %{public}@", completeResponse.hexadecimalString)
            return handleCompleteResponse(completeResponse)
        case .failure(let error):
            return (.failure(error), nil)
        }
    }

    public func handleCompleteResponse(_ completeResponse: Data) -> (result: DeviceCommResult<Void>, completion: Any?) {
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
                if requestOpcode == .invalidateKey {
                    securityManager.deleteStoredKey()
                }
                return (.success, completion)
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
            let result = ACFeature.handleResponse(completeResponse)
            switch result {
            case .success(_):
                return (.success, completion)
            case .failure(let error):
                return (.failure(error), completion)
            }
        case .resourceHandleToUUIDMapResponse:
            let completion = completeProcedure(ACControlPointOpcode.getResourceHandleToUUIDMap)
            let result = ResourceHandleToUUIDMap.handleResponse(completeResponse)
            switch result {
            case .success(let uuidToHandleMap):
                self.uuidToHandleMap = uuidToHandleMap
                return (.success , completion)
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
                queueGetPHDCertificateNonce()
                return (.success, completion)
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
                return (.success, completion)
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
                guard didQueueECDHConfirmationCodeRequest() else { return (.failure(.deviceNotReady), completion) }
                return (.success, completion)
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
            return (.success, completion)
        case .phdCertificateNonceResponse:
            let completion = completeProcedure(ACControlPointOpcode.getPHDCertificateNonce)
            guard completeResponse.count == 3 else {
                return (.failure(.invalidFormat), completion)
            }
            let certificateNonce = Int(completeResponse[completeResponse.startIndex.advanced(by: 1)...].to(UInt16.self))
            certificateHandler?(certificateNonce)
            return (.success, completion)
        default:
            log.error("control point response not currently implemented")
            return (.failure(.opcodeNotSupported), nil)
        }

    }

    func writeACControlPointRequest(_ peripherialManager: PeripheralManager, requestSegment: Data, timeout: TimeInterval) throws {
        try peripherialManager.writeACControlPointRequest(requestSegment, timeout: timeout)
    }

    func createStartKeyExchangeRequest() -> Data {
        var operand = Data(securityManager.configuration.ecdhKeyID)
        operand.append(StartKeyExchangeConfirmationMethod.oobNumberStatic.rawValue)
        operand.append(StartKeyExchangeConfirmationAction.staticAction.rawValue)

        return ACControlPoint.buildControlPointRequest(opcode: ACControlPointOpcode.startKeyExchange, operand: operand)
    }

    func createECDHConfirmationRandomNumberRequest() -> Data {
        var operand = Data(securityManager.configuration.ecdhKeyID)
        // BT transmittion expects little endian byte order
        operand.append(Data(securityManager.clientRandomNumberData.reversed()))

        return ACControlPoint.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumber, operand: operand)
    }

    public func queueStartKeyExchangeRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createStartKeyExchangeRequest(), completion: completion)
    }

    func queueECDHConfirmationRandomNumberRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createECDHConfirmationRandomNumberRequest(), completion: completion)
    }
}

//MARK: - Authorization Control Control Point Requests
extension ACControlPoint: RequestHandler {
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

        let requestSegments = segmentRequest(request)
        requestSegments.forEach { requestSegment in
            do {
                try writeACControlPointRequest(peripherialManager, requestSegment: requestSegment, timeout: timeout)
            } catch let error {
                log.error("%{public}@", String(describing: error))
                return
            }
        }
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

    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        // remove segmentation header
        let responseEdited = response.subdata(in: response.startIndex+1..<response.count)
        for opcode in ACControlPointOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: responseEdited) {
                switch opcode {
                case .responseCode:
                    if let requestOpcode = ACControlPointOpcode(rawValue: responseEdited[responseEdited.startIndex.advanced(by: 1)...].to(ACControlPointOpcode.RawValue.self)) {
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
        log.error("Authorization Control Control Point response does not have a procedure ID (raw response: %{public}@)", responseEdited.toHexString())
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
    private func createGetACSFeatureRequest() -> Data {
        ACFeature.request
    }

    private func createGetResourceHandleToUUIDMapRequest() -> Data {
        ResourceHandleToUUIDMap.request
    }

    private func createGetRestrictionMapIDListRequest() -> Data {
        RestrictionMapIDList.request
    }

    private func createGetAllActiveDescriptorsRequest() -> Data {
        ACControlPoint.buildControlPointRequest(opcode: ACControlPointOpcode.getAllActiveDescriptors)
    }
    
    func createECDHPublicKeyRequest(certificateData: Data) -> Data {
        KeyExchangeECDH.ecdhRequestCertificate(securityManager: securityManager, certificateData: certificateData)
    }

    func createECDHConfirmationCodeRequest() -> Data? {
        KeyExchangeECDH.ecdhConfirmationCodeRequest(securityManager: securityManager)
    }

    func createGetATTMTURequest() -> Data {
        ACControlPoint.buildControlPointRequest(opcode: ACControlPointOpcode.getATTMTU)
    }

    func createKeyExchangeKDFRequest() -> Data {
        let operand = Data(securityManager.configuration.ecdhKeyID)
        return ACControlPoint.buildControlPointRequest(opcode: ACControlPointOpcode.keyExchangeKDF, operand: operand)
    }

    func createSetClientNonceFixedRequest() -> Data {
        KeyExchangeECDH.setClientFixedNonce(securityManager: securityManager)
    }

    func createGetPHDCertificateNonceRequest() -> Data {
        ACControlPoint.buildControlPointRequest(opcode: ACControlPointOpcode.getPHDCertificateNonce)
    }

    func createInvalidateKeyRequest() -> Data {
        let operand = Data(securityManager.configuration.ecdhKeyID)
        return ACControlPoint.buildControlPointRequest(opcode: ACControlPointOpcode.invalidateKey, operand: operand)
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

    public func queueInvalidateKeyRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createInvalidateKeyRequest(), completion: completion)
    }

    public func queueKeyExchangeKDFRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createKeyExchangeKDFRequest(), completion: completion)
    }

    func queueSetClientFixedNonceRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createSetClientNonceFixedRequest(), completion: completion)
    }

    func queueGetPHDCertificateNonce(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetPHDCertificateNonceRequest(), completion: completion)
    }
    
    public func queueECDHPublicKeyRequest(certificateData: Data, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createECDHPublicKeyRequest(certificateData: certificateData), completion: completion)
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
        case .acsFeatureResponse: return "keyExchangeECDH"
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
