//
//  SecurityManager.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

// TODO should the security manager be added in the package or in the IDS pump manager?

import Foundation
import CryptoKit
// TODO should this be removed?
import CryptoSwift
import os.log

public protocol SecurePersistentAuthentication {
    func setAuthenticationData(_ data: Data?, for keyService: String?) throws
    func getAuthenticationData(for keyService: String?) -> Data?
}

protocol SecurityManagerDelegate: AnyObject {
    var sharedKeyData: Data? { get set }
    func getCertificateData() -> Data?
    func securityManagerDidEstablishedSecurity(_ securityManager: SecurityManager)
    func securityManagerDidUpdateConfiguration(_ securityManager: SecurityManager)
}

public class SecurityManager {
    
    struct EncryptedContent {
        let ciphertext: Data
        let mac: Data
        let nonceData: Data
    }
    
    weak var delegate: SecurityManagerDelegate?
    
    private let log = OSLog(category: "SecurityManager")
    
    private(set) var clientPrivateKey: SecKey?
    
    private var serverPublicKey: SecKey?
    
    private var lockedConfiguration: Locked<Configuration>
    
    var configuration: Configuration {
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
    
    private(set) var clientRandomNumberData: Data = Data((1...32).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
    
    var keyConfirmationCodeServerLittleEndian: Data?
    
    var applicationSecurityEstablished: Bool {
        return delegate?.sharedKeyData != nil
    }
    
    public convenience init(sequenceNumber: UInt64 = 0) {
        self.init(configuration: Configuration())
        self.configuration.sequenceNumber = sequenceNumber
    }
    
    public init(configuration: Configuration)
    {
        self.lockedConfiguration = Locked(configuration)
        if !configuration.hasOOBRandomNumber && applicationSecurityEstablished {
            // the stored key is invalid and needs to be deleted
            deleteStoredKey()
        }
    }
    
    func prepareForDeactivation() {
        deleteStoredKey()
    }
    
    //MARK: - Preparation Functions
    func generateKeyPair() {
        let attributes = [kSecAttrKeySizeInBits: configuration.ellipticCurve.keySizeInBits,
                                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                            kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]] as [CFString : Any] as CFDictionary
        var error: Unmanaged<CFError>?
        
        clientPrivateKey = SecKeyCreateRandomKey(attributes, &error)
        
        if error != nil {
            log.error("Private key creation failed %{public}@", error.debugDescription)
        }
    }
    
    func generateRandomNumber() {
        clientRandomNumberData = Data((1...32).map { _ in UInt8.random(in: UInt8.min...UInt8.max) })
    }
    
    func deleteStoredKey() {
        delegate?.sharedKeyData = nil
        // sequence number is nonce for key
        configuration.resetSequenceNumber()
    }
    
    func generateNewClientNonceFixed() -> Data {
        return configuration.generateNewClientNonceFixed()
    }
    
    //MARK: - Key functions
    public func generateSharedSecret(serverPublicKeyData: Data) {
        var error: Unmanaged<CFError>?
        let publicAttributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                               kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                               kSecAttrKeySizeInBits as String: configuration.ellipticCurve.keySizeInBits,
                                               kSecPublicKeyAttrs as String: [kSecAttrIsPermanent: false]]
        
        var tempServerKeyData = serverPublicKeyData
        tempServerKeyData.insert(4, at: 0)
        serverPublicKey = SecKeyCreateWithData(NSData(data: tempServerKeyData) as CFData, publicAttributes as CFDictionary, &error)
        guard error == nil,
              let clientPrivateKey = clientPrivateKey,
              let serverPublicKey = serverPublicKey else
        {
            log.error("Server public key creation failed %{public}@", error.debugDescription)
            return
        }
        
        let dict: [String: Any] = [:]
        delegate?.sharedKeyData = SecKeyCopyKeyExchangeResult(clientPrivateKey,
                                                              SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                              serverPublicKey,
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
    
    // Client Key functions
    public func getClientPublicKey() -> SecKey? {
        return getPublicKey(clientPrivateKey)
    }
    
    func getClientPublicKeyAsData() -> Data? {
        guard let publicKey = getClientPublicKey() else {
            return nil
        }
        return convertPublicKeyToData(publicKey)
    }
    
    func getClientPublicKeyX() -> Data? {
        guard let clientPublicKey = getClientPublicKeyAsData() else {
            return nil
        }
        let clientPublicKeyX = clientPublicKey.subdata(in: 0..<clientPublicKey.count/2)
        return clientPublicKeyX
    }
    
    func getClientPublicKeyY() -> Data? {
        guard let clientPublicKey = getClientPublicKeyAsData() else {
            return nil
        }
        let clientPublicKeyY = clientPublicKey.subdata(in: clientPublicKey.count/2..<clientPublicKey.count)
        return clientPublicKeyY
    }
    
    // Server Key functions
    func getServerPublicKeyAsData() -> Data? {
        guard let publicKey = serverPublicKey else {
            return nil
        }
        return convertPublicKeyToData(publicKey)
    }
    
    func getServerPublicKeyX() -> Data? {
        guard let serverPublicKey = getServerPublicKeyAsData() else {
            return nil
        }
        let serverPublicKeyX = serverPublicKey.subdata(in: 0..<serverPublicKey.count/2)
        return serverPublicKeyX
    }
    
    func getServerPublicKeyY() -> Data? {
        guard let serverPublicKey = getServerPublicKeyAsData() else {
            return nil
        }
        let serverPublicKeyY = serverPublicKey.subdata(in: serverPublicKey.count/2..<serverPublicKey.count)
        return serverPublicKeyY
    }
    
    //MARK: - ECDH and related confirmation
    public func calculateClientConfirmationCodeInLittleEndian() -> Data? {
        let message = clientRandomNumberData
        
        guard var confirmationCode = calculateKeyConfirmationCode(message: message) else {
            return nil
        }
        // security manager uses big endian. provide little endian
        confirmationCode.reverse()
        
        return confirmationCode
    }
    
    func calculateConfirmationKey() -> Data? {
        guard let clientPublicKeyX = getClientPublicKeyX(),
              let clientPublicKeyY = getClientPublicKeyY(),
              let serverPublicKeyX = getServerPublicKeyX(),
              let serverPublicKeyY = getServerPublicKeyY(),
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
    
    func calculateKeyConfirmationCode(message: Data) -> Data? {
        guard let confirmationKey = calculateConfirmationKey() else {
            return nil
        }
        
        let key = SymmetricKey(data: confirmationKey)
        let confirmationCode = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: message, using: key))
        
        return confirmationCode
    }
    
    func calculateKeyConfirmationServerLittleEndian(serverRandomNumberLittleEndian: Data) -> (calculatedConfirmationCode: Data?, validated: Bool) {
        // the security manager works in big endian
        let message = Data(serverRandomNumberLittleEndian.reversed())
        
        guard var calculatedKeyConfirmationServer = calculateKeyConfirmationCode(message: message) else {
            return (nil, false)
        }
        // security manager uses big endian. provide little endian
        calculatedKeyConfirmationServer.reverse()
        
        return (calculatedKeyConfirmationServer, calculatedKeyConfirmationServer == keyConfirmationCodeServerLittleEndian)
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
        configuration.sequenceNumber += 1
        var iv = configuration.clientIVFixedField ?? configuration.serverIVFixedField // fall back to the server fixed field when the client fixed field is not used
        iv.appendBigEndian(configuration.sequenceNumber)
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
                    // only the sequence number is transmitted
                    protectedRequest.append(configuration.sequenceNumber)
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
        do {
            let key = SymmetricKey(data: keyData)
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedContent = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: associateData)
            
            // reduce mac to length matching that in the key descriptor
            let reducedMac = Data(sealedContent.tag).subdata(in: 0..<configuration.macSize)
            return .success(EncryptedContent(ciphertext: sealedContent.ciphertext, mac: reducedMac, nonceData: nonceData))
        } catch let error {
            log.error("Error encrypting %{public}@ plaintext: %{public}@ nonce: %{public}@", String(describing: error), plaintext.hexadecimalString, nonceData.hexadecimalString)
            return .failure(.encryptionFailed)
        }
    }
    
