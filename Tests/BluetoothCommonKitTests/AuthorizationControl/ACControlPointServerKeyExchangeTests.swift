//
//  ACControlPointServerKeyExchangeTests.swift
//  BluetoothCommonKitTests
//
//  Created by Nathaniel Hamming on 2026-10-13.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//
//  Drives the server-side ACControlPointCharacteristic with the kit's own client handler through the ECDH key
//  exchange, so both ends' SecurityManagerDelegates are observed: the server must learn that security is
//  established on a confirmed exchange, and both sides must discard the shared secret on a failed one.

import XCTest
import CoreBluetooth
@testable import BluetoothCommonKit

final class ACControlPointServerKeyExchangeTests: XCTestCase {

    private final class RecordingSecurityDelegate: SecurityManagerDelegate {
        var sharedKeyData: Data?
        var establishedCount = 0

        func securityManagerDidEstablishedSecurity(_ securityManager: SecurityManager) {
            establishedCount += 1
        }

        func securityManagerDidUpdateConfiguration(_ securityManager: SecurityManager) { }
    }

    /// Collects the server's indications instead of sending them.
    private final class CollectingMessageQueue: MessagingQueue {
        var gattServer: GATTService!
        var items: [UUIDValuePair] = []
        var hasMessagesInQueue: Bool { !items.isEmpty }

        func addQueueItem(_ update: UUIDValuePair) {
            items.append(update)
        }

        func emptyQueue() {
            items.removeAll()
        }
    }

    /// Only the key-exchange procedures are exercised, so the descriptor getters are never called.
    private final class ServerDelegate: ACControlPointDelegate {
        let securityManager: SecurityManager
        var currentKeyID: KeyID?
        var invalidateKeyCount = 0

        init(securityManager: SecurityManager) {
            self.securityManager = securityManager
        }

        var ecdhKeyID: KeyID { securityManager.configuration.ecdhKeyID }
        var algorithmKeyID: KeyID { securityManager.configuration.algorithmKeyID }
        func getAuthorizationFeatures() -> Data { Data() }
        func getRestrictionMap(for restrictionMapID: RestrictionMapID, handleFilter: ResourceHandle) -> Data { Data() }
        func getRestrictionMapIDList() -> Data { Data() }
        func getInformationSecurityConfiguration(filter: SecurityConfigurationID) -> Data { Data() }
        func getKeyDescriptor(filter: KeyID) -> Data { Data() }
        func resourceHandleToUUIDMap() -> [[CBUUID: ResourceHandle]] { [] }
        func invalidateKey() { invalidateKeyCount += 1 }
    }

    private var serverSecurityDelegate: RecordingSecurityDelegate!
    private var serverSecurityManager: SecurityManager!
    private var serverDelegate: ServerDelegate!
    private var queue: CollectingMessageQueue!
    private var server: ACControlPointCharacteristic!

    private var clientSecurityDelegate: RecordingSecurityDelegate!
    private var clientSecurityManager: SecurityManager!
    private var client: ACControlPointDataHandler!

    override func setUp() {
        super.setUp()
        serverSecurityDelegate = RecordingSecurityDelegate()
        serverSecurityManager = SecurityManager()
        serverSecurityManager.configuration.oobRandomNumber = Data("42".utf8)
        serverSecurityManager.delegate = serverSecurityDelegate
        serverDelegate = ServerDelegate(securityManager: serverSecurityManager)
        queue = CollectingMessageQueue()
        server = ACControlPointCharacteristic(messageQueue: queue)
        server.securityManager = serverSecurityManager
        server.delegate = serverDelegate

        clientSecurityDelegate = RecordingSecurityDelegate()
        clientSecurityManager = SecurityManager()
        clientSecurityManager.configuration.oobRandomNumber = Data("42".utf8)
        // Normally learned from the Key Descriptor response, which this test does not exercise.
        clientSecurityManager.configuration.keyDerivationFunctionConfiguration = SecurityManager.Configuration.KeyDerivationFunctionConfiguration(keyDerivationFunction: .hkdfSHA256)
        clientSecurityManager.delegate = clientSecurityDelegate
        client = ACControlPointDataHandler(securityManager: clientSecurityManager, maxRequestSize: 19)
    }

    /// Queues the client's key exchange requests; the response handlers queue the confirmation steps themselves.
    private func queueKeyExchange() {
        let keyID = clientSecurityManager.configuration.ecdhKeyID
        clientSecurityManager.generateKeyPair()
        client.queueStartKeyExchangeRequest(keyID: keyID)
        client.queueECDHPublicKeyRequest()
        client.queueKeyExchangeKDFRequest(keyID: keyID)
    }

    /// Writes the next queued client request to the server and feeds every indication back to the client.
    /// Returns the client-side results so a test can look for a specific failure.
    @discardableResult
    private func exchangeOneRequest() -> [DeviceCommResult<Any?>] {
        guard let (request, _) = client.nextRequestToSend() else { return [] }
        client.procedureRunning = true
        for segment in client.segmentPayload(request) {
            XCTAssertEqual(server.onWrite(segment), .success)
        }
        let responses = queue.items
        queue.emptyQueue()
        var results: [DeviceCommResult<Any?>] = []
        for response in responses {
            let (result, _) = client.handleSegmentedResponse(response.value)
            if case .failure(.partialResponse) = result { continue }
            results.append(result)
        }
        return results
    }

    private func runExchange(maxRounds: Int = 12) -> [DeviceCommResult<Any?>] {
        var results: [DeviceCommResult<Any?>] = []
        var rounds = 0
        while client.nextRequestToSend() != nil, rounds < maxRounds {
            results.append(contentsOf: exchangeOneRequest())
            rounds += 1
        }
        return results
    }

    func testConfirmedExchangeEstablishesSecurityOnTheServerToo() {
        queueKeyExchange()
        let results = runExchange()

        XCTAssertNil(client.nextRequestToSend(), "client still has requests queued")
        XCTAssertFalse(results.contains { if case .failure = $0 { return true } else { return false } }, "client reported a failure: \(results)")

        // Both delegates heard about it, and both hold a derived key.
        XCTAssertEqual(serverSecurityDelegate.establishedCount, 1)
        XCTAssertEqual(clientSecurityDelegate.establishedCount, 1)
        XCTAssertNotNil(serverSecurityDelegate.sharedKeyData)
        XCTAssertNotNil(clientSecurityDelegate.sharedKeyData)
        XCTAssertTrue(serverSecurityManager.applicationSecurityEstablished)
        XCTAssertTrue(clientSecurityManager.applicationSecurityEstablished)
    }

    func testMismatchedOOBNumberDiscardsTheSharedSecretOnBothSides() {
        clientSecurityManager.configuration.oobRandomNumber = Data("43".utf8)
        queueKeyExchange()
        let results = runExchange()

        // The server rejected the confirmation and the client surfaced it as an authentication failure.
        XCTAssertTrue(results.contains { if case .failure(.authenticationFailed) = $0 { return true } else { return false } }, "expected authenticationFailed, got \(results)")

        XCTAssertEqual(serverSecurityDelegate.establishedCount, 0)
        XCTAssertEqual(clientSecurityDelegate.establishedCount, 0)
        XCTAssertNil(serverSecurityDelegate.sharedKeyData, "server kept the unconfirmed shared secret")
        XCTAssertNil(clientSecurityDelegate.sharedKeyData, "client kept the unconfirmed shared secret")
        XCTAssertFalse(serverSecurityManager.applicationSecurityEstablished)
        XCTAssertFalse(clientSecurityManager.applicationSecurityEstablished)
    }
}
