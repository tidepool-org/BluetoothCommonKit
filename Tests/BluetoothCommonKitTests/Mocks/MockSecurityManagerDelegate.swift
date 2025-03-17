//
//  MockSecurityManagerDelegate.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
@testable import BluetoothCommonKit

class SecurityManagerTestingDelegate: SecurityManagerDelegate {
    var sharedKeyData: Data? = nil
    
    func getCertificateData() -> Data? {
        return nil
    }
    
    func securityManagerDidEstablishedSecurity(_ securityManager: BluetoothCommonKit.SecurityManager) { }
    
    func securityManagerDidUpdateConfiguration(_ securityManager: BluetoothCommonKit.SecurityManager) { }
}
