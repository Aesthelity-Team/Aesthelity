//
//  AnalysisFinding.swift
//  Aesthelity
//
//  Created by Gaurav Pandey on 10/13/26.
//

import Foundation

public enum FindingSeverity: String, CaseIterable, Equatable {
    case normal
    case caution
    case unknown

    public var label: String {
        switch self {
        case .normal: return "Normal"
        case .caution: return "Caution"
        case .unknown: return "Unknown"
        }
    }

    public var iconName: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    /// Unknown findings come from incomplete data and must not be presented as a definitive result.
    public var isDefinitive: Bool { self != .unknown }
}

public struct AnalysisFinding: Identifiable, Equatable {
    public let id: String
    public let productName: String
    public let ingredientName: String
    public let category: String
    public let severity: FindingSeverity
    public let headline: String
    /// Plain-language explanation shown to the user.
    public let explanation: String
    /// Why the analysis generated this finding.
    public let reason: String
    public let limitation: String?

    public init(
        id: String,
        productName: String,
        ingredientName: String,
        category: String,
        severity: FindingSeverity,
        headline: String,
        explanation: String,
        reason: String,
        limitation: String? = nil
    ) {
        self.id = id
        self.productName = productName
        self.ingredientName = ingredientName
        self.category = category
        self.severity = severity
        self.headline = headline
        self.explanation = explanation
        self.reason = reason
        self.limitation = limitation
    }
}
