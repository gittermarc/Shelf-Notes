//
//  BookSearchLanguagePreference.swift
//  Shelf Notes
//
//  Stores the user's preferred default language for Google Books queries.
//  Default: .device (uses the device's preferred language if possible).
//

import Foundation

/// App-wide default language preference for Google Books search.
///
/// This is intentionally separate from the in-search filter UI:
/// - Settings define the default language for new searches.
/// - Users can still change language in the search sheet per-session.
enum BookSearchLanguagePreference: String, CaseIterable, Identifiable {
    /// Uses the device's preferred language (best effort).
    case device

    /// No language restriction.
    case any

    case de
    case en
    case fr
    case es
    case it

    static let storageKey = "book_search_language_preference_v1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .device: return "Automatisch (Gerät)"
        case .any: return "Alle Sprachen"
        case .de: return "Deutsch"
        case .en: return "Englisch"
        case .fr: return "Französisch"
        case .es: return "Spanisch"
        case .it: return "Italienisch"
        }
    }

    // MARK: - Persistence

    static func load(from defaults: UserDefaults = .standard) -> BookSearchLanguagePreference {
        if let raw = defaults.string(forKey: storageKey),
           let value = BookSearchLanguagePreference(rawValue: raw) {
            return value
        }
        return .device
    }

    static func store(_ value: BookSearchLanguagePreference, to defaults: UserDefaults = .standard) {
        defaults.set(value.rawValue, forKey: storageKey)
    }

    // MARK: - Resolution

    /// Returns the language option to preselect in the BookImport UI.
    ///
    /// If the device language isn't one of the supported UI choices, we fall back to `.any`.
    func resolvedImportLanguageOption() -> BookImportLanguageOption {
        switch self {
        case .device:
            guard let code = Self.deviceLanguageCode() else { return .any }
            return BookImportLanguageOption(rawValue: code) ?? .any
        default:
            return BookImportLanguageOption(rawValue: rawValue) ?? .any
        }
    }

    /// Returns an ISO 639-1 code for the Google Books `langRestrict` parameter, or nil for no restriction.
    ///
    /// Note: Unlike `resolvedImportLanguageOption()`, this can return device language codes
    /// even if they're not part of the UI list (e.g. "nl").
    func resolvedAPILangRestrict() -> String? {
        switch self {
        case .device:
            return Self.deviceLanguageCode()
        case .any:
            return nil
        default:
            return rawValue
        }
    }

    /// Best-effort primary language code ("de" from "de-DE").
    static func deviceLanguageCode() -> String? {
        // Preferred languages is usually the best indicator (e.g. "de-DE").
        if let preferred = Locale.preferredLanguages.first?.lowercased(),
           let primary = preferred.split(separator: "-").first,
           !primary.isEmpty {
            return String(primary)
        }

        // Fallback via Locale API.
        if #available(iOS 16.0, *) {
            if let id = Locale.current.language.languageCode?.identifier.lowercased(), !id.isEmpty {
                return id
            }
        }

        // Last resort: parse Locale identifier (e.g. "de_DE").
        let identifier = Locale.current.identifier.lowercased()
        if let primary = identifier.split(separator: "_").first, !primary.isEmpty {
            return String(primary)
        }

        return nil
    }

    static func deviceLanguageDisplayName(locale: Locale = .current) -> String {
        guard let code = deviceLanguageCode() else { return "–" }
        return locale.localizedString(forLanguageCode: code) ?? code
    }

    static func resolvedDeviceLanguageOptionTitle(locale: Locale = .current) -> String {
        let code = deviceLanguageCode() ?? "–"
        let name = deviceLanguageDisplayName(locale: locale)
        return "\(name) (\(code))"
    }
}
