//
//  GATTServer.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-04-02.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth

public class GATTServer: NSObject, GATTService {
    public func preWriteConstrain(_ preWriteConstrain: @escaping ([CallbackCharacteristic]) -> CBATTError.Code) {
        self.preWriteConstrain = preWriteConstrain
    }

    var peripheralManager: CBPeripheralManager!
    var services: [CBMutableService] = []
    var characteristics: [CBMutableService: [CallbackCharacteristic]] = [:]
    var startAdvertisementCalled: Bool = false
    var wasServiceAdded: Bool = false
    var wasServiceAddRequested: Bool = false
    var e2eProtectionEnabled: Bool = false
    var preWriteConstrain: ([CallbackCharacteristic]) -> CBATTError.Code
    var advertisedName: String
    var advertisedServices: [CBUUID]
    var serviceProvidedAdvertisementDataHandler: (() -> [String: Any]?)?

    public var subscribedCentrals: [CBCentral] = []
    public weak var delegate: GATTServiceDelegate?
    public weak var observers: GATTServiceObservers?

    public init(advertisedName: String, advertisedServices: [CBUUID]) {
        self.advertisedName = advertisedName
        self.advertisedServices = advertisedServices
        self.preWriteConstrain = { _ in return CBATTError.Code.success }
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        ConsoleOut.shared.logMessage(message: "State:\(peripheralManager.state)");
    }

    public func createService(_ serviceUUID: CBUUID, primary: Bool, withCharacteristics characteristics: [CallbackCharacteristic]) {
        let service = CBMutableService(type: serviceUUID, primary: primary)
        ConsoleOut.shared.logMessage(message: "\(#function) UUID: \(serviceUUID), primary: \(primary): \(service.debugDescription)")

        self.characteristics[service] = characteristics

        for characteristic in characteristics {
            service.addCharacteristic(characteristic)
        }

        ConsoleOut.shared.logMessage(message: "Characteristics has been added: \(characteristics.debugDescription)")

        services.append(service)
        ConsoleOut.shared.logMessage(message: "Service has been added: \(service.debugDescription)")
    }

    public func addService() {
        wasServiceAddRequested = true
        handleAddService()
    }

    func handleAddService() {
        if wasServiceAddRequested == true,
           CBManagerState.poweredOn == (peripheralManager.state)
        {
            for service in services {
                peripheralManager.add(service)
                ConsoleOut.shared.logMessage(message: "\(#function) service: \(service.debugDescription)")
                ConsoleOut.shared.logMessage(message: "\(#function) service characteristics: \(service.characteristics.debugDescription)")
            }
        }
    }

    /**
     searches the characteristics for the one the has the same UUID. Returns nil if not found.
     */
    public func getMutableCharacteristicForUUID (_ forUUID: CBUUID) -> CallbackCharacteristic? {
        for (_, characteristics) in self.characteristics {
            let characteristic = characteristics.filter { (characteristic) in characteristic.uuid.isEqual(forUUID) }.first
            if characteristic != nil {
                return characteristic
            }
        }

        return nil
    }

    public func isCharacteristicSubscribed (_ forUUID: CBUUID) -> Bool? {
        return getMutableCharacteristicForUUID(forUUID)?.isSubscribed
    }

    public func update(_ data: Data?, forUUID: CBUUID, onSubscribedCentrals: [CBCentral]? = nil) {
        ConsoleOut.shared.logMessage(message: "Response data: \(data!.hexadecimalString)")
        guard let data = data,
              let characteristic = getMutableCharacteristicForUUID(forUUID)
        else {
            if getMutableCharacteristicForUUID(forUUID) == nil {
                ConsoleOut.shared.logMessage(message: "UUID: \(forUUID), data: \(String(describing: data)): No characteristic found!")
            }
            if data == nil {
                ConsoleOut.shared.logMessage(message: "UUID: \(forUUID), data: \(String(describing: data)): Data was nil!")
            }
            return
        }

        characteristic.value = data
        if peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: onSubscribedCentrals) {
            observers?.readyToSend()
        }
    }

    public func startAdvertising(advertisementDataHandler: @escaping () -> [String: Any]?) {
        startAdvertisementCalled = true
        handleAddService()
        serviceProvidedAdvertisementDataHandler = advertisementDataHandler
        handleAdvertisementStart()
        print("\(#function): \(String(describing: peripheralManager))")
    }

    public func handleAdvertisementStart() {
        print("startAdvertising was called \(CBManagerState.poweredOn == peripheralManager.state) && \(startAdvertisementCalled) && \(wasServiceAdded)")
        peripheralManager.stopAdvertising()
        if CBManagerState.poweredOn == peripheralManager.state,
           startAdvertisementCalled,
           wasServiceAdded
        {
            var advertisementData: [String: Any] = serviceProvidedAdvertisementDataHandler?() ?? [:]
            advertisementData[CBAdvertisementDataLocalNameKey] = advertisedName
            advertisementData[CBAdvertisementDataServiceUUIDsKey] = advertisedServices
            peripheralManager.startAdvertising(advertisementData)
            ConsoleOut.shared.logMessage(message: "startAdvertising was executed with advertisementData \(advertisementData)")
        }
    }
}

