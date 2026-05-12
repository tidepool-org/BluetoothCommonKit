//
//  SecurityManager.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CryptoKit
import CryptoSwift
import os.log

public protocol SecurePersistentAuthentication {
    func setAuthenticationData(_ data: Data?, for keyService: String?) throws
    func getAuthenticationData(for keyService: String?) -> Data?
}

public protocol SecurityManagerDelegate: AnyObject {
    var sharedKeyData: Data? { get set }
    func securityManagerDidEstablishedSecurity(_ securityManager: SecurityManager)
    func securityManagerDidUpdateConfiguration(_ securityManager: SecurityManager)
}

public class SecurityManager {
    
    struct EncryptedContent {
        let ciphertext: Data
        let mac: Data
        let nonceData: Data
    }
    
    public weak var delegate: SecurityManagerDelegate?
    
    private let log = OSLog(category: "SecurityManager")
    
    public var generatedPrivateKey: SecKey?
    
    private var counterpartPublicKey: SecKey?
    
    private var lockedConfiguration: Locked<Configuration>

    private var isFirstNonce: Bool = true

    public var configuration: Configuration {
        get {
            return lockedConfiguration.value
        }
        set {
            if lockedConfiguration.value != newValue {
                lockedConfiguration.value = newValue
                delegate?.securityManagerDidUpdateConfiguration(self)
            }
        }
    }
    
    private(set) var generatedRandomNumberData: Data = Data((1...32).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
    
    var keyConfirmationCodeReceivedLittleEndian: Data?
    
    public var applicationSecurityEstablished: Bool {
        return delegate?.sharedKeyData != nil
    }
    
    public convenience init(sequenceNumber: UInt64 = 0) {
        self.init(configuration: Configuration())
        self.configuration.sequenceNumber = sequenceNumber
        self.isFirstNonce = true
    }

    public init(configuration: Configuration) {
        self.lockedConfiguration = Locked(configuration)
        self.isFirstNonce = false
        if !configuration.hasOOBRandomNumber && applicationSecurityEstablished {
            // the stored key is invalid and needs to be deleted
            deleteStoredKey()
        }
    }
    
    public func prepareForDeactivation() {
        deleteStoredKey()
    }
    
    //MARK: - Preparation Functions
    public func generateKeyPair() {
        let attributes = [kSecAttrKeySizeInBits: configuration.ellipticCurve.keySizeInBits,
                                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                            kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as [CFString : Any] as CFDictionary
        var error: Unmanaged<CFError>?
        
        generatedPrivateKey = SecKeyCreateRandomKey(attributes, &error)
        
        if error != nil {
            log.error("Private key creation failed %{public}@", error.debugDescription)
        }
    }
    
    func generateRandomNumber() {
        generatedRandomNumberData = Data((1...32).map { _ in UInt8.random(in: UInt8.min...UInt8.max) })
    }
    
    func deleteStoredKey() {
        delegate?.sharedKeyData = nil
        // sequence number is nonce for key
        configuration.resetSequenceNumber()
        isFirstNonce = true
    }
    
    func generateNewNonceFixed() -> Data {
        return configuration.generateNewNonceFixed()
    }
    
    //MARK: - Key functions
    public func generateSharedSecret(receivedPublicKeyData: Data) {
        var error: Unmanaged<CFError>?
        let publicAttributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                               kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                               kSecAttrKeySizeInBits as String: configuration.ellipticCurve.keySizeInBits,
                                               kSecPublicKeyAttrs as String: [kSecAttrIsPermanent: false]]
        
        var tempReceivedKeyData = receivedPublicKeyData
        tempReceivedKeyData.insert(4, at: 0)
        counterpartPublicKey = SecKeyCreateWithData(NSData(data: tempReceivedKeyData) as CFData, publicAttributes as CFDictionary, &error)
        guard error == nil,
              let generatedPrivateKey = generatedPrivateKey,
              let counterpartPublicKey = counterpartPublicKey else
        {
            log.error("public key creation failed %{public}@", error.debugDescription)
            return
        }
        
        let dict: [String: Any] = [:]
        delegate?.sharedKeyData = SecKeyCopyKeyExchangeResult(generatedPrivateKey,
                                                              SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                              counterpartPublicKey,
                                                              dict as CFDictionary,
                                                              &error) as Data?
        if error != nil {
            log.error("Shared key calculation failed %{public}@", error.debugDescription)
        }
    }
    
    func derivateSharedKey() -> Bool {
        guard let keyDerivationFunctionConfiguration = configuration.keyDerivationFunctionConfiguration,
              let sharedKeyData = delegate?.sharedKeyData
        else { return false }
        
        let salt = keyDerivationFunctionConfiguration.salt
        let info: Data = keyDerivationFunctionConfiguration.info
        
        let outputByteCount = keyDerivationFunctionConfiguration.keyDerivationFunction.outputByteCount
        
        let derivedKey: SymmetricKey
        switch keyDerivationFunctionConfiguration.keyDerivationFunction {
        case .hkdfSHA256:
            derivedKey = CryptoKit.HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: sharedKeyData), salt: salt, info: info, outputByteCount: outputByteCount)
        case .hkdfSHA384:
            derivedKey = CryptoKit.HKDF<SHA384>.deriveKey(inputKeyMaterial: SymmetricKey(data: sharedKeyData), salt: salt, info: info, outputByteCount: outputByteCount)
        case .hkdfSHA512:
            derivedKey = CryptoKit.HKDF<SHA512>.deriveKey(inputKeyMaterial: SymmetricKey(data: sharedKeyData), salt: salt, info: info, outputByteCount: outputByteCount)
        }
        
