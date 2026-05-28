//
//  DTControlPointTests.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

final class DTControlPointTests: XCTestCase, E2EProtectionDelegate {

    private var deviceTimeControlPoint = DTControlPointDataHandler()
    internal var isE2EProtectionSupported: Bool = true
    
    override func setUp() {
        deviceTimeControlPoint.e2eDelegate = self
    }
    
    func testOpcode() {
        XCTAssertEqual(DTControlPointOpcode(rawValue: 2), .proposeTimeUpdate)
        XCTAssertNil(DTControlPointOpcode.proposeTimeUpdate.requestOpcode)
        XCTAssertEqual(DTControlPointOpcode(rawValue: 3), .forceTimeUpdate)
        XCTAssertNil(DTControlPointOpcode.forceTimeUpdate.requestOpcode)
        XCTAssertEqual(DTControlPointOpcode(rawValue: 4), .proposeNonLoggedTimeAdjustmentLimit)
        XCTAssertNil(DTControlPointOpcode.proposeNonLoggedTimeAdjustmentLimit.requestOpcode)
        XCTAssertEqual(DTControlPointOpcode(rawValue: 5), .retrieveActiveTimeAdjustments)
        XCTAssertNil(DTControlPointOpcode.retrieveActiveTimeAdjustments.requestOpcode)
        XCTAssertEqual(DTControlPointOpcode(rawValue: 7), .reportActiveTimeAdjustments)
        XCTAssertEqual(DTControlPointOpcode.retrieveActiveTimeAdjustments, DTControlPointOpcode.reportActiveTimeAdjustments.requestOpcode)
        XCTAssertEqual(DTControlPointOpcode(rawValue: 9), .responseCode)
        XCTAssertNil(DTControlPointOpcode.responseCode.requestOpcode)
    }

    func testResponseCode() {
        XCTAssertEqual(DTControlPointResponseCode(rawValue: 1), .success)
        XCTAssertEqual(DTControlPointResponseCode(rawValue: 2), .opcodeNotSupported)
        XCTAssertEqual(DTControlPointResponseCode(rawValue: 3), .invalidOperand)
        XCTAssertEqual(DTControlPointResponseCode(rawValue: 4), .operationFailed)
        XCTAssertEqual(DTControlPointResponseCode(rawValue: 5), .procedureRejected)
        XCTAssertEqual(DTControlPointResponseCode(rawValue: 7), .deviceBusy)
    }

    func testTimeSource() {
        XCTAssertEqual(TimeSource(rawValue: 0), .unknown)
        XCTAssertEqual(TimeSource(rawValue: 1), .networkTimeProtocol)
        XCTAssertEqual(TimeSource(rawValue: 2), .gps)
        XCTAssertEqual(TimeSource(rawValue: 3), .radioTimeSignal)
        XCTAssertEqual(TimeSource(rawValue: 4), .manual)
        XCTAssertEqual(TimeSource(rawValue: 5), .atomicClock)
        XCTAssertEqual(TimeSource(rawValue: 6), .cellularNetwork)
    }

    func testTimeAccuracy() {
        XCTAssertEqual(TimeAccuracy(rawValue: 255), .unknown)
    }

    func testRejectionFlags() {
        XCTAssertEqual(RejectionFlags(rawValue: 1), .notRealistic)
        XCTAssertEqual(RejectionFlags(rawValue: 2), .notAuthorized)
        XCTAssertEqual(RejectionFlags(rawValue: 4), .outOfRangeOperand)
        XCTAssertEqual(RejectionFlags(rawValue: 8), .notUTCAligned)
        XCTAssertEqual(RejectionFlags(rawValue: 16), .outOfRangeTimeAccuracy)
        XCTAssertEqual(RejectionFlags(rawValue: 32), .timeSourceLowQuality)
        XCTAssertEqual(RejectionFlags(rawValue: 64), .epochYearNotAligned)
        XCTAssertEqual(RejectionFlags(rawValue: 256), .lackOfPrecision)
        XCTAssertEqual(RejectionFlags(rawValue: 512), .baseTimeRejected)
        XCTAssertEqual(RejectionFlags(rawValue: 1024), .timeZoneDSTRejected)
    }

    func testTimeUpdateFlags() {
        XCTAssertEqual(TimeUpdateFlags(rawValue: 1), .utcAligned)
        XCTAssertEqual(TimeUpdateFlags(rawValue: 2), .qualifiedLocalTime)
        XCTAssertEqual(TimeUpdateFlags(rawValue: 4), .adjustmentReasonManual)
        XCTAssertEqual(TimeUpdateFlags(rawValue: 8), .adjustmentReasonExternal)
        XCTAssertEqual(TimeUpdateFlags(rawValue: 16), .adjustmentReasonTimeZone)
        XCTAssertEqual(TimeUpdateFlags(rawValue: 32), .adjustmentReasonDSTOffset)
        XCTAssertEqual(TimeUpdateFlags(rawValue: 64), .epochYear2000)
        XCTAssertEqual(TimeUpdateFlags(rawValue: 128), .secondFractionsNotValid)
    }

