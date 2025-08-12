//
//  ResourceResponse.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public typealias ResourceHandle = UInt16

public struct ResourceResponse {
    public let resourceHandle: ResourceHandle
    public let response: Data
}