    func decryptSecureResponse(_ secureResponse: Data) -> Result<Data, SecurityManagerError> {
        guard let keyData = keyData else {
            return .failure(.missingKey)
        }
        
        let securityConfigurationID = secureResponse[secureResponse.startIndex...].to(UInt16.self)
        guard securityConfigurationID == configuration.securityConfigurationID else {
            log.error("Unexpected security configuration ID. Expected %d, received %d", configuration.securityConfigurationID, securityConfigurationID)
            return .failure(.incorrectSecurityConfiguration)
        }
        
        var index = 2
        var nonceData = configuration.serverIVFixedField
        var mac = Data()
        var ciphertext = Data()
        
        configuration.securityControls.forEach { control in
            switch control {
            case .nonce:
                // only the sequence number is transmitted
                // BT use little endian byte order
                nonceData.append(contentsOf: secureResponse.subdata(in: index..<index+configuration.nonceSizeOctetsVariable).reversed())
                index += configuration.nonceSizeOctetsVariable
            case .mac:
                // BT use little endian byte order
                mac = Data(secureResponse.subdata(in: index..<index+configuration.macSize).reversed())
                index += configuration.macSize
            case .authenticatedEncryptedATTPacketWithAssociatedData, .authenticatedEncryptedATTPacket:
                // BT use little endian byte order
                ciphertext = Data(secureResponse.subdata(in: index..<index+(secureResponse.count - (2+configuration.macSize+configuration.nonceSizeOctetsVariable))).reversed())
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
    
    // TODO check to see if that additional library is need
    func decrypt(ciphertext: Data, associateData: Data = Data(), keyData: Data, nonceData: Data, mac: Data) -> Result<Data, SecurityManagerError> {
        do {
            // In combined mode, the authentication tag is appended to the encrypted message. This is usually what you want.
            var ciphertextAndMac = ciphertext
            ciphertextAndMac.append(mac)
            let gcm = GCM(iv: nonceData.bytes, tagLength: 8, mode: .combined)
            let aes = try CryptoSwift.AES(key: keyData.bytes, blockMode: gcm, padding: .noPadding)
            let plaintext = try Data(aes.decrypt(ciphertextAndMac.bytes))
            return .success(plaintext)
        } catch let error {
            log.error("Error decrypting %{public}@ ciphertext: %{public}@ nonce: %{public}@ mac: %{public}@", String(describing: error), ciphertext.hexadecimalString, nonceData.hexadecimalString,  mac.hexadecimalString)
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
            case clientIVFixedField
            case certificateDeviceIdentifier
            case ecdhKeyID
            case ellipticCurve
            case keyDerivationFunctionConfiguration
            case macSize
            case nonceSizeOctetsVariable
            case nonceSizeOctetsFixed
            case nonceType
            case oobRandomNumber
            case securityConfigurationID
            case securityControls
            case sequenceNumber
            case serverIVFixedField
            case version
        }
        
        var oobRandomNumber: Data = Data()
        
        var ecdhKeyID: KeyID = 1
        
        var algorithmKeyID: KeyID = 10
        
        var ellipticCurve: EllipticCurve = .p256
        
        var keyDerivationFunctionConfiguration: KeyDerivationFunctionConfiguration? = nil
        
        var securityControls: [SecurityControlType] = [.nonce, .mac, .authenticatedEncryptedATTPacketWithAssociatedData]
        
        var macSize = 8
        
        var nonceType: NonceType = .sequenceNumberEvenOdd
        
        var nonceSizeOctetsVariable = 8
        
        var serverIVFixedField: Data = Data(UInt32(0xcafeaffe))
        
        var clientIVFixedField: Data?
        
        var sequenceNumber: UInt64 = 0
        
        var certificateDeviceIdentifier: CertificateDeviceIdentifier? = nil
        
        mutating func resetSequenceNumber() {
            sequenceNumber = 0
        }
        
        var securityConfigurationID: UInt16 = 1
        
        var hasOOBRandomNumber: Bool {
            !oobRandomNumber.isEmpty
        }
        
        mutating func generateNewClientNonceFixed() -> Data {
            // the client and server fixed parts are the same size
            let size = serverIVFixedField.count
            let clientIVFixedField = Data((1...size).map { _ in UInt8.random(in: 0...UInt8.max) })
            self.clientIVFixedField = clientIVFixedField
            return clientIVFixedField
        }
        
        struct KeyDerivationFunctionConfiguration: Codable, Equatable {
            let keyDerivationFunction: KeyDerivationFunction
            var salt: Data
            var info: Data
            
            init(keyDerivationFunction: KeyDerivationFunction, salt: Data? = nil, info: Data = Data()) {
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
            self.securityControls = securityControls
            self.macSize = macSize
            self.nonceSizeOctetsVariable = nonceSizeOctetsVariable
            self.sequenceNumber = sequenceNumber
            self.securityConfigurationID = securityConfigurationID
            
            self.serverIVFixedField = rawValue[SecurityManagerConfigurationKey.serverIVFixedField.rawValue] as? Data ?? Data(UInt32(0xcafeaffe))
            self.clientIVFixedField = rawValue[SecurityManagerConfigurationKey.clientIVFixedField.rawValue] as? Data
            
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
            raw[SecurityManagerConfigurationKey.ellipticCurve.rawValue] = ellipticCurve.rawValue
            let rawSecurityControls = try! PropertyListEncoder().encode(securityControls)
            raw[SecurityManagerConfigurationKey.securityControls.rawValue] = rawSecurityControls
            raw[SecurityManagerConfigurationKey.macSize.rawValue] = macSize
            raw[SecurityManagerConfigurationKey.nonceType.rawValue] = nonceType.rawValue
            raw[SecurityManagerConfigurationKey.nonceSizeOctetsVariable.rawValue] = nonceSizeOctetsVariable
            raw[SecurityManagerConfigurationKey.serverIVFixedField.rawValue] = serverIVFixedField
            raw[SecurityManagerConfigurationKey.clientIVFixedField.rawValue] = clientIVFixedField
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
