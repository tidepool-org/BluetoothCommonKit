//
//  BluetoothManager.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import Foundation
import os.log
import UIKit

public protocol BluetoothManagerDelegate: AnyObject {
    /**
     Tells the delegate that the peripheral manager service configuration can be updated before applying the configuration

     - parameter manager: The bluetooth manager
     - parameter peripheralManager: The peripheral manager
     */
    func updatePeripheralConfigurationIfNeeded(_ manager: BluetoothManager, peripheralManager: PeripheralManager)
    
    /**
     Tells the delegate that the bluetooth manager has finished connecting to and discovering all required services and characteristics of its peripheral, or that it failed to do so

     - parameter manager: The bluetooth manager
     - parameter peripheralManager: The peripheral manager
     - parameter error:   An error describing why bluetooth setup failed
     */
    func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, isReadyWithError error: Error?)
    
    /**
    Tells the delegate that a peripheral was discovered

    - parameter manager: The bluetooth manager
    - parameter peripheralName: The found peripheral name
    - parameter identifier: The found peripheral identifier
    - parameter advertisementData: The found peripheral advertisement data
    - parameter signalStrength: The found peripheral signal strength (dB)

    - returns: True if the peripheral should connect
    */
    func bluetoothManager(_ manager: BluetoothManager, didDiscoverPeripheralWithName peripheralName: String?, identifier: UUID, advertisementData: [String: Any], signalStrength: NSNumber)
    
    /**
     Asks the delegate whether the discovered or restored peripheral should be connected

     - parameter manager:    The bluetooth manager
     - parameter peripheral: The found peripheral
     - returns: True if the peripheral should connect
     */
    func bluetoothManager(_ manager: BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral, advertisementData: [String: Any]?) -> Bool
    
    /**
     Informs the delegate that the bluetooth manager received new data on a characteristic
    
     - Parameters:
       - manager: The bluetooth manager
       - peripheralManager: The peripheral manager
       - value: The data received on the characteristic
       - uuid: The characteristic UUID
     */
    func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveValue value: Data, fromCharactistic uuid: CBUUID)

    /**
     Informs the delegate that the bluetooth manager encountered an error when interacting with a characteristic

     - Parameters:
       - manager: The bluetooth manager
       - peripheralManager: The peripheral manager
       - error: The error encounter
     */
    func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didEncounterError error: Error)
}


public class BluetoothManager: NSObject {

    public weak var delegate: BluetoothManagerDelegate? {
        didSet {
            if delegate != nil, oldValue == nil {
                // allow reporting of discovered peripherals even if they were discovered previously.
                discoveredPeripherals.removeAll()
            }
        }
    }

    private let log = OSLog(category: "BluetoothManager")

    /// Isolated to `managerQueue`
    private var centralManager: CBCentralManager!
    
    public var peripheralConfiguration: PeripheralManager.Configuration {
        didSet {
            peripheralManager?.configuration = peripheralConfiguration
        }
    }
    
    var servicesToDiscover: [CBUUID]
    
    /// Isolated to `managerQueue`
    private var peripheral: CBPeripheral? {
        get {
            return peripheralManager?.peripheral
        }
        set {
            guard let peripheral = newValue else {
                peripheralManager = nil
                return
            }

            if let peripheralManager = peripheralManager {
                peripheralManager.peripheral = peripheral
                peripheralIdentifier = peripheral.identifier
                peripheralManager.configuration = peripheralConfiguration
            } else {
                peripheralManager = PeripheralManager(
                    peripheral: peripheral,
                    configuration: peripheralConfiguration,
                    centralManager: centralManager
                )
            }
        }
    }
    
    private(set) var discoveredPeripherals: [CBPeripheral] = []
    
    public var peripheralIdentifier: UUID? {
        get {
            return lockedPeripheralIdentifier.value
        }
        set {
            lockedPeripheralIdentifier.value = newValue
        }
    }
    
    private let lockedPeripheralIdentifier: Locked<UUID?>

    /// Isolated to `managerQueue`
    public var peripheralManager: PeripheralManager? {
        didSet {
            oldValue?.delegate = nil
            peripheralManager?.delegate = self

            peripheralIdentifier = peripheralManager?.peripheral?.identifier
        }
    }

    // MARK: - Synchronization

    private let centralManagerQueue = DispatchQueue(label: "org.tidepool.BluetoothCommonKit.BluetoothManager.queue", qos: .unspecified)
    
    public init(peripheralIdentifier: UUID? = nil,
                peripheralConfiguration: PeripheralManager.Configuration,
                servicesToDiscover: [CBUUID],
                restoreOptions: [String: Any]? = [CBCentralManagerOptionRestoreIdentifierKey: "org.tidepool.BluetoothCommonKit"])
    {
        self.lockedPeripheralIdentifier = Locked(peripheralIdentifier)
        self.peripheralConfiguration = peripheralConfiguration
        self.servicesToDiscover = servicesToDiscover
        super.init()

        centralManagerQueue.sync {
            self.centralManager = CBCentralManager(delegate: self, queue: centralManagerQueue, options: restoreOptions)
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil, queue: nil) { [weak self] _ in
            guard let self = self,
                  self.peripheral?.state != .connected
            else { return }

            // if there is no peripheral connected, check if a peripheral has connected to iOS (not discoverable by just scanning)
            self.centralManagerQueue.sync {
                self.stopScanning()
                self.centralManagerQueueScanForPeripheral()
            }
        }
    }

