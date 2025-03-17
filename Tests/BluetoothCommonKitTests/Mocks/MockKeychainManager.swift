//
//  MockKeychainManager.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-17.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import BluetoothCommonKit

class MockKeychainManager: SecurePersistentAuthentication {
    var storage: [String: Data] = [:]
    
    func setAuthenticationData(_ data: Data?, for keyService: String?) throws {
        guard let keyService = keyService else {
            return
        }

        storage[keyService] = data
    }

    func getAuthenticationData(for keyService: String?) -> Data? {
        guard let keyService = keyService else {
            return nil
        }
        
        return storage[keyService]
    }
}