        self.delegate?.sharedKeyData = derivedKey.withUnsafeBytes { Data(Array($0)) }
        
        return true
    }
    
    public func getPublicKey(_ key: SecKey?) -> SecKey? {
        guard let key = key else {
            return nil
        }
        return SecKeyCopyPublicKey(key)
    }
    
    func convertPublicKeyToData(_ publicKey: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        
        guard let publicKeyRep04XY = (SecKeyCopyExternalRepresentation(publicKey, &error) as Data?) else {
            log.error("Error getting data representation of public key: %{public}@", String(describing: error))
            return nil
        }
        return publicKeyRep04XY.subdata(in: 1..<publicKeyRep04XY.count)
    }
    
    var sharedKeyData: Data? {
        get {
            delegate?.sharedKeyData
        }
        set {
            delegate?.sharedKeyData = newValue
        }
    }
    
    // Generated Key functions
    public func getGeneratedPublicKey() -> SecKey? {
        return getPublicKey(generatedPrivateKey)
    }
    
    func getGeneratedPublicKeyAsData() -> Data? {
        guard let publicKey = getGeneratedPublicKey() else {
            return nil
        }
        return convertPublicKeyToData(publicKey)
    }
    
    func getGeneratedPublicKeyX() -> Data? {
        guard let publicKey = getGeneratedPublicKeyAsData() else {
            return nil
        }
        let publicKeyX = publicKey.subdata(in: 0..<publicKey.count/2)
        return publicKeyX
    }
    
    func getGeneratedPublicKeyY() -> Data? {
        guard let publicKey = getGeneratedPublicKeyAsData() else {
            return nil
        }
        let publicKeyY = publicKey.subdata(in: publicKey.count/2..<publicKey.count)
        return publicKeyY
    }
    
    // Counterpart Key functions
    func getCounterpartPublicKeyAsData() -> Data? {
        guard let publicKey = counterpartPublicKey else {
            return nil
        }
        return convertPublicKeyToData(publicKey)
    }
    
    func getCounterpartPublicKeyX() -> Data? {
        guard let publicKey = getCounterpartPublicKeyAsData() else {
            return nil
        }
        let publicKeyX = publicKey.subdata(in: 0..<publicKey.count/2)
        return publicKeyX
    }
    
    func getCounterpartPublicKeyY() -> Data? {
        guard let publicKey = getCounterpartPublicKeyAsData() else {
            return nil
        }
        let publicKeyY = publicKey.subdata(in: publicKey.count/2..<publicKey.count)
        return publicKeyY
    }

    //MARK: - ECDH and related confirmation
    public func calculateGeneratedConfirmationCodeInLittleEndianClient() -> Data? {
        let message = generatedRandomNumberData
        
        guard var confirmationCode = calculateKeyConfirmationCodeClient(message: message) else {
            return nil
        }
        // security manager uses big endian. provide little endian
        confirmationCode.reverse()
        
        return confirmationCode
    }
    
    public func calculateGeneratedConfirmationCodeInLittleEndianServer() -> Data? {
        let message = generatedRandomNumberData
        
        guard var confirmationCode = calculateKeyConfirmationCodeServer(message: message) else {
            return nil
        }
        // security manager uses big endian. provide little endian
        confirmationCode.reverse()
        
        return confirmationCode
    }
    
    func calculateConfirmationKeyClient() -> Data? {
        guard let clientPublicKeyX = getGeneratedPublicKeyX(),
              let clientPublicKeyY = getGeneratedPublicKeyY(),
              let serverPublicKeyX = getCounterpartPublicKeyX(),
              let serverPublicKeyY = getCounterpartPublicKeyY(),
              let sharedKeyData = delegate?.sharedKeyData else
        {
            log.error("not ready to calculate the confirmation key")
            return nil
        }
        
        let zeroKeyData = Data(Array(repeating: 0x00, count: 16))
        
        var message = Data(serverPublicKeyX)
        message.append(contentsOf: serverPublicKeyY)
        message.append(contentsOf: clientPublicKeyX)
        message.append(contentsOf: clientPublicKeyY)
        
        var key = SymmetricKey(data: zeroKeyData)
        let saltKey = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        message = sharedKeyData
        message.append(Data(authValue))
        key = SymmetricKey(data: saltKey)
        let confirmationKey = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        return confirmationKey
    }
    
    func calculateConfirmationKeyServer() -> Data? {
        guard let serverPublicKeyX = getGeneratedPublicKeyX(),
              let serverPublicKeyY = getGeneratedPublicKeyY(),
              let clientPublicKeyX = getCounterpartPublicKeyX(),
              let clientPublicKeyY = getCounterpartPublicKeyY(),
              let sharedKeyData = delegate?.sharedKeyData else
        {
            log.error("not ready to calculate the confirmation key")
            return nil
        }
        
        let zeroKeyData = Data(Array(repeating: 0x00, count: 16))
        
        var message = Data(serverPublicKeyX)
        message.append(contentsOf: serverPublicKeyY)
        message.append(contentsOf: clientPublicKeyX)
        message.append(contentsOf: clientPublicKeyY)
        
        var key = SymmetricKey(data: zeroKeyData)
        let saltKey = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        message = sharedKeyData
        message.append(Data(authValue))
        key = SymmetricKey(data: saltKey)
        let confirmationKey = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        return confirmationKey
    }
    
    private var authValue: Data {
        // auth value is the OOB random number with zero padding
        var authValue = Data((1...32-configuration.oobRandomNumber.count).map { _ in UInt8(0) })
        authValue.append(configuration.oobRandomNumber)
        
        return authValue
    }
    
    func calculateKeyConfirmationCodeClient(message: Data) -> Data? {
        guard let confirmationKey = calculateConfirmationKeyClient() else {
            return nil
        }
        
        let key = SymmetricKey(data: confirmationKey)
        let confirmationCode = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        return confirmationCode
    }
    
    func calculateKeyConfirmationCodeServer(message: Data) -> Data? {
        guard let confirmationKey = calculateConfirmationKeyServer() else {
            return nil
        }
        
        let key = SymmetricKey(data: confirmationKey)
        let confirmationCode = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        return confirmationCode
    }
    
    func calculateKeyConfirmationReceivedLittleEndian(serverRandomNumberLittleEndian: Data) -> (calculatedConfirmationCode: Data?, validated: Bool) {
        // the security manager works in big endian
        let message = Data(serverRandomNumberLittleEndian.reversed())
        
        guard var calculatedKeyConfirmationReceived = calculateKeyConfirmationCodeClient(message: message) else {
            return (nil, false)
        }
        // security manager uses big endian. provide little endian
        calculatedKeyConfirmationReceived.reverse()
        
        return (calculatedKeyConfirmationReceived, calculatedKeyConfirmationReceived == keyConfirmationCodeReceivedLittleEndian)
    }
    
    func calculateKeyConfirmationReceivedLittleEndian(clientRandomNumberLittleEndian: Data) -> (calculatedConfirmationCode: Data?, validated: Bool) {
        // the security manager works in big endian
        let message = Data(clientRandomNumberLittleEndian.reversed())
        
        guard var calculatedKeyConfirmationReceived = calculateKeyConfirmationCodeServer(message: message) else {
            return (nil, false)
        }
        // security manager uses big endian. provide little endian
        calculatedKeyConfirmationReceived.reverse()
        
        return (calculatedKeyConfirmationReceived, calculatedKeyConfirmationReceived == keyConfirmationCodeReceivedLittleEndian)
    }
}

