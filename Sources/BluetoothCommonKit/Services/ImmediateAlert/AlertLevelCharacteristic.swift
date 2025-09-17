//
//  AlertLevelCharacteristic.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-25.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import AVFoundation

// MARK: - Support Server Implementation
public class AlertLevelCharacteristic: WritableCharacteristic {
    var messageQueue: MessagingQueue
    
    public required init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    public func onWrite(_ request: Data?) -> CBATTError.Code {
        ConsoleOut.shared.logMessage(message: "\(#function) Alert Level request \(String(describing: request?.hexadecimalString))")
        guard let request = request else {
            return CBATTError.Code.invalidPdu
        }

        let alertLevel = AlertType(rawValue: request[request.startIndex...].to(AlertType.RawValue.self))

        switch alertLevel {
        case .mildAlert:
            let systemSoundID: SystemSoundID = 1052
            AudioServicesPlaySystemSound(systemSoundID)
        case .highAlert:
            let systemSoundID: SystemSoundID = 1304
            AudioServicesPlaySystemSound(systemSoundID)
        default:
            break
        }
        
        return CBATTError.Code.success
    }
}

public enum AlertType: UInt8 {
    case noAlert
    case mildAlert
    case highAlert
}
