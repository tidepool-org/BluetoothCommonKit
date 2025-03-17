//
//  ACFeature.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import os.log

private let log = OSLog(category: "ACFeature")

struct ACFeature: RequestHandler {
    
    // dictionary keys
    enum ACFeatureKey: String {
        case confirmationInputCapa
        case confirmationInputSize
        case confirmationOutputCapa
        case confirmationOutputSize
        case features
        case oobKeyExchangeCapa
        case oobStaticNumberExchangeCapa
        case qualityOfProtection
    }

    static var request: Data {
        return ACFeature.buildControlPointRequest(opcode: ACControlPointOpcode.getACSFeature)
    }
    
    static func handleResponse(_ response: Data) -> Result<FeaturesFlag, DeviceCommError> {
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

struct FeaturesFlag: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt32

    static let setInformationSecurityControlsAvailabilitySupported = FeaturesFlag(rawValue: 1 << 0)
    static let descriptorsSupported = FeaturesFlag(rawValue: 1 << 1)
    static let multipleRestrictionMapsSupported  = FeaturesFlag(rawValue: 1 << 2)
    static let resourceHandleToUUIDMapSupported = FeaturesFlag(rawValue: 1 << 3)
    static let initiatePairingSupported = FeaturesFlag(rawValue: 1 << 4)
    static let keyExchangeOOBSupported = FeaturesFlag(rawValue: 1 << 5)
    static let keyExchangeECDHSupported = FeaturesFlag(rawValue: 1 << 6)
    static let keyExchangeKDFSupported = FeaturesFlag(rawValue: 1 << 7)
    static let keyURISupported = FeaturesFlag(rawValue: 1 << 8)
    static let invalidateEstablishedSecuritySupported = FeaturesFlag(rawValue: 1 << 9)
    static let attMTUSupported = FeaturesFlag(rawValue: 1 << 10)
    static let protectedResourceWriteSupported = FeaturesFlag(rawValue: 1 << 11)
    static let protectedResourceReadSupported = FeaturesFlag(rawValue: 1 << 12)
    static let protectedResourceNotificationSupported = FeaturesFlag(rawValue: 1 << 13)
    static let protectedResourceIndicationSupported = FeaturesFlag(rawValue: 1 << 14)
    static let keyFormatServerManufacturerSpecificSupported = FeaturesFlag(rawValue: 1 << 15)
    static let keyFormatClientManufacturerSpecificSupported = FeaturesFlag(rawValue: 1 << 16)
    static let keyFormatServerUncompressedPlainSupported = FeaturesFlag(rawValue: 1 << 17)
    static let keyFormatClientUncompressedPlainSupported = FeaturesFlag(rawValue: 1 << 18)
    static let keyFormatServerX509Supported = FeaturesFlag(rawValue: 1 << 19)
    static let keyFormatClientX509Supported = FeaturesFlag(rawValue: 1 << 20)
    static let allZeros = FeaturesFlag([])

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

struct QualityOfProtection: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt16
    
    static let confidentiality  = QualityOfProtection(rawValue: 1 << 0)
    static let integrity = QualityOfProtection(rawValue: 1 << 1)
    static let authentication = QualityOfProtection(rawValue: 1 << 2)
    static let authorization = QualityOfProtection(rawValue: 1 << 3)
    static let nonRepudiation = QualityOfProtection(rawValue: 1 << 4)
    static let manufactureSpecificControlsUsed = QualityOfProtection(rawValue: 1 << 5)
    static let allZeros = QualityOfProtection([])
    
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

struct OOBCapability: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt16

    static let other = OOBCapability(rawValue: 1 << 0)
    static let uri = OOBCapability(rawValue: 1 << 1)
    static let machineReadableCode2D = OOBCapability(rawValue: 1 << 2)
    static let barCode = OOBCapability(rawValue: 1 << 3)
    static let nfc  = OOBCapability(rawValue: 1 << 4)
    static let number = OOBCapability(rawValue: 1 << 5)
    static let string = OOBCapability(rawValue: 1 << 6)
    static let certificateX509 = OOBCapability(rawValue: 1 << 7)
    static let onBox = OOBCapability(rawValue: 1 << 11)
    static let insideBox = OOBCapability(rawValue: 1 << 12)
    static let onPaper = OOBCapability(rawValue: 1 << 13)
    static let insideManual = OOBCapability(rawValue: 1 << 14)
    static let onDevice = OOBCapability(rawValue: 1 << 15)
    static let allZeros = OOBCapability([])

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

struct ConfirmationInputCapability: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt16
    
    static let push = ConfirmationInputCapability(rawValue: 1 << 0)
    static let inputNumeric = ConfirmationInputCapability(rawValue: 1 << 2)
    static let allZeros = ConfirmationInputCapability([])
    
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

struct ConfirmationOutputCapability: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt16
    
    static let beep = ConfirmationOutputCapability(rawValue: 1 << 0)
    static let outputNumeric = ConfirmationOutputCapability(rawValue: 1 << 3)
    static let allZeros = ConfirmationOutputCapability([])
    
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
