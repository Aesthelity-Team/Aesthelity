//
//  CatalogProductIdentity.swift
//  Aesthelity
//
//  Deterministic product UUIDs derived from DemoCatalog string IDs so routine
//  steps survive app relaunch and resolve to the same catalog product.
//

import CryptoKit
import Foundation

public enum CatalogProductIdentity {
    /// Stable namespace for name-based (v5-style) catalog UUIDs.
    private static let namespaceUUID = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!

    /// Returns a UUID that is stable for a given catalog product id across launches.
    public static func uuid(forCatalogId catalogId: String) -> UUID {
        var namespaceBytes = withUnsafeBytes(of: namespaceUUID.uuid) { Array($0) }
        var payload = Data(namespaceBytes)
        payload.append(Data(catalogId.utf8))

        let digest = SHA256.hash(data: payload)
        var bytes = Array(digest.prefix(16))
        // RFC 4122 version 5 + variant 10
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