//MARK: - ECDH and related confirmation
extension SecurityManager {
    func keyExchangeResults(_ success: Bool) {
        if success {
            delegate?.securityManagerDidEstablishedSecurity(self)
        }
    }
}

//MARK: - Encryption and Decryption.
extension SecurityManager {
    
    func nextIV() -> Data {
        switch configuration.nonceType {
        case .sequenceNumberEvenOdd:
            if isFirstNonce {
                isFirstNonce = false
                configuration.sequenceNumber = configuration.isClient ? 1 : 0
            } else {
                configuration.sequenceNumber += 2
            }
        case .sequenceNumberDifferentFixedParts, .profileDefinedParameter:
            configuration.sequenceNumber += 1
        }
        var iv = configuration.generatedIVFixedField ?? configuration.receivedIVFixedField
        let sequenceNumberBigEndian = Data(bigEndian: configuration.sequenceNumber)
        iv.append(sequenceNumberBigEndian.suffix(configuration.nonceSizeOctetsVariable))
        return iv
    }
    
    // key actually used for crypto functions
    private var keyData: Data? {
        // Authorization Control Profile limits block cipher to AES-128. AES-128 key is limited to 16 octets. Take the MSO
        let keySize = 16
        guard let sharedKeyData = delegate?.sharedKeyData,
              sharedKeyData.count >= keySize
        else { return nil }
        return sharedKeyData.subdata(in: 0..<keySize)
    }
    
