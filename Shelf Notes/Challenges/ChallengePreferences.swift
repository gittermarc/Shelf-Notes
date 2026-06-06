//
//  ChallengePreferences.swift
//  Shelf Notes
//
//  UserDefaults-backed configuration for enabled challenge cadences.
//

import Foundation

nonisolated enum ChallengePreferencesStorageKey {
    static let enabledKinds = "challenge_enabled_kinds_v1"
    static let preset = "challenge_preset_v1"
    static let celebrationsEnabled = "challenge_celebrations_enabled_v1"
    static let hapticsEnabled = "challenge_haptics_enabled_v1"
}

nonisolated enum ChallengePreferencesPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case allMissions
    case dailyWeekly
    case monthlyOnly
    case longTerm
    case custom
    case paused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allMissions:
            return "Alle Missionen"
        case .dailyWeekly:
            return "Tag & Woche"
        case .monthlyOnly:
            return "Nur Monat"
        case .longTerm:
            return "Langfristig"
        case .custom:
            return "Benutzerdefiniert"
        case .paused:
            return "Pausiert"
        }
    }

    var detail: String {
        switch self {
        case .allMissions:
            return "Tages-, Wochen-, Monats- und Jahreschallenges. Volles Programm, aber bitte mit Kaffee."
        case .dailyWeekly:
            return "Kurzfristiger Fokus für mehr Momentum im Alltag."
        case .monthlyOnly:
            return "Ruhiger Modus mit einer Monatsmission."
        case .longTerm:
            return "Monats- und Jahresquests für langfristigen Lesesog."
        case .custom:
            return "Du entscheidest einzeln, welche Challenge-Arten aktiv sind."
        case .paused:
            return "Es werden keine neuen Challenges erzeugt. Bestehende Belohnungen bleiben erhalten."
        }
    }

    var systemImage: String {
        switch self {
        case .allMissions:
            return "sparkles"
        case .dailyWeekly:
            return "bolt.fill"
        case .monthlyOnly:
            return "calendar"
        case .longTerm:
            return "mountain.2.fill"
        case .custom:
            return "slider.horizontal.3"
        case .paused:
            return "pause.circle"
        }
    }

    var configuredKinds: [ChallengeKind]? {
        switch self {
        case .allMissions:
            return ChallengeCadence.supportedKinds
        case .dailyWeekly:
            return [.daily, .weekly]
        case .monthlyOnly:
            return [.monthly]
        case .longTerm:
            return [.monthly, .yearly]
        case .custom:
            return nil
        case .paused:
            return []
        }
    }

    static func match(for kinds: [ChallengeKind]) -> ChallengePreferencesPreset {
        let normalized = ChallengePreferences.normalizedKinds(kinds)
        return allCases.first { preset in
            guard preset != .custom, let presetKinds = preset.configuredKinds else { return false }
            return ChallengePreferences.normalizedKinds(presetKinds) == normalized
        } ?? .custom
    }
}

nonisolated struct ChallengePreferences: Equatable, Sendable {
    static let defaultEnabledKinds: [ChallengeKind] = ChallengeCadence.defaultGenerationKinds
    static let defaultCelebrationsEnabled = true
    static let defaultHapticsEnabled = true
    static let defaultValue = ChallengePreferences(
        enabledKinds: defaultEnabledKinds,
        preset: .custom,
        celebrationsEnabled: defaultCelebrationsEnabled,
        hapticsEnabled: defaultHapticsEnabled
    )

    let enabledKinds: [ChallengeKind]
    let preset: ChallengePreferencesPreset
    let celebrationsEnabled: Bool
    let hapticsEnabled: Bool

    init(
        enabledKinds: [ChallengeKind],
        preset: ChallengePreferencesPreset = .custom,
        celebrationsEnabled: Bool = ChallengePreferences.defaultCelebrationsEnabled,
        hapticsEnabled: Bool = ChallengePreferences.defaultHapticsEnabled
    ) {
        self.enabledKinds = Self.normalizedKinds(enabledKinds)
        self.preset = preset
        self.celebrationsEnabled = celebrationsEnabled
        self.hapticsEnabled = hapticsEnabled
    }

    var enabledKindSet: Set<ChallengeKind> {
        Set(enabledKinds)
    }

    var storageSignature: String {
        ChallengePreferencesStore.rawValue(for: enabledKinds)
    }

    func isEnabled(_ kind: ChallengeKind) -> Bool {
        enabledKindSet.contains(kind)
    }

    static func normalizedKinds(_ kinds: [ChallengeKind]) -> [ChallengeKind] {
        let requested = Set(kinds.filter(\.isKnownCadence))
        return ChallengeCadence.supportedKinds.filter { requested.contains($0) }
    }
}

