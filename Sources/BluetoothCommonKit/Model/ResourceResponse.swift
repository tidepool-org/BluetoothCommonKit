//
//  ResourceResponse.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

typealias ResourceHandle = UInt16

struct ResourceResponse {
    let resourceHandle: ResourceHandle
    let response: Data
}
