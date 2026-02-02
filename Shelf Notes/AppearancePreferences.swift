//
//  AppearancePreferences.swift
//  Shelf Notes
//
//  Centralized appearance preference keys + option enums.
//

import SwiftUI

// MARK: - Storage Keys

enum AppearanceStorageKey {
    // Existing (v1)
    static let useSystemTextColor = "appearance_use_system_text_color_v1"
    static let textColorHex = "appearance_text_color_hex_v1"

    // New (v1)
    static let fontDesign = "appearance_font_design_v1"
    static let textSize = "appearance_text_size_v1"
    static let density = "appearance_density_v1"

    static let useSystemTint = "appearance_use_system_tint_v1"
    static let tintColorHex = "appearance_tint_color_hex_v1"
}

// MARK: - Font Design

enum AppFontDesignOption: String, CaseIterable, Identifiable {
    case system
    case serif
    case rounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .system: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }
}

// MARK: - Text Size

/// App-internal text size override.
///
/// We apply this via `dynamicTypeSize` so it scales all text styles consistently,
/// independent from the system setting.
enum AppTextSizeOption: String, CaseIterable, Identifiable {
    case small
    case standard
    case large
    case xLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Klein"
        case .standard: return "Standard"
        case .large: return "Groß"
        case .xLarge: return "Sehr groß"
        }
    }

    /// Maps to a DynamicTypeSize. `.large` is the typical baseline.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .medium
        case .standard: return .large
        case .large: return .xLarge
        case .xLarge: return .xxLarge
        }
    }
}

// MARK: - Density

enum AppDensityOption: String, CaseIterable, Identifiable {
    case compact
    case standard
    case comfortable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "Kompakt"
        case .standard: return "Standard"
        case .comfortable: return "Komfortabel"
        }
    }

    var controlSize: ControlSize {
        switch self {
        case .compact: return .small
        case .standard: return .regular
        case .comfortable: return .large
        }
    }

    var minListRowHeight: CGFloat {
        switch self {
        case .compact: return 38
        case .standard: return 44
        case .comfortable: return 52
        }
    }
}
