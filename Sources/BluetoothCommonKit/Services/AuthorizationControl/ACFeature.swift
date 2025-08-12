//
//  ACFeature.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth
import os.log

public struct ACFeatureDataHandler: RequestHandler {
    private static let log = OSLog(category: "ACFeature")
    
    // dictionary keys
    public enum ACFeatureKey: String {
        case confirmationInputCapa
        case confirmationInputSize
        case confirmationOutputCapa
        case confirmationOutputSize
        case features
        case oobKeyExchangeCapa
        case oobStaticNumberExchangeCapa
        case qualityOfProtection
    }

    static public var request: Data {
        return ACFeatureDataHandler.buildControlPointRequest(opcode: ACControlPointOpcode.getACSFeature)
    }
    
    static public func handleResponse(_ response: Data) -> Result<FeaturesFlag, DeviceCommError> {
        let expectedResponseLength: Int = 23
        guard response.count == expectedResponseLength else { // includes opcode
            log.error("AC feature response is an unexpected size: (expect %d, actual, %d)", expectedResponseLength, response.count)
            return .failure(.invalidFormat)
        }

        var parsedResponse = Dictionary<String, Any>()
        var index = 1 // skip the opcode

        let features = FeaturesFlag(rawValue: response[response.startIndex.advanced(by: index)...].to(FeaturesFlag.RawValue.self))
        index += 4
        parsedResponse[ACFeatureKey.features.rawValue] = features

        let qualityOfProtection = QualityOfProtection(rawValue: response[response.startIndex.advanced(by: index)...].to(QualityOfProtection.RawValue.self))
        index += 2
        parsedResponse[ACFeatureKey.qualityOfProtection.rawValue] = qualityOfProtection

        let oobKeyExchangeCapability = OOBCapability(rawValue: response[response.startIndex.advanced(by: index)...].to(OOBCapability.RawValue.self))
        index += 2
        parsedResponse[ACFeatureKey.oobKeyExchangeCapa.rawValue] = oobKeyExchangeCapability

        let oobStaticNumberExchangeCapability = OOBCapability(rawValue: response[response.startIndex.advanced(by: index)...].to(OOBCapability.RawValue.self))
        index = index + 2
        parsedResponse[ACFeatureKey.oobStaticNumberExchangeCapa.rawValue] = oobStaticNumberExchangeCapability

        let confirmationInputSize = response[response.startIndex.advanced(by: index)...].to(UInt32.self)
        index += 4
        parsedResponse[ACFeatureKey.confirmationInputSize.rawValue] = confirmationInputSize

        let confirmationInputCapability = ConfirmationInputCapability(rawValue: response[response.startIndex.advanced(by: index)...].to(ConfirmationInputCapability.RawValue.self))
        index += 2
        parsedResponse[ACFeatureKey.confirmationInputCapa.rawValue] = confirmationInputCapability

        let confirmationOutputSize = response[response.startIndex.advanced(by: index)...].to(UInt32.self)
        index += 4
        parsedResponse[ACFeatureKey.confirmationOutputSize.rawValue] = confirmationOutputSize

        let confirmationOutputCapability = ConfirmationOutputCapability(rawValue: response[response.startIndex.advanced(by: index)...].to(ConfirmationOutputCapability.RawValue.self))
        index += 2
        parsedResponse[ACFeatureKey.confirmationOutputCapa.rawValue] = confirmationOutputCapability

        log.debug("%{public}@", parsedResponse)
        return .success(features)
    }
}