    func protectRequest(_ request: Data) -> Result<Data, SecurityManagerError> {
        // security manager uses in big endian, BT uses little endian
        let plaintext = Data(request.reversed())
        let result = encrypt(plaintext: plaintext)
        switch result {
        case .success(let encryptedContent):
            var protectedRequest = Data(configuration.securityConfigurationID)
            configuration.securityControls.forEach { control in
                switch control {
                case .nonce:
                    // only the sequence number is transmitted in little endian
                    let sequenceNumberLittleEndian = Data(configuration.sequenceNumber)
                    protectedRequest.append(sequenceNumberLittleEndian.prefix(configuration.nonceSizeOctetsVariable))
                case .mac:
                    // BT transmits in little endian byte order
                    protectedRequest.append(Data(encryptedContent.mac.reversed()))
                case .authenticatedEncryptedATTPacketWithAssociatedData, .authenticatedEncryptedATTPacket:
                    // BT transmits in little endian byte order
                    protectedRequest.append(Data(encryptedContent.ciphertext.reversed()))
                default:
                    log.error("Security control is not supported %{public}@", String(describing: control))
                }
            }
            return .success(protectedRequest)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func encrypt(plaintext: Data) -> Result<EncryptedContent, SecurityManagerError> {
        guard let keyData = keyData else {
            return .failure(.missingKey)
        }
        
        let nonceData = nextIV()
        return encrypt(plaintext: plaintext, keyData: keyData, nonceData: nonceData)
    }
    
    func encrypt(plaintext: Data, associateData: Data = Data(), keyData: Data, nonceData: Data) -> Result<EncryptedContent, SecurityManagerError> {
        switch configuration.algorithmType {
        case .aesGCM:
            return encryptGCM(plaintext: plaintext, associateData: associateData, keyData: keyData, nonceData: nonceData)
        case .aesCCM:
            return encryptCCM(plaintext: plaintext, associateData: associateData, keyData: keyData, nonceData: nonceData)
        default:
            return .failure(.unsupportedAlgorithm)
        }
    }

    private func encryptGCM(plaintext: Data, associateData: Data, keyData: Data, nonceData: Data) -> Result<EncryptedContent, SecurityManagerError> {
        do {
            let key = SymmetricKey(data: keyData)
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedContent = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: associateData)

            let reducedMac = Data(sealedContent.tag).subdata(in: 0..<configuration.macSize)
            return .success(EncryptedContent(ciphertext: sealedContent.ciphertext, mac: reducedMac, nonceData: nonceData))
        } catch let error {
            log.error("Error encrypting GCM %{public}@ plaintext: %{public}@ nonce: %{public}@", String(describing: error), plaintext.hexadecimalString, nonceData.hexadecimalString)
            return .failure(.encryptionFailed)
        }
    }

    private func encryptCCM(plaintext: Data, associateData: Data, keyData: Data, nonceData: Data) -> Result<EncryptedContent, SecurityManagerError> {
        do {
            let ccm = CCM(
                iv: nonceData.byteArray,
                tagLength: configuration.macSize,
                messageLength: plaintext.count,
                additionalAuthenticatedData: associateData.isEmpty ? nil : associateData.byteArray
            )
            let aes = try CryptoSwift.AES(key: keyData.byteArray, blockMode: ccm, padding: .noPadding)
            let encrypted = try aes.encrypt(plaintext.byteArray)

            let ciphertextBytes = Array(encrypted.prefix(encrypted.count - configuration.macSize))
            let macBytes = Array(encrypted.suffix(configuration.macSize))
            return .success(EncryptedContent(ciphertext: Data(ciphertextBytes), mac: Data(macBytes), nonceData: nonceData))
        } catch let error {
            log.error("Error encrypting CCM %{public}@ plaintext: %{public}@ nonce: %{public}@", String(describing: error), plaintext.hexadecimalString, nonceData.hexadecimalString)
            return .failure(.encryptionFailed)
        }
    }
    
    func decryptSecurePayload(_ securePayload: Data) -> Result<Data, SecurityManagerError> {
        guard let keyData = keyData else {
            return .failure(.missingKey)
        }
        
        let securityConfigurationID = securePayload[securePayload.startIndex...].to(UInt16.self)
        guard securityConfigurationID == configuration.securityConfigurationID else {
            log.error("Unexpected security configuration ID. Expected %d, received %d", configuration.securityConfigurationID, securityConfigurationID)
            return .failure(.incorrectSecurityConfiguration)
        }
        
        var index = 2
        var nonceData = configuration.receivedIVFixedField
        var mac = Data()
        var ciphertext = Data()
        
        configuration.securityControls.forEach { control in
            switch control {
            case .nonce:
                // only the sequence number is transmitted
                // BT use little endian byte order
                nonceData.append(contentsOf: securePayload.subdata(in: index..<index+configuration.nonceSizeOctetsVariable).reversed())
                index += configuration.nonceSizeOctetsVariable
            case .mac:
                // BT use little endian byte order
                mac = Data(securePayload.subdata(in: index..<index+configuration.macSize).reversed())
                index += configuration.macSize
            case .authenticatedEncryptedATTPacketWithAssociatedData, .authenticatedEncryptedATTPacket:
                // BT use little endian byte order
                ciphertext = Data(securePayload.subdata(in: index..<index+(securePayload.count - (2+configuration.macSize+configuration.nonceSizeOctetsVariable))).reversed())
                index += ciphertext.count
            default:
                log.error("Security control is not supported %{public}@", String(describing: control))
            }
        }
        
        let result = decrypt(ciphertext: ciphertext, keyData: keyData, nonceData: nonceData, mac: mac)
        switch result {
        case .success(var response):
            // security manager uses big endian, BT uses little endian
            response.reverse()
            return .success(response)
        default:
            return result
        }
    }
    
    func decrypt(ciphertext: Data, associateData: Data = Data(), keyData: Data, nonceData: Data, mac: Data) -> Result<Data, SecurityManagerError> {
        switch configuration.algorithmType {
        case .aesGCM:
            return decryptGCM(ciphertext: ciphertext, associateData: associateData, keyData: keyData, nonceData: nonceData, mac: mac)
        case .aesCCM:
            return decryptCCM(ciphertext: ciphertext, associateData: associateData, keyData: keyData, nonceData: nonceData, mac: mac)
        default:
            return .failure(.unsupportedAlgorithm)
        }
    }

    private func decryptGCM(ciphertext: Data, associateData: Data, keyData: Data, nonceData: Data, mac: Data) -> Result<Data, SecurityManagerError> {
        do {
            var ciphertextAndMac = ciphertext
            ciphertextAndMac.append(mac)
            let gcm = GCM(iv: nonceData.byteArray, tagLength: mac.count, mode: .combined)
            let aes = try CryptoSwift.AES(key: keyData.byteArray, blockMode: gcm, padding: .noPadding)
            let plaintext = try Data(aes.decrypt(ciphertextAndMac.byteArray))
            return .success(plaintext)
        } catch let error {
            log.error("Error decrypting GCM %{public}@ ciphertext: %{public}@ nonce: %{public}@ mac: %{public}@", String(describing: error), ciphertext.hexadecimalString, nonceData.hexadecimalString, mac.hexadecimalString)
            return .failure(.decryptionFailed)
        }
    }

    private func decryptCCM(ciphertext: Data, associateData: Data, keyData: Data, nonceData: Data, mac: Data) -> Result<Data, SecurityManagerError> {
        do {
            var ciphertextAndMac = ciphertext
            ciphertextAndMac.append(mac)
            let ccm = CCM(
                iv: nonceData.byteArray,
                tagLength: mac.count,
                messageLength: ciphertext.count,
                additionalAuthenticatedData: associateData.isEmpty ? nil : associateData.byteArray
            )
            let aes = try CryptoSwift.AES(key: keyData.byteArray, blockMode: ccm, padding: .noPadding)
            let plaintext = try Data(aes.decrypt(ciphertextAndMac.byteArray))
            return .success(plaintext)
        } catch let error {
            log.error("Error decrypting CCM %{public}@ ciphertext: %{public}@ nonce: %{public}@ mac: %{public}@", String(describing: error), ciphertext.hexadecimalString, nonceData.hexadecimalString, mac.hexadecimalString)
            return .failure(.decryptionFailed)
        }
    }
}

//MARK: - Security Manager Configuration.
extension SecurityManager {
    public struct Configuration: RawRepresentable, Equatable, Codable {
        
