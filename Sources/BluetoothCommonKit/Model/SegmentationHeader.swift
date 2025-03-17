//
//  SegmentationHeader.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct SegmentationHeader: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: UInt8
    
    static let firstPart = SegmentationHeader(rawValue: 1 << 0)
    static let lastPart = SegmentationHeader(rawValue: 1 << 1)
    static let counterPart = SegmentationHeader(rawValue: 0b11111100)
    static let allZeros = SegmentationHeader([])
    
    static let maxCounterValue: UInt8 = 63
    
    var counter: UInt8 {
        return ((rawValue & SegmentationHeader.counterPart.rawValue) >> 2)
    }
    
    var nextCounterValue: UInt8 {
        // range is 0 to 63
        return (counter + 1) % (SegmentationHeader.maxCounterValue + 1)
    }

    var isFirstPart: Bool {
        self.contains(SegmentationHeader.firstPart)
    }

    var isLastPart: Bool {
        self.contains(SegmentationHeader.lastPart)
    }
    
    static let debugDescriptions: [SegmentationHeader:String] = {
        var descriptions = [SegmentationHeader:String]()
        descriptions[.firstPart] = "firstPart"
        descriptions[.lastPart] = "lastPart"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in SegmentationHeader.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "SegmentationHeader(rawValue: \(rawValue), segment counter: \(counter)) \(result)"
    }
}