public struct FeaturesFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    static public let setInformationSecurityControlsAvailabilitySupported = FeaturesFlag(rawValue: 1 << 0)
    static public let descriptorsSupported = FeaturesFlag(rawValue: 1 << 1)
    static public let multipleRestrictionMapsSupported  = FeaturesFlag(rawValue: 1 << 2)
    static public let resourceHandleToUUIDMapSupported = FeaturesFlag(rawValue: 1 << 3)
    static public let initiatePairingSupported = FeaturesFlag(rawValue: 1 << 4)
    static public let keyExchangeOOBSupported = FeaturesFlag(rawValue: 1 << 5)
    static public let keyExchangeECDHSupported = FeaturesFlag(rawValue: 1 << 6)
    static public let keyExchangeKDFSupported = FeaturesFlag(rawValue: 1 << 7)
    static public let keyURISupported = FeaturesFlag(rawValue: 1 << 8)
    static public let invalidateEstablishedSecuritySupported = FeaturesFlag(rawValue: 1 << 9)
    static public let attMTUSupported = FeaturesFlag(rawValue: 1 << 10)
    static public let protectedResourceWriteSupported = FeaturesFlag(rawValue: 1 << 11)
    static public let protectedResourceReadSupported = FeaturesFlag(rawValue: 1 << 12)
    static public let protectedResourceNotificationSupported = FeaturesFlag(rawValue: 1 << 13)
    static public let protectedResourceIndicationSupported = FeaturesFlag(rawValue: 1 << 14)
    static public let keyFormatServerManufacturerSpecificSupported = FeaturesFlag(rawValue: 1 << 15)
    static public let keyFormatClientManufacturerSpecificSupported = FeaturesFlag(rawValue: 1 << 16)
    static public let keyFormatServerUncompressedPlainSupported = FeaturesFlag(rawValue: 1 << 17)
    static public let keyFormatClientUncompressedPlainSupported = FeaturesFlag(rawValue: 1 << 18)
    static public let keyFormatServerX509Supported = FeaturesFlag(rawValue: 1 << 19)
    static public let keyFormatClientX509Supported = FeaturesFlag(rawValue: 1 << 20)
    static public let allZeros = FeaturesFlag([])

    static let debugDescriptions: [FeaturesFlag:String] = {
        var descriptions = [FeaturesFlag:String]()
        descriptions[.setInformationSecurityControlsAvailabilitySupported] = "setInformationSecurityControlsAvailabilitySupported"
        descriptions[.keyExchangeECDHSupported] = "keyExchangeSupported"
        descriptions[.keyExchangeKDFSupported] = "keyExchangeSupported"
        descriptions[.multipleRestrictionMapsSupported] = "multiplRestrictionMapsSupported"
        descriptions[.resourceHandleToUUIDMapSupported] = "resourceHandleToUUIDMapSupported"
        descriptions[.descriptorsSupported] = "descriptorsSupported"
        descriptions[.initiatePairingSupported] = "initiatePairingSupported"
        descriptions[.keyExchangeOOBSupported] = "keyExchangeOOBSupported"
        descriptions[.keyURISupported] = "keyURISupported"
        descriptions[.attMTUSupported] = "attMTUSupported"
        descriptions[.keyExchangeECDHSupported] = "keyExchangeECDHSupported"
        descriptions[.protectedResourceWriteSupported] = "protectedResourceWriteSupported"
        descriptions[.protectedResourceReadSupported] = "protectedResourceReadSupported"
        descriptions[.protectedResourceNotificationSupported] = "protectedResourceNotificationSupported"
        descriptions[.protectedResourceIndicationSupported] = "protectedResourceIndicationSupported"
        descriptions[.keyFormatServerManufacturerSpecificSupported] = "keyFormatServerManufacturerSpecificSupported"
        descriptions[.keyFormatClientManufacturerSpecificSupported] = "keyFormatClientManufacturerSpecificSupported"
        descriptions[.keyFormatServerUncompressedPlainSupported] = "keyFormatServerUncompressedPlainSupported"
        descriptions[.keyFormatClientUncompressedPlainSupported] = "keyFormatClientUncompressedPlainSupported"
        descriptions[.keyFormatServerX509Supported] = "keyFormatServerX509Supported"
        descriptions[.keyFormatClientX509Supported] = "keyFormatClientX509Supported"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in FeaturesFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "FeaturesFlag(rawValue: \(self.rawValue)) \(result)"
    }
}