        public typealias RawValue = [String: Any]
        
        public static let version = 1
        
        private enum SecurityManagerConfigurationKey: String {
            case algorithmKeyID
            case algorithmType
            case generatedIVFixedField
            case certificateDeviceIdentifier
            case ecdhKeyID
            case ellipticCurve
            case isClient
            case kdfKeyID
            case kdfKeyDerivationFunction
            case keyDerivationFunctionConfiguration
            case macSize
            case nonceSizeOctetsVariable
            case nonceSizeOctetsFixed
            case nonceType
            case oobRandomNumber
            case securityConfigurationID
            case securityControls
            case sequenceNumber
            case receivedIVFixedField
            case version
        }
        
        public var oobRandomNumber: Data = Data()
        
        public var ecdhKeyID: KeyID = 1
        
        public var algorithmKeyID: KeyID = 2

        public var kdfKeyID: KeyID = 0

        public var kdfKeyDerivationFunction: KeyDerivationFunction?

        public var algorithmType: KeyType = .aesGCM

        public var isClient: Bool = true

        var ellipticCurve: EllipticCurve = .p256
        
        public var keyDerivationFunctionConfiguration: KeyDerivationFunctionConfiguration? = nil
        
        var securityControls: [SecurityControlType] = [.nonce, .mac, .authenticatedEncryptedATTPacketWithAssociatedData]
        