nonisolated enum ChallengePreferencesStore {
    static let defaultEnabledKindsRaw = rawValue(for: ChallengePreferences.defaultEnabledKinds)
    static let defaultPresetRaw = ChallengePreferences.defaultValue.preset.rawValue
    static let defaultCelebrationsEnabled = ChallengePreferences.defaultCelebrationsEnabled
    static let defaultHapticsEnabled = ChallengePreferences.defaultHapticsEnabled

    static func load(userDefaults: UserDefaults = .standard) -> ChallengePreferences {
        let enabledRaw = userDefaults.object(forKey: ChallengePreferencesStorageKey.enabledKinds) as? String
        let presetRaw = userDefaults.string(forKey: ChallengePreferencesStorageKey.preset)
        let celebrationsEnabled = userDefaults.object(forKey: ChallengePreferencesStorageKey.celebrationsEnabled) as? Bool
        let hapticsEnabled = userDefaults.object(forKey: ChallengePreferencesStorageKey.hapticsEnabled) as? Bool
        return preferences(
            enabledKindsRaw: enabledRaw,
            presetRaw: presetRaw,
            celebrationsEnabled: celebrationsEnabled,
            hapticsEnabled: hapticsEnabled
        )
    }

    static func save(_ preferences: ChallengePreferences, userDefaults: UserDefaults = .standard) {
        userDefaults.set(rawValue(for: preferences.enabledKinds), forKey: ChallengePreferencesStorageKey.enabledKinds)
        userDefaults.set(preferences.preset.rawValue, forKey: ChallengePreferencesStorageKey.preset)
        userDefaults.set(preferences.celebrationsEnabled, forKey: ChallengePreferencesStorageKey.celebrationsEnabled)
        userDefaults.set(preferences.hapticsEnabled, forKey: ChallengePreferencesStorageKey.hapticsEnabled)
    }

    static func saveEnabledKinds(
        _ kinds: [ChallengeKind],
        preset: ChallengePreferencesPreset? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let current = load(userDefaults: userDefaults)
        let normalized = ChallengePreferences.normalizedKinds(kinds)
        let resolvedPreset = preset ?? ChallengePreferencesPreset.match(for: normalized)
        save(
            ChallengePreferences(
                enabledKinds: normalized,
                preset: resolvedPreset,
                celebrationsEnabled: current.celebrationsEnabled,
                hapticsEnabled: current.hapticsEnabled
            ),
            userDefaults: userDefaults
        )
    }

    static func savePreset(_ preset: ChallengePreferencesPreset, userDefaults: UserDefaults = .standard) {
        let current = load(userDefaults: userDefaults)
        guard let kinds = preset.configuredKinds else {
            save(
                ChallengePreferences(
                    enabledKinds: current.enabledKinds,
                    preset: .custom,
                    celebrationsEnabled: current.celebrationsEnabled,
                    hapticsEnabled: current.hapticsEnabled
                ),
                userDefaults: userDefaults
            )
            return
        }

        save(
            ChallengePreferences(
                enabledKinds: kinds,
                preset: preset,
                celebrationsEnabled: current.celebrationsEnabled,
                hapticsEnabled: current.hapticsEnabled
            ),
            userDefaults: userDefaults
        )
    }

    static func preferences(enabledKindsRaw: String?, presetRaw: String?) -> ChallengePreferences {
        preferences(
            enabledKindsRaw: enabledKindsRaw,
            presetRaw: presetRaw,
            celebrationsEnabled: nil,
            hapticsEnabled: nil
        )
    }

    static func preferences(
        enabledKindsRaw: String?,
        presetRaw: String?,
        celebrationsEnabled: Bool?,
        hapticsEnabled: Bool?
    ) -> ChallengePreferences {
        let enabledKinds = enabledKinds(fromRaw: enabledKindsRaw)
        let storedPreset = presetRaw.flatMap { ChallengePreferencesPreset(rawValue: $0) }
        let resolvedPreset = resolvedPreset(storedPreset: storedPreset, enabledKinds: enabledKinds)
        return ChallengePreferences(
            enabledKinds: enabledKinds,
            preset: resolvedPreset,
            celebrationsEnabled: celebrationsEnabled ?? ChallengePreferences.defaultCelebrationsEnabled,
            hapticsEnabled: hapticsEnabled ?? ChallengePreferences.defaultHapticsEnabled
        )
    }

    static func enabledKinds(fromRaw raw: String?) -> [ChallengeKind] {
        guard let raw else { return ChallengePreferences.defaultEnabledKinds }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        let parsed = trimmed
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { ChallengeKind.decoded(rawValue: $0) }
            .filter(\.isKnownCadence)

        let normalized = ChallengePreferences.normalizedKinds(parsed)
        return normalized.isEmpty ? ChallengePreferences.defaultEnabledKinds : normalized
    }

    static func rawValue(for kinds: [ChallengeKind]) -> String {
        ChallengePreferences.normalizedKinds(kinds)
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private static func resolvedPreset(
        storedPreset: ChallengePreferencesPreset?,
        enabledKinds: [ChallengeKind]
    ) -> ChallengePreferencesPreset {
        if let storedPreset, let configuredKinds = storedPreset.configuredKinds {
            if ChallengePreferences.normalizedKinds(configuredKinds) == ChallengePreferences.normalizedKinds(enabledKinds) {
                return storedPreset
            }
        }

        return ChallengePreferencesPreset.match(for: enabledKinds)
    }
}
