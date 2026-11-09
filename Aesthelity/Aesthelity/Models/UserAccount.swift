//
//  UserAccount.swift
//  Aesthelity
//
//  Represents an authenticated user account session in Aesthelity.
//

import Foundation

public struct UserAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let email: String
    public let createdAt: Date
    public let isAnonymous: Bool

    public init(
        id: String,
        email: String,
        createdAt: Date = Date(),
        isAnonymous: Bool = false
    ) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.isAnonymous = isAnonymous
    }
}
