//
//  KeychainManager.swift
//  Aesthelity
//
//  Secure credential and session token storage using Apple Keychain Services.
//

import Foundation
import Security

public enum KeychainError: LocalizedError, Equatable {
    case duplicateItem
    case itemNotFound
    case unhandledError(status: OSStatus)
    case dataConversionFailed
    
    public var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "An identical item already exists in the secure storage."
        case .itemNotFound:
            return "The requested item was not found in secure storage."
        case .unhandledError(let status):
            return "Secure storage operation failed with status code \(status)."
        case .dataConversionFailed:
            return "Failed to convert the data for secure storage."
        }
    }
}

public protocol KeychainManagerProtocol: Sendable {
    func save(data: Data, forKey key: String) throws
    func save(string: String, forKey key: String) throws
    func readData(forKey key: String) throws -> Data?
    func readString(forKey key: String) throws -> String?
    func delete(forKey key: String) throws
    func clearAll() throws
    
    func saveSecurePassword(_ secret: String, forAccount account: String) throws
    func readSecurePassword(forAccount account: String) throws -> String?
    func deleteSecurePassword(forAccount account: String) throws
}

extension KeychainManagerProtocol {
    public func saveSecurePassword(_ secret: String, forAccount account: String) throws {
        guard !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthError.missingFields
        }
        try save(string: secret, forKey: "auth_credential_\(account.lowercased())")
    }
    
    public func readSecurePassword(forAccount account: String) throws -> String? {
        try readString(forKey: "auth_credential_\(account.lowercased())")
    }
    
    public func deleteSecurePassword(forAccount account: String) throws {
        try delete(forKey: "auth_credential_\(account.lowercased())")
    }
}

public final class KeychainManager: KeychainManagerProtocol, @unchecked Sendable {
    public static let shared = KeychainManager()
    
    public let service: String
    public let accessGroup: String?

    public init(service: String = "com.Aesthelity.Aesthelity.auth", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    public func save(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
        case errSecItemNotFound:
            var newItem: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            if let accessGroup = accessGroup {
                newItem[kSecAttrAccessGroup as String] = accessGroup
            }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func save(string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        try save(data: data, forKey: key)
    }
    
    public func readData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func readString(forKey key: String) throws -> String? {
        guard let data = try readData(forKey: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }
    
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}
