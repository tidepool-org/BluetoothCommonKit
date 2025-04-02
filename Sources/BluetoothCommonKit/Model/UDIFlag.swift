//
//  UDIFlag.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//


public struct UDIFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static public let presentLabel = UDIFlag(rawValue: 1 << 0)
    static public let presentDeviceIdentifier = UDIFlag(rawValue: 1 << 1)
    static public let presentIssuer = UDIFlag(rawValue: 1 << 2)
    static public let presentAuthority = UDIFlag(rawValue: 1 << 3)
    static public let allZeros = UDIFlag([])

    static let debugDescriptions: [UDIFlag:String] = {
        var descriptions = [UDIFlag:String]()
        descriptions[.presentLabel] = "presentLabel"
        descriptions[.presentDeviceIdentifier] = "presentDeviceIdentifier"
        descriptions[.presentIssuer] = "presentIssuer"
        descriptions[.presentAuthority] = "presentAuthority"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for key in UDIFlag.debugDescriptions.keys {
            guard self.contains(key),
                  let description = UDIFlag.debugDescriptions[key]
            else { continue }
            result.append(description)
        }
        return "UDIFlag(rawValue: \(self.rawValue)) \(result)"
    }
}