        public var macSize = 8
        
        var nonceType: NonceType = .sequenceNumberDifferentFixedParts
        
        public var nonceSizeOctetsVariable = 8
        
        public var receivedIVFixedField: Data = Data(UInt32(0xcafeaffe))
        
        public var generatedIVFixedField: Data?
        
        var sequenceNumber: UInt64 = 0
        
        var certificateDeviceIdentifier: CertificateDeviceIdentifier? = nil
        
        public mutating func resetSequenceNumber() {
            sequenceNumber = 0
        }
        
        var securityConfigurationID: UInt16 = 1
        
        var hasOOBRandomNumber: Bool {
            !oobRandomNumber.isEmpty
        }
        
        mutating func generateNewNonceFixed() -> Data {
            // the generated and counterpart fixed parts are the same size
            let size = receivedIVFixedField.count
            let generatedIVFixedField = Data((1...size).map { _ in UInt8.random(in: 0...UInt8.max) })
            self.generatedIVFixedField = generatedIVFixedField
            return generatedIVFixedField
        }
        
        public struct KeyDerivationFunctionConfiguration: Codable, Equatable {
            public let keyDerivationFunction: KeyDerivationFunction
            public var salt: Data
            public var info: Data

            public init(keyDerivationFunction: KeyDerivationFunction, salt: Data? = nil, info: Data = Data()) {
                self.keyDerivationFunction = keyDerivationFunction
                self.salt = salt ?? Data([UInt8](repeating: 0, count: keyDerivationFunction.hashLengthOctets))
                self.info = info
            }
        }
        