extension GATTServer: CBPeripheralManagerDelegate {

    @objc public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            ConsoleOut.shared.logMessage(message: "state: \(peripheral.state) State changed to PoweredOn")
            handleAddService()
            handleAdvertisementStart()
        case .poweredOff:
            ConsoleOut.shared.logMessage(message: "powered off")
            peripheralManager.stopAdvertising()
        case CBManagerState.unknown: ConsoleOut.shared.logMessage(message: "state unknown")
        case CBManagerState.resetting: ConsoleOut.shared.logMessage(message: "state resetting")
        case CBManagerState.unsupported: ConsoleOut.shared.logMessage(message: "unsupported")
        case CBManagerState.unauthorized: ConsoleOut.shared.logMessage(message: "unauthorized")
        @unknown default:
            fatalError("unknown peripheral state")
        }
    }

    @objc public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard let error = error else {
            ConsoleOut.shared.logMessage(message: "peripheralManagerDidStartAdvertising: Succeeded!")
            print("\(#function): \(String(describing: peripheralManager))")
            print("\(#function): \(String(describing: services))")
            return
        }
        ConsoleOut.shared.logMessage(message: "peripheralManagerDidStartAdvertising: Failed… error: \(error)")
    }

    @objc public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard let error = error else {
            wasServiceAdded = true
            handleAdvertisementStart()
            ConsoleOut.shared.logMessage(message: "\(#function) service \(service) has been added to \(String(describing: peripheralManager))")
            return
        }
        ConsoleOut.shared.logMessage(message: "\(#function) service: \(service), error: \(error)")
    }

    @objc public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if let characteristic = getMutableCharacteristicForUUID(request.characteristic.uuid) {
            // Respond to the request
            let result = characteristic.onRead().0
            let data = characteristic.onRead().1

            // Set the correspondent characteristic's value
            // to the request
            request.value = data

            ConsoleOut.shared.logMessage(message: "Read_Response data: \(String(describing: request.value?.hexadecimalString))")

            peripheralManager.respond(
                to: request,
                withResult: result)
        }
    }

    @objc public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        let preCondition:CBATTError.Code = CBATTError.Code.success //preWriteConstrain(characteristics.values.first!) TODO not sure what this was intended to do
        for request in requests {
            guard delegate?.isProcedureAlreadyInProgress() != true else {
                peripheralManager.respond(to: request, withResult: .procedureAlreadyInProgress)
                continue
            }

            guard delegate?.isOutOfRange() != true else {
                peripheralManager.respond(to: request, withResult: .outOfRange)
                continue
            }

            if let characteristic = getMutableCharacteristicForUUID(request.characteristic.uuid) {
                // Set the request's value
                // to the correspondent characteristic
                if preCondition != CBATTError.Code.success {
                    peripheralManager.respond(to: request, withResult: preCondition)
                } else {
                    let result = characteristic.onWrite(request.value, fromCentral: request.central)
                    ConsoleOut.shared.logMessage(message: "Write_Request data: \(String(describing: request.value?.hexadecimalString))")
                    peripheralManager.respond(to: request, withResult: result)
                }
            }
        }
    }

    @objc public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic)
    {
        ConsoleOut.shared.logMessage(message: "central \(central.description) subscribed to: \( characteristic.uuid)")
        getMutableCharacteristicForUUID(characteristic.uuid)?.subscribed(true)
        if !subscribedCentrals.contains(central) {
            subscribedCentrals.append(central)
        }
        delegate?.centralDidSubscribe(characteristicUUID: characteristic.uuid)
    }

    @objc public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic)
    {
        ConsoleOut.shared.logMessage(message: "central \(central.description) unsubscribed from: \( characteristic.uuid)")
        subscribedCentrals.removeAll(where: { $0 == central })
        getMutableCharacteristicForUUID(characteristic.uuid)?.subscribed(false)
        delegate?.centralDidUnsubscribe(characteristicUUID: characteristic.uuid)
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        observers?.readyToSend()
    }

    public func disconnect() {
        ConsoleOut.shared.logMessage(message: "Disconnecting")
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
    }
}

extension CBMutableService {
    public func addCharacteristic(_ callbackCharacteristic: CallbackCharacteristic) {
        if characteristics == nil {
            characteristics = []
        }
        //service.characteristics!.append(callbackCharacteristic)
        characteristics?.append(callbackCharacteristic)
        ConsoleOut.shared.logMessage(message: "Characteristic has been added: \(characteristics.debugDescription)")
    }
}
