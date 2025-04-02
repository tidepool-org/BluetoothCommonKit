//
//  ACControlPointTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2020-03-31.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class ACControlPointTests: XCTestCase {

    private var acControlPoint: ACControlPointDataHandler!
    private var securityManager: SecurityManager!
    private var mockKeychainManager: MockKeychainManager!
    private var securityManagerTestingDelegate = SecurityManagerTestingDelegate()

    override func setUp() {
        securityManagerTestingDelegate.sharedKeyData = Data(hexadecimalString: "000102030405060708090a0b0c0d0e0f")!
        mockKeychainManager = MockKeychainManager()
        securityManager = SecurityManager()
        securityManager.delegate = securityManagerTestingDelegate
        securityManager.generateKeyPair()
        let serverPublicKeyData = Data(hexadecimalString: "a8c5fdce8b62c5ada598f141adb3b26cf254c280b2857a63d2ad783a73115f6b806e1aafec4af80a0d786b3de45375b517a7e5b51ffb2c356537c9e6ef227d4a")!
        securityManager.generateSharedSecret(receivedPublicKeyData: serverPublicKeyData)
        acControlPoint = ACControlPointDataHandler(securityManager: securityManager, maxRequestSize: 19)
    }

    func testOpcode() {
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x00), ACControlPointOpcode.responseCode)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x01), ACControlPointOpcode.getAllActiveDescriptors)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x02), ACControlPointOpcode.getRestrictionMapDescriptor)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x03), ACControlPointOpcode.restrictionMapDescriptorResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x04), ACControlPointOpcode.getRestrictionMapIDList)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x05), ACControlPointOpcode.restrictionMapIDListResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x06), ACControlPointOpcode.activateRestrictionMap)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x07), ACControlPointOpcode.getResourceHandleToUUIDMap)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x08), ACControlPointOpcode.resourceHandleToUUIDMapResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x09), ACControlPointOpcode.getServiceCharacteristicUUIDsCharacteristicResourceHandle)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x0A), ACControlPointOpcode.serviceCharacteristicUUIDsCharacteristicResourceHandleResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x0B), ACControlPointOpcode.getInformationSecurityConfigurationDescriptor)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x0C), ACControlPointOpcode.informationSecurityConfigurationDescriptorResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x0D), ACControlPointOpcode.getKeyDescriptor)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x0E), ACControlPointOpcode.keyDescriptorResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x0F), ACControlPointOpcode.getCurrentKeyList)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x10), ACControlPointOpcode.currentKeyListResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x11), ACControlPointOpcode.startKeyExchange)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x12), ACControlPointOpcode.keyExchangeResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x13), ACControlPointOpcode.invalidateAllEstablishedSecurity)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x14), ACControlPointOpcode.invalidateKey)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x15), ACControlPointOpcode.abort)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x16), ACControlPointOpcode.setAvailabilityOfInformationSecurityControls)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x17), ACControlPointOpcode.getKeyURI)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x18), ACControlPointOpcode.keyURIResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x19), ACControlPointOpcode.getACSFeature)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x1A), ACControlPointOpcode.acsFeatureResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x1B), ACControlPointOpcode.keyExchangeECDH)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x1C), ACControlPointOpcode.keyExchangeECDHResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x1D), ACControlPointOpcode.keyExchangeECDHConfirmationCode)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x1E), ACControlPointOpcode.keyExchangeECDHConfirmationCodeResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x1F), ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumber)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x20), ACControlPointOpcode.keyExchangeECDHConfirmationRandomNumberResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x21), ACControlPointOpcode.keyExchangeKDF)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x22), ACControlPointOpcode.keyExchangeKDFResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0x23), ACControlPointOpcode.setClientNonceFixed)
        XCTAssertNil(ACControlPointOpcode(rawValue: 0x24))
        XCTAssertNil(ACControlPointOpcode(rawValue: 0xDC))
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0xDD), ACControlPointOpcode.getATTMTU)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0xDE), ACControlPointOpcode.attMTUResponse)
        XCTAssertEqual(ACControlPointOpcode(rawValue: 0xDF), ACControlPointOpcode.initiatePairing)
        XCTAssertNil(ACControlPointResponseCode(rawValue: 0xE0))
    }
    
    func testResponseCode() {
        XCTAssertNil(ACControlPointResponseCode(rawValue: 0x00))
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x01), ACControlPointResponseCode.success)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x02), ACControlPointResponseCode.opcodeNotSupported)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x03), ACControlPointResponseCode.invalidOperand)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x04), ACControlPointResponseCode.procedureNotCompleted)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x05), ACControlPointResponseCode.parameterOutOfRange)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x06), ACControlPointResponseCode.procedureNotApplicable)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x07), ACControlPointResponseCode.abortUnsuccessful)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x08), ACControlPointResponseCode.noRecordsFound)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x09), ACControlPointResponseCode.invalidKeyExchangeConfirmationCode)
        XCTAssertEqual(ACControlPointResponseCode(rawValue: 0x0a), ACControlPointResponseCode.invalidPublicKey)
        XCTAssertNil(ACControlPointResponseCode(rawValue: 0x0b))
    }
    
    func testInitialization() {
        XCTAssertTrue(acControlPoint.requestQueue.isEmpty)
        XCTAssertFalse(acControlPoint.procedureRunning)
        XCTAssertTrue(acControlPoint.storedPayloads.isEmpty)
        XCTAssertEqual(acControlPoint.segmentCounter, 0)
        XCTAssertTrue(acControlPoint.uuidToHandleMap.isEmpty)
    }
    
    func testPrepareConfigurationRequests() {
        acControlPoint.queueConfigurationRequests()
        XCTAssertFalse(acControlPoint.requestQueue.isEmpty)
        XCTAssertEqual(acControlPoint.requestQueue.count, 5)
        
        XCTAssertEqual(ACControlPointOpcode(rawValue: acControlPoint.requestQueue[0].request[acControlPoint.requestQueue[0].request.startIndex...].to(ACControlPointOpcode.RawValue.self)), .getACSFeature)
        XCTAssertEqual(ACControlPointOpcode(rawValue: acControlPoint.requestQueue[1].request[acControlPoint.requestQueue[1].request.startIndex...].to(ACControlPointOpcode.RawValue.self)), .getATTMTU)
        XCTAssertEqual(ACControlPointOpcode(rawValue: acControlPoint.requestQueue[2].request[acControlPoint.requestQueue[2].request.startIndex...].to(ACControlPointOpcode.RawValue.self)),.getResourceHandleToUUIDMap)
        XCTAssertEqual(ACControlPointOpcode(rawValue: acControlPoint.requestQueue[3].request[acControlPoint.requestQueue[3].request.startIndex...].to(ACControlPointOpcode.RawValue.self)), .getRestrictionMapIDList)
        XCTAssertEqual(ACControlPointOpcode(rawValue: acControlPoint.requestQueue[4].request[acControlPoint.requestQueue[4].request.startIndex...].to(ACControlPointOpcode.RawValue.self)), .getAllActiveDescriptors)
    }

    func testHandleResourceRestrictionMapIDList() {
        let getRestrictionMapIDListRequest = Data(ACControlPointOpcode.getRestrictionMapIDList.rawValue)
        acControlPoint.appendToRequestQueue(getRestrictionMapIDListRequest, completion: nil)
        
        let segmentationHeader: SegmentationHeader = [.firstPart, .lastPart]
        let restrictionMapID: UInt16 = 0x0001
        let securityConfigurationID: UInt16 = 0x0002
        var restrictionMapIDListResponse = Data(segmentationHeader.rawValue)
        restrictionMapIDListResponse.append(ACControlPointOpcode.restrictionMapIDListResponse.rawValue)
        restrictionMapIDListResponse.append(restrictionMapID)
        restrictionMapIDListResponse.append(securityConfigurationID)
        
        let (result, _) = acControlPoint.handleSegmentedResponse(restrictionMapIDListResponse)
        switch result {
        case .failure(_):
            XCTAssert(false)
        case .success(_):
            XCTAssertTrue(acControlPoint.requestQueue.isEmpty)
            XCTAssertTrue(acControlPoint.storedPayloads.isEmpty)
        }
    }
    
    func testHandleGeneralResponseValid() {
        let getAllActiveDescriptorsRequest = Data(ACControlPointOpcode.getAllActiveDescriptors.rawValue)
        acControlPoint.appendToRequestQueue(getAllActiveDescriptorsRequest, completion: nil)
        
        let segmentationHeader: SegmentationHeader = [.firstPart, .lastPart]
        var getAllActiveDescriptorsResponse = Data(segmentationHeader.rawValue)
        getAllActiveDescriptorsResponse.append(ACControlPointOpcode.responseCode.rawValue)
        getAllActiveDescriptorsResponse.append(ACControlPointOpcode.getAllActiveDescriptors.rawValue)
        getAllActiveDescriptorsResponse.append(ACControlPointResponseCode.success.rawValue)
        
        let (result, _) = acControlPoint.handleSegmentedResponse(getAllActiveDescriptorsResponse)
        switch result {
        case .failure(_):
            XCTAssert(false)
        case .success(_):
            XCTAssertTrue(acControlPoint.requestQueue.isEmpty)
            XCTAssertTrue(acControlPoint.storedPayloads.isEmpty)
        }
    }
    
    func testHandleGeneralResponseInvalid() {
        let getAllActiveDescriptorsRequest = Data(ACControlPointOpcode.getAllActiveDescriptors.rawValue)
        acControlPoint.appendToRequestQueue(getAllActiveDescriptorsRequest, completion: nil)
        
        let segmentationHeader: SegmentationHeader = [.firstPart, .lastPart]
        let extraData = 0x01
        var getAllActiveDescriptorsResponse = Data(segmentationHeader.rawValue)
        getAllActiveDescriptorsResponse.append(ACControlPointOpcode.responseCode.rawValue)
        getAllActiveDescriptorsResponse.append(ACControlPointOpcode.getAllActiveDescriptors.rawValue)
        getAllActiveDescriptorsResponse.append(ACControlPointResponseCode.success.rawValue)
        getAllActiveDescriptorsResponse.append(extraData)
        
        let (result, _) = acControlPoint.handleSegmentedResponse(getAllActiveDescriptorsResponse)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        case .success(_):
            XCTAssert(false)
        }
    }

    func testUpdateMaxRequestSize() {
        var maxRequestSize = 19
        XCTAssertEqual(acControlPoint.maxRequestSize, maxRequestSize)

        maxRequestSize = 256
        acControlPoint.updateMaxRequestSize(maxRequestSize)
        XCTAssertEqual(acControlPoint.maxRequestSize, maxRequestSize)
    }

    func testCreateGetATTMTURequest() {
        let request = acControlPoint.createGetATTMTURequest()
        XCTAssertEqual(request.count, 1)
        XCTAssertEqual(request.last, ACControlPointOpcode.getATTMTU.rawValue)
    }

    func testHandleATTMTUResponse() {
        let testExpectation = expectation(description: #function)
        var receivedMaxRequestSize: Int?
        let maxRequestUpdatedHandler: (Int) -> Void = { newValue in
            receivedMaxRequestSize = newValue
            testExpectation.fulfill()
        }
        acControlPoint.maxRequestSizeUpdatedHandler = maxRequestUpdatedHandler

        let segmentationHeader: SegmentationHeader = [.firstPart, .lastPart]
        let attMTU = 256
        let newMaxRequestSize = attMTU - 1 // minus 1 for segmentation header
        var response = Data(segmentationHeader.rawValue)
        response.append(ACControlPointOpcode.attMTUResponse.rawValue)
        response.append(UInt16(attMTU))

        let (result, _) = acControlPoint.handleSegmentedResponse(response)
        wait(for: [testExpectation], timeout: 30)
        switch result {
        case .success:
            XCTAssertEqual(receivedMaxRequestSize, newMaxRequestSize)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testCreateSetClientNonceFixedRequest() {
        let algorithmKeyID: KeyID = 10
        securityManager.configuration.algorithmKeyID = algorithmKeyID
        let request = acControlPoint.createSetClientNonceFixedRequest()

        XCTAssertEqual(request.count, 7)
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(ACControlPointOpcode.RawValue.self), ACControlPointOpcode.setClientNonceFixed.rawValue)
        index+=1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(KeyID.self), algorithmKeyID)
        index+=2
        guard let clientIVFixedField = securityManager.configuration.generatedIVFixedField else {
            XCTAssert(false)
            return
        }
        let clientIVFixedFieldLittleEndian: Data? = Data(clientIVFixedField.reversed())
        XCTAssertEqual(Data(request[request.startIndex.advanced(by: index)...].to(UInt32.self)), clientIVFixedFieldLittleEndian)
    }

    func testAddClientFixedNonceRequest() throws {
        XCTAssertTrue(acControlPoint.requestQueue.isEmpty)
        acControlPoint.queueSetClientFixedNonceRequest()
        XCTAssertEqual(acControlPoint.requestQueue.count, 1)
        XCTAssertEqual(acControlPoint.procedureIDForNextRequest(), ACControlPointOpcode.setClientNonceFixed.procedureID)
    }

    func testAddKeyExchangeKDFRequest() {
        let keyID: KeyID = 1
        securityManager.configuration.ecdhKeyID = keyID
        XCTAssertTrue(acControlPoint.requestQueue.isEmpty)
        acControlPoint.queueKeyExchangeKDFRequest()
        XCTAssertEqual(acControlPoint.requestQueue.count, 1)
        XCTAssertEqual(acControlPoint.procedureIDForNextRequest(), ACControlPointOpcode.keyExchangeKDF.procedureID)

        let (request, _) = acControlPoint.requestQueue.first!
        XCTAssertEqual(ACControlPointOpcode.keyExchangeKDF, ACControlPointOpcode(rawValue: request[request.startIndex...].to(ACControlPointOpcode.RawValue.self)))
        XCTAssertEqual(keyID, request[request.startIndex.advanced(by: 1)...].to(KeyID.self))
    }

    func testKeyExchangeKDFResponse() {
        securityManager.configuration.ecdhKeyID = 1
        securityManager.configuration.keyDerivationFunctionConfiguration = SecurityManager.Configuration.KeyDerivationFunctionConfiguration(keyDerivationFunction: .hkdfSHA256)
        let segmentationHeader: SegmentationHeader = [.firstPart, .lastPart]
        let keyID: KeyID = 2
        let saltSize: UInt8 = 3
        let salt = Data([0x01, 0x02, 0x03])
        let infoSize: UInt8 = 3
        let info = Data([0x04, 0x05, 0x06])
        var response = Data(segmentationHeader.rawValue)
        response.append(ACControlPointOpcode.keyExchangeKDFResponse.rawValue)
        response.append(keyID)
        response.append(saltSize)
        response.append(salt)
        response.append(infoSize)
        response.append(info)

        XCTAssertTrue(acControlPoint.requestQueue.isEmpty)
        let (result, _) = acControlPoint.handleSegmentedResponse(response)
        switch result {
        case .success:
            XCTAssertEqual(acControlPoint.requestQueue.count, 1)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testKeyExchangeKDFResponseDerivationFailed() {
        let segmentationHeader: SegmentationHeader = [.firstPart, .lastPart]
        let keyID: KeyID = 2
        let saltSize: UInt8 = 3
        let salt = Data([0x01, 0x02, 0x03])
        let infoSize: UInt8 = 3
        let info = Data([0x04, 0x05, 0x06])
        var response = Data(segmentationHeader.rawValue)
        response.append(ACControlPointOpcode.keyExchangeKDFResponse.rawValue)
        response.append(keyID)
        response.append(saltSize)
        response.append(salt)
        response.append(infoSize)
        response.append(info)

        XCTAssertTrue(acControlPoint.requestQueue.isEmpty)
        let (result, _) = acControlPoint.handleSegmentedResponse(response)
        switch result {
        case .success:
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .securityManagerError(.keyDerivationFailed))
        }
    }

    func testCreateInvalidateKeyRequest() {
        let keyID: UInt16 = 1
        securityManager.configuration.ecdhKeyID = keyID
        let request = acControlPoint.createInvalidateKeyRequest()

        XCTAssertEqual(request.count, 3)
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(ACControlPointOpcode.RawValue.self), ACControlPointOpcode.invalidateKey.rawValue)
        index+=1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(KeyID.self), keyID)
    }
}
