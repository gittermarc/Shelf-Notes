//
//  ChallengeSettingsView.swift
//  Shelf Notes
//
//  Settings for enabled challenge cadences.
//

import SwiftUI

struct ChallengeSettingsView: View {
    @AppStorage(ChallengePreferencesStorageKey.enabledKinds) private var enabledKindsRaw: String = ChallengePreferencesStore.defaultEnabledKindsRaw
    @AppStorage(ChallengePreferencesStorageKey.preset) private var presetRaw: String = ChallengePreferencesStore.defaultPresetRaw
    @AppStorage(ChallengePreferencesStorageKey.celebrationsEnabled) private var celebrationsEnabled: Bool = ChallengePreferencesStore.defaultCelebrationsEnabled
    @AppStorage(ChallengePreferencesStorageKey.hapticsEnabled) private var hapticsEnabled: Bool = ChallengePreferencesStore.defaultHapticsEnabled

    private var preferences: ChallengePreferences {
        ChallengePreferencesStore.preferences(
            enabledKindsRaw: enabledKindsRaw,
            presetRaw: presetRaw,
            celebrationsEnabled: celebrationsEnabled,
            hapticsEnabled: hapticsEnabled
        )
    }

    private var selectedPreset: Binding<ChallengePreferencesPreset> {
        Binding(
            get: { preferences.preset },
            set: { newValue in
                applyPreset(newValue)
            }
        )
    }

    var body: some View {
        Form {
            presetSection
            cadenceSection
            celebrationSection
            statusSection
        }
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var presetSection: some View {
        Section {
            Picker("Preset", selection: selectedPreset) {
                ForEach(ChallengePreferencesPreset.allCases) { preset in
                    Label(preset.title, systemImage: preset.systemImage)
                        .tag(preset)
                }
            }
            .pickerStyle(.menu)

            Text(preferences.preset.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Preset")
        } footer: {
            Text("Presets ändern nur, welche neuen Challenge-Zeiträume künftig automatisch vorbereitet werden. Alte Challenges bleiben erhalten.")
        }
    }

    private var cadenceSection: some View {
        Section {
            ForEach(ChallengeCadence.supportedKinds) { kind in
                Toggle(isOn: enabledBinding(for: kind)) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(labelTitle(for: kind))
                            Text(labelDetail(for: kind))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: kind.badgeSystemImage)
                    }
                }
            }
        } header: {
            Text("Missionen")
        } footer: {
            Text("Deaktivierte Challenge-Arten erzeugen keine neuen Missionen. Offene Belohnungen gehen dadurch nicht verloren.")
        }
    }

    private var statusSection: some View {
        Section {
            LabeledContent("Aktiv", value: activeKindsText)
            LabeledContent("Preset", value: preferences.preset.title)
            LabeledContent("Feiern", value: celebrationsEnabled ? "Animiert" : "Ruhig")
            LabeledContent("Haptik", value: hapticsEnabled ? "An" : "Aus")
        } header: {
            Text("Aktueller Modus")
        }
    }

    private var celebrationSection: some View {
        Section {
            Toggle(isOn: $celebrationsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Belohnungen animieren")
                        Text("Trophy, Fortschrittsring und kleine Sparkles beim Einsammeln.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "sparkles")
                }
            }

            Toggle(isOn: $hapticsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptisches Feedback")
                        Text("Ein kurzer Erfolgsklopfer, wenn du eine Challenge-Belohnung sicherst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                }
            }
        } header: {
            Text("Feiern & Feedback")
        } footer: {
            Text("Wenn „Bewegung reduzieren“ in iOS aktiv ist, zeigt Shelf Notes automatisch eine ruhigere Variante der Belohnungen.")
        }
    }

    private var activeKindsText: String {
        guard !preferences.enabledKinds.isEmpty else { return "Keine" }
        return preferences.enabledKinds.map(\.displayName).joined(separator: ", ")
    }

    private func enabledBinding(for kind: ChallengeKind) -> Binding<Bool> {
        Binding(
            get: { preferences.isEnabled(kind) },
            set: { isEnabled in
                var kinds = preferences.enabledKinds
                if isEnabled {
                    kinds.append(kind)
                } else {
                    kinds.removeAll { $0 == kind }
                }
                applyEnabledKinds(kinds, preferredPreset: nil)
            }
        )
    }

    private func applyPreset(_ preset: ChallengePreferencesPreset) {
        guard let kinds = preset.configuredKinds else {
            presetRaw = ChallengePreferencesPreset.custom.rawValue
            return
        }

        applyEnabledKinds(kinds, preferredPreset: preset)
    }

    private func applyEnabledKinds(_ kinds: [ChallengeKind], preferredPreset: ChallengePreferencesPreset?) {
        let normalized = ChallengePreferences.normalizedKinds(kinds)
        let resolvedPreset = preferredPreset ?? ChallengePreferencesPreset.match(for: normalized)
        enabledKindsRaw = ChallengePreferencesStore.rawValue(for: normalized)
        presetRaw = resolvedPreset.rawValue
    }

    private func labelTitle(for kind: ChallengeKind) -> String {
        switch kind {
        case .daily:
            return "Tageschallenges"
        case .weekly:
            return "Wochenchallenges"
        case .monthly:
            return "Monatschallenges"
        case .yearly:
            return "Jahreschallenges"
        case .unknown:
            return "Unbekannt"
        }
    }

    private func labelDetail(for kind: ChallengeKind) -> String {
        switch kind {
        case .daily:
            return "Kleine Missionen für heute."
        case .weekly:
            return "Momentum über die aktuelle Woche."
        case .monthly:
            return "Ruhigere Monatsziele mit mehr Spielraum."
        case .yearly:
            return "Langfristige Quests über das Lesejahr."
        case .unknown:
            return "Wird nur defensiv für alte oder unbekannte Daten genutzt."
        }
    }
}

#Preview {
    NavigationStack {
        ChallengeSettingsView()
    }
}
