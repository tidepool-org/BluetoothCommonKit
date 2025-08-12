//
//  FloatingPoint.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public extension FloatingPoint {
    var roundedToTenths: Self {
        return (self * 10).rounded() / 10
    }
    
    var roundedToHundredths: Self {
        return (self * 100).rounded() / 100
    }
    
    var roundedToThousandths: Self {
        return (self * 1000).rounded() / 1000
    }
}