    // MARK: - Actions

    private func reconnectToPeripheral() {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))
        log.debug("%{public}@ %{public}@", #function, String(describing: peripheralIdentifier?.uuidString))

        guard let peripheral = peripheralManager?.peripheral else {
            return
        }

        centralManager.connectIfNecessary(peripheral)
    }
    
    public func peripheral(forIdentifier identifier: UUID) -> CBPeripheral? {
        return discoveredPeripherals.first(where: { $0.identifier == identifier })
    }
    
    public func connectToPeripheral(withIdentifier identifier: UUID) {
        dispatchPrecondition(condition: .notOnQueue(centralManagerQueue))
        log.debug("%{public}@ %{public}@", #function, String(describing: identifier))

        guard let peripheral = peripheral(forIdentifier: identifier) else {
            return
        }
        
        self.peripheral = peripheral
        log.debug("Will connect to %{public}@", String(describing: peripheral))
        
        centralManagerQueue.sync {
            centralManager.connectIfNecessary(peripheral)
        }
    }

    public func disconnect() {
        dispatchPrecondition(condition: .notOnQueue(centralManagerQueue))
        log.debug("%{public}@", #function)

        centralManagerQueue.sync {
            stopScanning()

            if let peripheral = peripheral {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    public func prepareForDeactivation() {
        log.debug("%{public}@", #function)
        NotificationCenter.default.removeObserver(self)
        self.reset()
    }
    
    public func prepareForNewPeripheral() {
        dispatchPrecondition(condition: .notOnQueue(centralManagerQueue))
        log.debug("%{public}@", #function)

        centralManagerQueue.sync {
            centralManagerQueueScanForPeripheral()
        }
    }

    /// Cancels any active connection and starts a fresh scan. Unlike `prepareForNewPeripheral()`
    /// this bypasses the `retrievePeripherals(withIdentifiers:)` path that would
    /// otherwise reconnect to a cached `CBPeripheral` without firing discovery.
    public func rescanForPeripheral() {
        dispatchPrecondition(condition: .notOnQueue(centralManagerQueue))
        log.debug("%{public}@", #function)

        centralManagerQueue.sync {
            stopScanning()
            if let peripheral, peripheral.state != .disconnected {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            guard centralManager.state == .poweredOn else { return }
            scanForPeripherals()
        }
    }

    public func reset() {
        log.debug("%{public}@", #function)
        disconnect()
        peripheralManager = nil
        peripheralIdentifier = nil
        discoveredPeripherals = []
    }

    private func stopScanning() {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))
        log.debug("%{public}@", #function)
        if centralManager.isScanning == true {
            centralManager.stopScan()
        }
    }

    private func centralManagerQueueScanForPeripheral() {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))
        log.debug("%{public}@", #function)

        guard centralManager.state == .poweredOn else {
            return
        }

        let currentState = peripheral?.state ?? .disconnected
        if currentState == .connected, let peripheral = peripheral {
            // CBCentralManager state restoration (enabled via CBCentralManagerOptionRestoreIdentifierKey)
            // hands us back peripherals with `state == .connected` and a populated
            // `services` cache, but our app-level state machines (ACS auth, characteristic
            // subscriptions, ID handle map) are reset and never run if we bail here.
            // The didBecomeActive observer above already early-bails on .connected so
            // this branch only runs at launch / BT poweredOn. Force a clean reconnect:
            // cancelPeripheralConnection → didDisconnect → reconnectToPeripheral →
            // didConnect → normal post-connect flow.
            log.debug("Cancelling stale connection to %{public}@ before reconnect", peripheral.identifier.uuidString)
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        if let peripheralIdentifier = peripheralIdentifier,
            let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralIdentifier]).first
        {
            log.debug("Re-connecting to known peripheral %{public}@", peripheralIdentifier.uuidString)
            self.peripheral = peripheral
            centralManager.connect(peripheral)
        } else {
            let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: servicesToDiscover)
            log.debug("connectedPeripherals with services (%{public}@): %{public}@ ", servicesToDiscover, connectedPeripherals)
            for connectedPeripheral in connectedPeripherals {
                guard delegate?.bluetoothManager(self, shouldConnectPeripheral: connectedPeripheral, advertisementData: nil) == true else {
                    log.debug("do not connect to peripheral %{public}@", connectedPeripheral)
                    continue
                }

                log.debug("connecting to peripheral %{public}@", connectedPeripheral)
                self.peripheral = connectedPeripheral
                centralManager.connect(connectedPeripheral)
                return
            }

            log.debug("did not connect to a connected peripheral. Scanning for new peripherals")
            scanForPeripherals()
        }
    }

    private func scanForPeripherals() {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))
        log.debug("Scanning for peripherals")
        centralManager.scanForPeripherals(
            withServices: servicesToDiscover,
            options: nil
        )
    }

    // MARK: - Accessors

    public var isScanning: Bool {
        dispatchPrecondition(condition: .notOnQueue(centralManagerQueue))

        var isScanning = false
        centralManagerQueue.sync {
            isScanning = centralManager.isScanning
        }
        return isScanning
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))

        peripheralManager?.centralManagerDidUpdateState(central)
        log.info("%{public}@: %{public}@", #function, String(describing: central.state.rawValue))

        switch central.state {
        case .poweredOn:
            centralManagerQueueScanForPeripheral()
        case .poweredOff:
            if let peripheralManager = peripheralManager {
                delegate?.bluetoothManager(self, peripheralManager: peripheralManager, isReadyWithError: CBError(.peripheralDisconnected))
            }
            fallthrough
        case .resetting, .unauthorized, .unknown, .unsupported:
            fallthrough
        @unknown default:
            stopScanning()
        }
    }

    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))
        log.debug("%{public}@", #function)

        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                if delegate == nil || delegate!.bluetoothManager(self, shouldConnectPeripheral: peripheral, advertisementData: nil) {
                    log.info("Restoring peripheral from state: %{public}@", peripheral.identifier.uuidString)
                    self.peripheral = peripheral
                }
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))

        log.info("%{public}@: %{public}@ %{public}@ %{public}@", #function, peripheral, advertisementData, RSSI)
        if !discoveredPeripherals.contains(peripheral),
            let delegate = delegate
        {
            discoveredPeripherals.append(peripheral)
            if delegate.bluetoothManager(self, shouldConnectPeripheral: peripheral, advertisementData: advertisementData) {
                self.peripheral = peripheral
                centralManager.connect(peripheral)
            } else {
                delegate.bluetoothManager(self, didDiscoverPeripheralWithName: peripheral.name, identifier: peripheral.identifier, advertisementData: advertisementData, signalStrength: RSSI)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))

        log.info("%{public}@: %{public}@", #function, peripheral)
        stopScanning()

        peripheralManager?.centralManager(central, didConnect: peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))
        guard let peripheralManager = peripheralManager else { return }

        if let error = error as NSError? {
            log.error("%{public}@: %{public}@", #function, error)
            delegate?.bluetoothManager(self, peripheralManager: peripheralManager, isReadyWithError: error)
        } else {
            delegate?.bluetoothManager(self, peripheralManager: peripheralManager, isReadyWithError: CBError(.peripheralDisconnected))
        }

        if peripheralManager.configuration.willServiceSetChange {
            // when the service set changes, the peripheral identifier also changes and we need to scan for this.
            scanForPeripherals()
        } else {
            reconnectToPeripheral()
        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(centralManagerQueue))

        if let error = error, let peripheralManager = peripheralManager {
            delegate?.bluetoothManager(self, peripheralManager: peripheralManager, isReadyWithError: error)
        }

        reconnectToPeripheral()
    }
}

