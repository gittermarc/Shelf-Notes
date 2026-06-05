//
//  ModelContainerFailureView.swift
//  Shelf Notes
//
//  Recovery UI for SwiftData/CloudKit startup failures.
//

import SwiftUI

struct ModelContainerFailureView: View {
    let error: Error
    let retry: () -> Void
    let startLocalOnly: () -> Void
    let startInMemory: () -> Void

    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.system(size: 34, weight: .semibold))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Datenbank konnte nicht gestartet werden")
                                .font(.title2.weight(.semibold))
                            Text("Shelf Notes konnte den SwiftData-Speicher nicht initialisieren. Häufige Ursachen sind iCloud/CloudKit-Setup, Signierung/Entitlements oder ein temporäres iCloud-Problem.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Was du jetzt tun kannst")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Prüfe, ob du in iCloud eingeloggt bist", systemImage: "person.crop.circle")
                            Label("Aktiviere iCloud Drive", systemImage: "icloud")
                            Label("Stelle sicher, dass die App Zugriff auf iCloud hat", systemImage: "checkmark.shield")
                            Label("Wenn du gerade offline bist: kurz warten und erneut versuchen", systemImage: "wifi.slash")
                        }
                        .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        Button(action: retry) {
                            Label("Erneut versuchen", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: startLocalOnly) {
                            Label("Ohne iCloud starten (lokal)", systemImage: "internaldrive")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: startInMemory) {
                            Label("Nur temporär starten (In‑Memory)", systemImage: "bolt")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    DisclosureGroup("Technische Details", isExpanded: $showDetails) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(describing: error))
                                .font(.footnote)
                                .textSelection(.enabled)

                            #if DEBUG
                            Text("Hinweis: Im Release solltest du hier keine sensiblen Details anzeigen. Für Debug/Support ist das aber Gold wert.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            #endif
                        }
                        .padding(.top, 6)
                    }
                    .padding(.top, 6)
                }
                .padding()
            }
            .navigationTitle("Startproblem")
        }
    }
}
