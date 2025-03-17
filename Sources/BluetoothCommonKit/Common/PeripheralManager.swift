//
//  PeripheralManager.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import CoreBluetooth
import Foundation
import os.log

public class PeripheralManager: NSObject { 

    private let log = OSLog(category: "PeripheralManager")

    ///
    /// This is mutable, because CBPeripheral instances can seemingly become invalid, and need to be periodically re-fetched from CBCentralManager
    public var peripheral: CBPeripheral? {
        didSet {
            guard oldValue !== peripheral else {
                return
            }

            log.error("Replacing peripheral reference %{public}@ -> %{public}@", String(describing: oldValue), String(describing: peripheral))

            if let oldPeripheral = oldValue,
               oldPeripheral.state == .connected || oldPeripheral.state == .connecting
            {
                log.debug("cancelling connection to %{public}@", String(describing: oldPeripheral))
                centralManager?.cancelPeripheralConnection(oldPeripheral)
            }

            oldValue?.delegate = nil
            peripheral?.delegate = self

            queue.sync {
                needsConfiguration = true
            }
        }
    }

    /// The dispatch queue used to serialize operations on the peripheral
    let queue = DispatchQueue(label: "org.tidepool.InsulinDeliveryService.PeripheralManager.queue", qos: .unspecified)

    /// The condition used to signal command completion
    private let commandLock = NSCondition()

    /// The required conditions for the operation to complete
    private var commandConditions = [CommandCondition]()

    /// Any error surfaced during the active operation
    private var commandError: Error?

    private(set) weak var centralManager: CBCentralManager?

    var configuration: Configuration

    var willServiceSetChange: Bool {
        false
    }

    // Confined to `queue`
    private var needsConfiguration = true

    weak var delegate: PeripheralManagerDelegate? {
        didSet {
            guard delegate != nil else { return }
            queue.sync {
                needsConfiguration = true
            }
        }
    }

    public init(peripheral: CBPeripheral, configuration: Configuration, centralManager: CBCentralManager?) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        self.configuration = configuration

        super.init()

        peripheral.delegate = self

        assertConfiguration()
    }
    
    // ONLY FOR TESTING
    override public init() {
        self.configuration = Configuration(serviceCharacteristics: [ACCharacteristicUUID.service.cbUUID: [ACCharacteristicUUID.controlPoint.cbUUID]], notifyingCharacteristics: [ACCharacteristicUUID.service.cbUUID: [ACCharacteristicUUID.controlPoint.cbUUID]], valueUpdateMacros: [:])

        super.init()
    }
}


// MARK: - Nested types
public extension PeripheralManager {
    struct Configuration {
        var serviceCharacteristics: [CBUUID: [CBUUID]] = [:]
        var notifyingCharacteristics: [CBUUID: [CBUUID]] = [:]
        var valueUpdateMacros: [CBUUID: (_ manager: PeripheralManager) -> Void] = [:]
        
        public init(serviceCharacteristics: [CBUUID : [CBUUID]], notifyingCharacteristics: [CBUUID : [CBUUID]], valueUpdateMacros: [CBUUID : (_: PeripheralManager) -> Void]) {
            self.serviceCharacteristics = serviceCharacteristics
            self.notifyingCharacteristics = notifyingCharacteristics
            self.valueUpdateMacros = valueUpdateMacros
        }
    }

    enum CommandCondition {
        case notificationStateUpdate(characteristic: CBCharacteristic, enabled: Bool)
        case valueUpdate(characteristic: CBCharacteristic, matching: ((Data?) -> Bool)?)
        case write(characteristic: CBCharacteristic)
        case discoverServices
        case discoverCharacteristicsForService(serviceUUID: CBUUID)
    }
}

extension PeripheralManager.Configuration: Equatable {
    public static func == (lhs: PeripheralManager.Configuration, rhs: PeripheralManager.Configuration) -> Bool {
        return lhs.serviceCharacteristics == rhs.serviceCharacteristics &&
        lhs.notifyingCharacteristics == rhs.notifyingCharacteristics
    }
}

protocol PeripheralManagerDelegate: AnyObject {
    func peripheralManager(_ peripheralManager: PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic)

    func peripheralManager(_ peripheralManager: PeripheralManager, didReadRSSI RSSI: NSNumber, error: Error?)

    func peripheralManagerDidUpdateName(_ peripheralManager: PeripheralManager)

    func completeConfiguration(for peripheralManager: PeripheralManager) throws
    
    func didCompleteConfiguration(_ peripheralManager: PeripheralManager)

    func didEncounterError(_ peripheralManager: PeripheralManager, error: Error)
}


