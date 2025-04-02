//
//  ConsoleOut.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public protocol ConsoleOutDelegate: AnyObject {
    func displayMessageInConsole(message : String)
}

public class ConsoleOut: @unchecked Sendable {
    public weak var delegate : ConsoleOutDelegate?

    static public let shared = ConsoleOut()

    public func logMessage(message : String) {
        print(message)
        delegate?.displayMessageInConsole(message: message)
    }
}