    func testEpoch2000() {
        let epoch2000 = Date.epoch2000
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: epoch2000)
        XCTAssertEqual(dateComponents.year, 2000)
        XCTAssertEqual(dateComponents.month, 1)
        XCTAssertEqual(dateComponents.day, 1)
        XCTAssertEqual(dateComponents.hour, 0)
        XCTAssertEqual(dateComponents.minute, 0)
        XCTAssertEqual(dateComponents.second, 0)
    }

    func testHandleGeneralResponse() {
        let requestOpcode = DTControlPointOpcode.proposeTimeUpdate
        let responseCode = DTControlPointResponseCode.success
        var response = Data(DTControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response = response.appendingCRCPrefix()

        let (result, _) = deviceTimeControlPoint.handleResponse(response)
        switch result {
        case .success():
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseOpcodeNotSupported() {
        let requestOpcode = DTControlPointOpcode.proposeTimeUpdate
        let responseCode = DTControlPointResponseCode.opcodeNotSupported
        var response = Data(DTControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response = response.appendingCRCPrefix()

        let (result, _) = deviceTimeControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .opcodeNotSupported)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseInvalidOperand() {
        let requestOpcode = DTControlPointOpcode.proposeTimeUpdate
        let responseCode = DTControlPointResponseCode.invalidOperand
        var response = Data(DTControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response = response.appendingCRCPrefix()

        let (result, _) = deviceTimeControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidOperand)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseProcedureNotCompleted() {
        let requestOpcode = DTControlPointOpcode.proposeTimeUpdate
        var responseCode = DTControlPointResponseCode.operationFailed
        var response = Data(DTControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response = response.appendingCRCPrefix()

        var (result, _) = deviceTimeControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotCompleted)
        default:
            XCTAssert(false)
        }

        responseCode = DTControlPointResponseCode.procedureRejected
        response = Data(DTControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response = response.appendingCRCPrefix()

        (result, _) = deviceTimeControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotCompleted)
        default:
            XCTAssert(false)
        }

        responseCode = DTControlPointResponseCode.deviceBusy
        response = Data(DTControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response = response.appendingCRCPrefix()

        (result, _) = deviceTimeControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotCompleted)
        default:
            XCTAssert(false)
        }
    }

    func testCreateProposeTimeUpdateRequest() {
        let now = Date()
        let expectedBaseTime = UInt32(now.timeIntervalSince(Date.epoch2000).seconds)
        let timeZone = TimeZone.current
        let expectedTimeZoneOffset = Int8((timeZone.secondsFromGMT(for: now) - Int(timeZone.daylightSavingTimeOffset(for: now))) / (60 * 15))
        let expectedTimeSource = TimeSource.networkTimeProtocol
        let expectedTimeAccuracy: UInt8 = 255
        let expectedDSTOffset = timeZone.dstOffset()

        var expectedTimeUpdateFlags: TimeUpdateFlags = [.utcAligned, .qualifiedLocalTime, .epochYear2000, .secondFractionsNotValid, .adjustmentReasonTimeZone]
        if expectedDSTOffset != .standardTime && expectedDSTOffset != .unknown {
            expectedTimeUpdateFlags.insert(.adjustmentReasonDSTOffset)
        }

        let request = deviceTimeControlPoint.createProposeTimeUpdateRequest(now, using: timeZone, features: [.supportedEpochYear2000])

        XCTAssertTrue(request.isCRCPrefixValid)
        var index = 2
        XCTAssertEqual(DTControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(DTControlPointOpcode.RawValue.self)), DTControlPointOpcode.proposeTimeUpdate)
        index += 1
        XCTAssertEqual(TimeUpdateFlags(rawValue: request[request.startIndex.advanced(by: index)...].to(TimeUpdateFlags.RawValue.self)), expectedTimeUpdateFlags)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt32.self), expectedBaseTime)
        index += 4
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(Int8.self), expectedTimeZoneOffset)
        index += 1
        XCTAssertEqual(DSTOffset(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), expectedDSTOffset)
        index += 1
        XCTAssertEqual(TimeSource(rawValue: request[request.startIndex.advanced(by: index)...].to(TimeSource.RawValue.self)), expectedTimeSource)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedTimeAccuracy)
    }

    func testProcedureIDForResponse() {
        for opcode in DTControlPointOpcode.responseOpcodes {
            if opcode == .responseCode {
                for requestOpcode in DTControlPointOpcode.allCases {
                    if requestOpcode != .responseCode {
                        var response = Data(UInt16(0))// CRC prefix
                        response.append(opcode.rawValue)
                        response.append(requestOpcode.rawValue)
                        let procedureID = deviceTimeControlPoint.procedureIDForResponse(response)
                        XCTAssertEqual(procedureID, requestOpcode.procedureID)
                    }
                }
            } else {
                var response = Data(UInt16(0)) // CRC prefix
                response.append(opcode.rawValue)
                let procedureID = deviceTimeControlPoint.procedureIDForResponse(response)
                switch opcode {
                case .reportActiveTimeAdjustments: XCTAssertEqual(procedureID, DTControlPointOpcode.retrieveActiveTimeAdjustments.procedureID)
                default:
                    XCTAssert(false)
                }
            }
        }
    }

    func testProcedureIDForRequest() {
        for opcode in DTControlPointOpcode.allCases {
            var request = Data(UInt16(0)) // CRC prefix
            request.append(opcode.rawValue)
            XCTAssertEqual(opcode.procedureID, deviceTimeControlPoint.procedureIDForRequest(request))
        }
    }
}