// MARK: - Operation sequence management
extension PeripheralManager {
    func configureAndRun(_ block: @escaping (_ manager: PeripheralManager) -> Void) -> (() -> Void) {
        return {
            if !self.needsConfiguration && self.peripheral?.services == nil {
                self.log.error("Configured peripheral has no services. Reconfiguring…")
            }

            if self.needsConfiguration || self.peripheral?.services == nil {
                do {
                    try self.applyConfiguration()
                    self.log.default("Peripheral configuration completed")
                } catch let error {
                    self.log.error("Error applying peripheral configuration: %{public}@", String(describing: error))
                    return
                }

                do {
                    if let delegate = self.delegate {
                        try delegate.completeConfiguration(for: self)
                        self.log.default("Delegate configuration completed")
                        self.needsConfiguration = false
                    } else {
                        self.log.error("No delegate set configured")
                    }
                } catch let error {
                    self.log.error("Error applying delegate configuration: %@", String(describing: error))
                }
            }

            block(self)
        }
    }

    public func perform(_ block: @escaping (_ peripheralManager: PeripheralManager) -> Void) {
        queue.async(execute: configureAndRun(block))
    }

    private func assertConfiguration() {
        perform { (_) in
            // Intentionally empty to trigger configuration if necessary
        }
    }

    private func applyConfiguration(discoveryTimeout: TimeInterval = 2) throws {
        try discoverServices(configuration.serviceCharacteristics.keys.map { $0 }, timeout: discoveryTimeout)

        for service in peripheral?.services ?? [] {
            guard let characteristics = configuration.serviceCharacteristics[service.uuid] else {
                // Not all services may have characteristics
                continue
            }

            try discoverCharacteristics(characteristics, for: service, timeout: discoveryTimeout)
        }

        for (serviceUUID, characteristicUUIDs) in configuration.notifyingCharacteristics {
            guard let service = peripheral?.services?.itemWithUUID(serviceUUID) else {
                throw PeripheralManagerError.unknownCharacteristic
            }

            for characteristicUUID in characteristicUUIDs {
                guard let characteristic = service.characteristics?.itemWithUUID(characteristicUUID) else {
                    throw PeripheralManagerError.unknownCharacteristic
                }

                guard !characteristic.isNotifying else {
                    continue
                }

                try setNotifyValue(true, for: characteristic, timeout: discoveryTimeout)
            }
        }
        
        if peripheral?.services != nil {
            delegate?.didCompleteConfiguration(self)
        }
    }
}


// MARK: - Synchronous Commands
public extension PeripheralManager {
    /// - Throws: PeripheralManagerError
    func runCommand(timeout: TimeInterval, command: () -> Void) throws {
        // Prelude
        dispatchPrecondition(condition: .onQueue(queue))
        guard centralManager?.state == .poweredOn && peripheral?.state == .connected else {
            throw PeripheralManagerError.notReady
        }

        commandLock.lock()

        defer {
            commandLock.unlock()
        }

        guard commandConditions.isEmpty else {
            throw PeripheralManagerError.notReady
        }

        // Run
        command()

        guard !commandConditions.isEmpty else {
            // If the command didn't add any conditions, then finish immediately
            return
        }

        // Postlude
        let signaled = commandLock.wait(until: Date(timeIntervalSinceNow: timeout))

        defer {
            commandError = nil
            commandConditions = []
        }

        guard signaled else {
            throw PeripheralManagerError.timeout
        }

        if let error = commandError {
            throw PeripheralManagerError.cbPeripheralError(error)
        }
    }

    /// It's illegal to call this without first acquiring the commandLock
    ///
    /// - Parameter condition: The condition to add
    internal func addCondition(_ condition: CommandCondition) {
        dispatchPrecondition(condition: .onQueue(queue))
        commandConditions.append(condition)
    }

    func discoverServices(_ serviceUUIDs: [CBUUID], timeout: TimeInterval) throws {
        try runCommand(timeout: timeout) {
            // get all services, since 2 service sets are possible and the advertising data does not hint as to which is active
            addCondition(.discoverServices)
            peripheral?.discoverServices(nil)
        }
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID], for service: CBService, timeout: TimeInterval) throws {

        guard let characteristicsToDiscover = peripheral?.characteristicsToDiscover(from: characteristicUUIDs, for: service),
              !characteristicsToDiscover.isEmpty
        else {
            return
        }

        try runCommand(timeout: timeout) {
            addCondition(.discoverCharacteristicsForService(serviceUUID: service.uuid))

            peripheral?.discoverCharacteristics(characteristicsToDiscover, for: service)
        }
    }

    /// - Throws: PeripheralManagerError
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic, timeout: TimeInterval) throws {
        try runCommand(timeout: timeout) {
            addCondition(.notificationStateUpdate(characteristic: characteristic, enabled: enabled))

            peripheral?.setNotifyValue(enabled, for: characteristic)
        }
    }

    /// - Throws: PeripheralManagerError
    func readValue(for characteristic: CBCharacteristic, timeout: TimeInterval) throws -> Data? {
        try runCommand(timeout: timeout) {
            addCondition(.valueUpdate(characteristic: characteristic, matching: nil))

            peripheral?.readValue(for: characteristic)
        }

        return characteristic.value
    }

    /// - Throws: PeripheralManagerError
    func wait(for characteristic: CBCharacteristic, timeout: TimeInterval) throws -> Data {
        try runCommand(timeout: timeout) {
            addCondition(.valueUpdate(characteristic: characteristic, matching: nil))
        }

        guard let value = characteristic.value else {
            throw PeripheralManagerError.timeout
        }

        return value
    }

    /// - Throws: PeripheralManagerError
    func writeValue(_ value: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType, timeout: TimeInterval) throws {
        try runCommand(timeout: timeout) {
            if case .withResponse = type {
                addCondition(.write(characteristic: characteristic))
            }

            log.debug("%{public}@ value %{public}@ characteristic %{public}@", #function, value.toHexString(), characteristic.uuid)
            peripheral?.writeValue(value, for: characteristic, type: type)
        }
    }
}


