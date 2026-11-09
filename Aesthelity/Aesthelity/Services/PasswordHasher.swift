//
//  PasswordHasher.swift
//  Aesthelity
//
//  Cryptographic password hashing and verification utility.
//

import CryptoKit
import Foundation
import Security

/// Cryptographic helper for generating salts, hashing passwords, and verifying password hashes.
public enum PasswordHasher: Sendable {
    /// Generates a cryptographically secure random salt of the specified byte count.
    public static func generateSalt(byteCount: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes).base64EncodedString()
    }

    /// Computes a secure SHA-256 hash using the salt and raw password.
    public static func hash(password: String, salt: String) -> String {
        let payload = "\(salt):\(password)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Constant-time verification of a raw password against an expected hash and salt.
    public static func verify(password: String, hash expectedHash: String, salt: String) -> Bool {
        let computed = hash(password: password, salt: salt)
        let computedBytes = Array(computed.utf8)
        let expectedBytes = Array(expectedHash.utf8)
        guard computedBytes.count == expectedBytes.count else { return false }
        var accumulator: UInt8 = 0
        for (a, b) in zip(computedBytes, expectedBytes) {
            accumulator |= a ^ b
        }
        return accumulator == 0
    }
}