        struct CertificateDeviceIdentifier: Codable, Equatable {
            let deviceSerialNumber: String
            let certificateNonce: Int
        }
        
        public init() { }
        
        public init?(rawValue: RawValue) {
            guard let oobRandomNumber = rawValue[SecurityManagerConfigurationKey.oobRandomNumber.rawValue] as? Data,
                  let ecdhKeyID = rawValue[SecurityManagerConfigurationKey.ecdhKeyID.rawValue] as? KeyID,
                  let algorithmKeyID = rawValue[SecurityManagerConfigurationKey.algorithmKeyID.rawValue] as? KeyID,
                  let rawSecurityControls = rawValue[SecurityManagerConfigurationKey.securityControls.rawValue] as? Data,
                  let securityControls = try? PropertyListDecoder().decode([SecurityControlType].self, from: rawSecurityControls),
                  let macSize = rawValue[SecurityManagerConfigurationKey.macSize.rawValue] as? Int,
                  let nonceSizeOctetsVariable = rawValue[SecurityManagerConfigurationKey.nonceSizeOctetsVariable.rawValue] as? Int,
                  let sequenceNumber = rawValue[SecurityManagerConfigurationKey.sequenceNumber.rawValue] as? UInt64,
                  let securityConfigurationID = rawValue[SecurityManagerConfigurationKey.securityConfigurationID.rawValue] as? UInt16
            else {
                return nil
            }
            
            self.oobRandomNumber = oobRandomNumber
            self.ecdhKeyID = ecdhKeyID
            self.algorithmKeyID = algorithmKeyID
            if let kdfKeyID = rawValue[SecurityManagerConfigurationKey.kdfKeyID.rawValue] as? KeyID {
                self.kdfKeyID = kdfKeyID
            }
            if let rawKdfFunction = rawValue[SecurityManagerConfigurationKey.kdfKeyDerivationFunction.rawValue] as? KeyDerivationFunction.RawValue {
                self.kdfKeyDerivationFunction = KeyDerivationFunction(rawValue: rawKdfFunction)
            }
            if let rawAlgorithmType = rawValue[SecurityManagerConfigurationKey.algorithmType.rawValue] as? KeyType.RawValue,
               let algorithmType = KeyType(rawValue: rawAlgorithmType)
            {
                self.algorithmType = algorithmType
            }
            if let isClient = rawValue[SecurityManagerConfigurationKey.isClient.rawValue] as? Bool {
                self.isClient = isClient
            }
            self.securityControls = securityControls
            self.macSize = macSize
            self.nonceSizeOctetsVariable = nonceSizeOctetsVariable
            self.sequenceNumber = sequenceNumber
            self.securityConfigurationID = securityConfigurationID
            
            self.receivedIVFixedField = rawValue[SecurityManagerConfigurationKey.receivedIVFixedField.rawValue] as? Data ?? Data(UInt32(0xcafeaffe))
            self.generatedIVFixedField = rawValue[SecurityManagerConfigurationKey.generatedIVFixedField.rawValue] as? Data
            
            self.ellipticCurve = .p256
            if let rawEllipticCurve = rawValue[SecurityManagerConfigurationKey.ellipticCurve.rawValue] as? EllipticCurve.RawValue,
               let ellipticCurve = EllipticCurve(rawValue: rawEllipticCurve)
            {
                self.ellipticCurve = ellipticCurve
            }
            
            self.nonceType = .sequenceNumberEvenOdd
            if let rawNonceType = rawValue[SecurityManagerConfigurationKey.nonceType.rawValue] as? NonceType.RawValue,
               let nonceType = NonceType(rawValue: rawNonceType)
            {
                self.nonceType =  nonceType
            }
            
            if let rawKeyDerivationFunctionConfiguration = rawValue[SecurityManagerConfigurationKey.keyDerivationFunctionConfiguration.rawValue] as? Data,
               let keyDerivationFunctionConfiguration = try? PropertyListDecoder().decode(KeyDerivationFunctionConfiguration.self, from: rawKeyDerivationFunctionConfiguration)
            {
                self.keyDerivationFunctionConfiguration = keyDerivationFunctionConfiguration
            }
            
            if let rawKeyCertificateDeviceIdentifier = rawValue[SecurityManagerConfigurationKey.certificateDeviceIdentifier.rawValue] as? Data,
               let certificateDeviceIdentifier = try? PropertyListDecoder().decode(CertificateDeviceIdentifier.self, from: rawKeyCertificateDeviceIdentifier)
            {
                self.certificateDeviceIdentifier = certificateDeviceIdentifier
            }
        }
        
