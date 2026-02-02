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

    // Typography / density (v1)
    static let fontDesign = "appearance_font_design_v1"
    static let textSize = "appearance_text_size_v1"
    static let density = "appearance_density_v1"

    // Accent / tint (v1)
    static let useSystemTint = "appearance_use_system_tint_v1"
    static let tintColorHex = "appearance_tint_color_hex_v1"

    // Library / list rows (v1)
    static let libraryShowCovers = "appearance_library_show_covers_v1"
    static let libraryCoverSize = "appearance_library_cover_size_v1"
    static let libraryCoverCornerRadius = "appearance_library_cover_corner_radius_v1"
    static let libraryCoverContentMode = "appearance_library_cover_content_mode_v1"
    static let libraryCoverShadowEnabled = "appearance_library_cover_shadow_enabled_v1"

    static let libraryRowShowAuthor = "appearance_library_row_show_author_v1"
    static let libraryRowShowStatus = "appearance_library_row_show_status_v1"
    static let libraryRowShowReadDate = "appearance_library_row_show_read_date_v1"
    static let libraryRowShowRating = "appearance_library_row_show_rating_v1"
    static let libraryRowShowTags = "appearance_library_row_show_tags_v1"
    static let libraryRowMaxTags = "appearance_library_row_max_tags_v1"

    // Row spacing / insets
    static let libraryRowVerticalInset = "appearance_library_row_vertical_inset_v1"
    static let libraryRowContentSpacing = "appearance_library_row_content_spacing_v1"
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

// MARK: - Library Cover Style

enum LibraryCoverSizeOption: String, CaseIterable, Identifiable {
    case small
    case standard
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Klein"
        case .standard: return "Standard"
        case .large: return "Groß"
        }
    }

    /// Target row thumbnail size (in points)
    var size: CGSize {
        switch self {
        case .small: return CGSize(width: 38, height: 56)
        case .standard: return CGSize(width: 44, height: 66)
        case .large: return CGSize(width: 52, height: 78)
        }
    }
}

enum LibraryCoverContentModeOption: String, CaseIterable, Identifiable {
    case fit
    case fill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fit: return "Einpassen"
        case .fill: return "Füllen"
        }
    }

    var contentMode: ContentMode {
        switch self {
        case .fit: return .fit
        case .fill: return .fill
        }
    }
}

// MARK: - Presets

enum AppAppearancePreset: String, CaseIterable, Identifiable {
    case classic
    case cozy
    case compact
    case midnight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .cozy: return "Cozy"
        case .compact: return "Kompakt"
        case .midnight: return "Midnight"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "System-Schrift, Standard, System-Akzent"
        case .cozy: return "Serif, größer & luftig, warmer Akzent"
        case .compact: return "Kleiner & dichter, frischer Akzent"
        case .midnight: return "Rounded, Fokus, violetter Akzent"
        }
    }

    /// Presets apply only to the P0 controls: font design, text size, density and tint.
    /// Text color stays untouched on purpose.
    var fontDesign: AppFontDesignOption {
        switch self {
        case .classic: return .system
        case .cozy: return .serif
        case .compact: return .system
        case .midnight: return .rounded
        }
    }

    var textSize: AppTextSizeOption {
        switch self {
        case .classic: return .standard
        case .cozy: return .large
        case .compact: return .small
        case .midnight: return .standard
        }
    }

    var density: AppDensityOption {
        switch self {
        case .classic: return .standard
        case .cozy: return .comfortable
        case .compact: return .compact
        case .midnight: return .standard
        }
    }

    var useSystemTint: Bool {
        switch self {
        case .classic: return true
        case .cozy, .compact, .midnight: return false
        }
    }

    var tintHex: String {
        switch self {
        case .classic: return "#007AFF" // unused when system tint
        case .cozy: return "#FF9500" // warm orange
        case .compact: return "#34C759" // green
        case .midnight: return "#AF52DE" // purple
        }
    }
}
