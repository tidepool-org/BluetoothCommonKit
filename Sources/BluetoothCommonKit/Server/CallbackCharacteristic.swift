//
//  CallbackCharacteristic.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CallbackCharacteristic: CBMutableCharacteristic {
    var ext_onWrite: ((Data?, CBCentral) -> CBATTError.Code)
    var ext_onRead: (() -> (CBATTError.Code, Data))
    public var isSubscribed: Bool = false
    
    public init(uuid: CBUUID,
                properties: CBCharacteristicProperties,
                value: Data? = nil,
                permissions: CBAttributePermissions,
                descriptors: [CBDescriptor]? = nil,
                _onWrite: @escaping ((Data?, CBCentral) -> CBATTError.Code),
                _onRead: @escaping (() -> (CBATTError.Code, Data)))
    {
        ext_onRead = _onRead
        ext_onWrite = _onWrite
        super.init(type: uuid, properties: properties, value: value, permissions: permissions)
        self.descriptors = descriptors
    }

    convenience public init(uuid: CBUUID,
                            properties: CBCharacteristicProperties,
                            value: Data? = nil,
                            permissions: CBAttributePermissions,
                            descriptors: [CBDescriptor]? = nil)
    {
        self.init(uuid: uuid,
                  properties: properties,
                  value: value,
                  permissions: permissions,
                  descriptors: descriptors,
                  _onWrite:  {(_,_) in return CBATTError.Code.success },
                  _onRead:  { return (CBATTError.Code.success, Data() ) })
    }

    public func onWrite(_ value : Data?, fromCentral central: CBCentral?) -> CBATTError.Code {
        guard let value = value,
              let central = central
        else { return .requestNotSupported }

        if !isSubscribed &&
            !super.properties.contains(.read) &&
            super.properties.contains(CBCharacteristicProperties.indicate) || super.properties.contains(CBCharacteristicProperties.notify) {
            return .improperlyConfigured
        } else {
            super.value = value
            return ext_onWrite(value, central)
        }
    }

    public func onRead() -> (CBATTError.Code, Data) {
        return ext_onRead()
    }

    public func subscribed(_ subscribed : Bool) {
        self.isSubscribed = subscribed
    }
}