extension BluetoothManager: PeripheralManagerDelegate {
    func peripheralManager(_ peripheralManager: PeripheralManager, didReadRSSI RSSI: NSNumber, error: Error?) {
        log.debug("%{public}@ %{public}@ %{public}@ %{public}@", #function, peripheralManager, RSSI, (error?.localizedDescription ?? "no error"))
    }
    
    func peripheralManagerDidUpdateName(_ peripheralManager: PeripheralManager) {
        log.debug("%{public}@ %{public}@", #function, peripheralManager)
    }
    
    func completeConfiguration(for peripheralManager: PeripheralManager) throws {
        // delegate can further configure the peripheralManager, if needed.
        log.debug("%{public}@ %{public}@", #function, peripheralManager)
        delegate?.updatePeripheralConfigurationIfNeeded(self, peripheralManager: peripheralManager)
    }
    
    func didCompleteConfiguration(_ peripheralManager: PeripheralManager) {
        if self.peripheralManager == peripheralManager,
            case .poweredOn = centralManager.state,
            case .connected = peripheralManager.peripheral?.state
        {
            delegate?.bluetoothManager(self, peripheralManager: peripheralManager, isReadyWithError: nil)
        }
    }
    
    func peripheralManager(_ peripheralManager: PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic) {
        log.debug("%{public}@ %{public}@ %{public}@", #function, peripheralManager, characteristic)
        
        guard let value = characteristic.value else {
            return
        }
        
        log.debug("%{public}@", String(describing: value.hexadecimalString))

        let service: CBService? = characteristic.service
        guard let serviceUUID = service?.uuid,
              let serviceConfiguration = peripheralManager.configuration.serviceCharacteristics[serviceUUID],
              serviceConfiguration.contains(characteristic.uuid) else
        {
            return
        }
        
        delegate?.bluetoothManager(self, peripheralManager: peripheralManager, didReceiveValue: value, fromCharactistic: characteristic.uuid)
    }

    func didEncounterError(_ peripheralManager: PeripheralManager, error: Error) {
        delegate?.bluetoothManager(self, peripheralManager: peripheralManager, didEncounterError: error)
    }
}