        public var rawValue: RawValue {
            var raw: RawValue = [
                SecurityManagerConfigurationKey.version.rawValue: SecurityManager.Configuration.version,
            ]
            raw[SecurityManagerConfigurationKey.oobRandomNumber.rawValue] = oobRandomNumber
            raw[SecurityManagerConfigurationKey.ecdhKeyID.rawValue] = ecdhKeyID
            raw[SecurityManagerConfigurationKey.algorithmKeyID.rawValue] = algorithmKeyID
            raw[SecurityManagerConfigurationKey.kdfKeyID.rawValue] = kdfKeyID
            raw[SecurityManagerConfigurationKey.kdfKeyDerivationFunction.rawValue] = kdfKeyDerivationFunction?.rawValue
            raw[SecurityManagerConfigurationKey.algorithmType.rawValue] = algorithmType.rawValue
            raw[SecurityManagerConfigurationKey.isClient.rawValue] = isClient
            raw[SecurityManagerConfigurationKey.ellipticCurve.rawValue] = ellipticCurve.rawValue
            let rawSecurityControls = try! PropertyListEncoder().encode(securityControls)
            raw[SecurityManagerConfigurationKey.securityControls.rawValue] = rawSecurityControls
            raw[SecurityManagerConfigurationKey.macSize.rawValue] = macSize
            raw[SecurityManagerConfigurationKey.nonceType.rawValue] = nonceType.rawValue
            raw[SecurityManagerConfigurationKey.nonceSizeOctetsVariable.rawValue] = nonceSizeOctetsVariable
            raw[SecurityManagerConfigurationKey.receivedIVFixedField.rawValue] = receivedIVFixedField
            raw[SecurityManagerConfigurationKey.generatedIVFixedField.rawValue] = generatedIVFixedField
            raw[SecurityManagerConfigurationKey.sequenceNumber.rawValue] = sequenceNumber
            raw[SecurityManagerConfigurationKey.securityConfigurationID.rawValue] = securityConfigurationID
            
            if let keyDerivationFunctionConfiguration = keyDerivationFunctionConfiguration {
                raw[SecurityManagerConfigurationKey.keyDerivationFunctionConfiguration.rawValue] = try? PropertyListEncoder().encode(keyDerivationFunctionConfiguration)
            }
            
            if let certificateDeviceIdentifier = certificateDeviceIdentifier {
                raw[SecurityManagerConfigurationKey.certificateDeviceIdentifier.rawValue] = try? PropertyListEncoder().encode(certificateDeviceIdentifier)
            }
            
            return raw
        }
    }
}