// MARK: - Delegate methods executed on the central managers's queue
extension PeripheralManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        log.debug("%{public}@ %{public}@ services %{public}@ %{public}@", #function, peripheral, String(describing: peripheral.services), String(describing: error))
        commandLock.lock()

        if let index = commandConditions.firstIndex(where: { (condition) -> Bool in
            if case .discoverServices = condition {
                return true
            } else {
                return false
            }
        }) {
            commandConditions.remove(at: index)
            commandError = error

            if commandConditions.isEmpty {
                commandLock.broadcast()
            }
        }

        commandLock.unlock()
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        log.debug("%{public}@ %{public}@ service %{public}@ %{public}@", #function, peripheral, service.uuid, String(describing: error))
        commandLock.lock()

        if let index = commandConditions.firstIndex(where: { (condition) -> Bool in
            if case .discoverCharacteristicsForService(serviceUUID: service.uuid) = condition {
                return true
            } else {
                return false
            }
        }) {
            commandConditions.remove(at: index)
            commandError = error

            if commandConditions.isEmpty {
                commandLock.broadcast()
            }
        }

        commandLock.unlock()
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        log.debug("%{public}@ %{public}@ characteristic %{public}@ %{public}@", #function, peripheral, characteristic.uuid, String(describing: error))
        commandLock.lock()

        if let error = error {
            delegate?.didEncounterError(self, error: error)
        }

        if let index = commandConditions.firstIndex(where: { (condition) -> Bool in
            if case .notificationStateUpdate(characteristic: characteristic, enabled: characteristic.isNotifying) = condition {
                return true
            } else {
                return false
            }
        }) {
            commandConditions.remove(at: index)
            commandError = error

            if commandConditions.isEmpty {
                commandLock.broadcast()
            }
        }

        commandLock.unlock()
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        log.debug("%{public}@ %{public}@ characteristic %{public}@ error %{public}@", #function, peripheral, characteristic.uuid, String(describing: error))
        commandLock.lock()

        if let error = error {
            delegate?.didEncounterError(self, error: error)
        }

        if let index = commandConditions.firstIndex(where: { (condition) -> Bool in
            if case .write(characteristic: characteristic) = condition {
                return true
            } else {
                return false
            }
        }) {
            commandConditions.remove(at: index)
            commandError = error

            if commandConditions.isEmpty {
                commandLock.broadcast()
            }
        }

        commandLock.unlock()
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        log.debug("%{public}@ %{public}@ characteristic %{public}@ value %{public}@ %{public}@", #function, peripheral, characteristic.uuid, characteristic.value?.toHexString() ?? "No value", String(describing: error))
        commandLock.lock()

        var notifyDelegate = false

        if let index = commandConditions.firstIndex(where: { (condition) -> Bool in
            if case .valueUpdate(characteristic: characteristic, matching: let matching) = condition {
                return matching?(characteristic.value) ?? true
            } else {
                return false
            }
        }) {
            commandConditions.remove(at: index)
            commandError = error

            if commandConditions.isEmpty {
                commandLock.broadcast()
            }
        } else if let macro = configuration.valueUpdateMacros[characteristic.uuid] {
            macro(self)
        } else { // always notify unexpected updates to characteristic values
            notifyDelegate = true // execute after the unlock
        }

        commandLock.unlock()

        if notifyDelegate {
            // If we weren't expecting this notification, pass it along to the delegate
            delegate?.peripheralManager(self, didUpdateValueFor: characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        delegate?.peripheralManager(self, didReadRSSI: RSSI, error: error)
    }

    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        delegate?.peripheralManagerDidUpdateName(self)
    }
}


extension PeripheralManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ centralManager: CBCentralManager) {
        switch centralManager.state {
        case .poweredOn:
            assertConfiguration()
        default:
            break
        }
    }

    public func centralManager(_ centralManager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        switch peripheral.state {
        case .connected:
            assertConfiguration()
        default:
            break
        }
    }
}


extension PeripheralManager {
    public override var debugDescription: String {
        var items = [
            "## PeripheralManager",
            "peripheral: \(String(describing: peripheral))",
        ]
        queue.sync {
            items.append("needsConfiguration: \(needsConfiguration)")
        }
        return items.joined(separator: "\n")
    }
}