public struct QualityOfProtection: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    static public let confidentiality  = QualityOfProtection(rawValue: 1 << 0)
    static public let integrity = QualityOfProtection(rawValue: 1 << 1)
    static public let authentication = QualityOfProtection(rawValue: 1 << 2)
    static public let authorization = QualityOfProtection(rawValue: 1 << 3)
    static public let nonRepudiation = QualityOfProtection(rawValue: 1 << 4)
    static public let manufactureSpecificControlsUsed = QualityOfProtection(rawValue: 1 << 5)
    static public let allZeros = QualityOfProtection([])
    
    static let debugDescriptions: [QualityOfProtection:String] = {
        var descriptions = [QualityOfProtection:String]()
        descriptions[.confidentiality] = "confidentiality"
        descriptions[.integrity] = "integrity"
        descriptions[.authentication] = "authentication"
        descriptions[.authorization] = "authorization"
        descriptions[.nonRepudiation] = "nonRepudiation"
        descriptions[.manufactureSpecificControlsUsed] = "manufactureSpecificControlsUsed"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in QualityOfProtection.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "QualityOfProtection(rawValue: \(rawValue)) \(result)"
    }
}

public struct OOBCapability: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    static public let other = OOBCapability(rawValue: 1 << 0)
    static public let uri = OOBCapability(rawValue: 1 << 1)
    static public let machineReadableCode2D = OOBCapability(rawValue: 1 << 2)
    static public let barCode = OOBCapability(rawValue: 1 << 3)
    static public let nfc  = OOBCapability(rawValue: 1 << 4)
    static public let number = OOBCapability(rawValue: 1 << 5)
    static public let string = OOBCapability(rawValue: 1 << 6)
    static public let certificateX509 = OOBCapability(rawValue: 1 << 7)
    static public let onBox = OOBCapability(rawValue: 1 << 11)
    static public let insideBox = OOBCapability(rawValue: 1 << 12)
    static public let onPaper = OOBCapability(rawValue: 1 << 13)
    static public let insideManual = OOBCapability(rawValue: 1 << 14)
    static public let onDevice = OOBCapability(rawValue: 1 << 15)
    static public let allZeros = OOBCapability([])

    static let debugDescriptions: [OOBCapability:String] = {
        var descriptions = [OOBCapability:String]()
        descriptions[.other] = "other"
        descriptions[.uri] = "uri"
        descriptions[.machineReadableCode2D] = "machineReadableCode2D"
        descriptions[.barCode] = "barCode"
        descriptions[.nfc] = "nfc"
        descriptions[.number] = "number"
        descriptions[.string] = "string"
        descriptions[.certificateX509] = "certificateX509"
        descriptions[.onBox] = "onBox"
        descriptions[.insideBox] = "insideBox"
        descriptions[.onPaper] = "onPaper"
        descriptions[.insideManual] = "insideManual"
        descriptions[.onDevice] = "onDevice"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in OOBCapability.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "OOBCapability(rawValue: \(rawValue)) \(result)"
    }
}

public struct ConfirmationInputCapability: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    static public let push = ConfirmationInputCapability(rawValue: 1 << 0)
    static public let inputNumeric = ConfirmationInputCapability(rawValue: 1 << 2)
    static public let allZeros = ConfirmationInputCapability([])
    
    static let debugDescriptions: [ConfirmationInputCapability:String] = {
        var descriptions = [ConfirmationInputCapability:String]()
        descriptions[.push] = "push"
        descriptions[.inputNumeric] = "inputNumeric"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in ConfirmationInputCapability.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "ConfirmationInputCapability(rawValue: \(rawValue)) \(result)"
    }
}

public struct ConfirmationOutputCapability: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    static public let beep = ConfirmationOutputCapability(rawValue: 1 << 0)
    static public let outputNumeric = ConfirmationOutputCapability(rawValue: 1 << 3)
    static public let allZeros = ConfirmationOutputCapability([])
    
    static let debugDescriptions: [ConfirmationOutputCapability:String] = {
        var descriptions = [ConfirmationOutputCapability:String]()
        descriptions[.beep] = "beep"
        descriptions[.outputNumeric] = "outputNumeric"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in ConfirmationOutputCapability.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "ConfirmationOutputCapability(rawValue: \(rawValue)) \(result)"
    }
}
