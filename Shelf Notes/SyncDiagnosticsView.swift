//
//  SyncDiagnosticsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 23.01.26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
import CloudKit
#endif

struct SyncDiagnosticsView: View {
    @ObservedObject private var sync = SyncDiagnostics.shared

    var body: some View {
        List {
            Section("Status") {
                LabeledContent {
                    Text(sync.accountStatusShort)
                        .foregroundStyle(sync.accountStatus == .available ? .primary : .secondary)
                } label: {
                    Label("iCloud", systemImage: "icloud")
                }

                if let hint = sync.accountStatusHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let checked = sync.accountStatusLastChecked {
                    LabeledContent("Zuletzt geprüft", value: checked.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                }

                LabeledContent("Netzwerk", value: sync.networkStatusShort)

                if sync.networkIsConstrained {
                    Text("Die Verbindung ist gerade eingeschränkt (Constrained). Sync kann verzögert sein.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if sync.networkIsExpensive {
                    Text("Die Verbindung ist als teuer markiert (z. B. Hotspot). Sync kann zurückhaltender sein.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let changed = sync.networkLastChanged {
                    LabeledContent("Netzwerkwechsel", value: changed.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                }

                LabeledContent("Letzter lokaler Save", value: sync.lastLocalSaveShort)

                if let src = sync.lastLocalSaveSource, !src.isEmpty {
                    Text("Quelle: " + src)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = sync.lastLocalSaveError, !err.isEmpty {
                    Text("Letzter Save-Fehler: " + err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if sync.offlineSaveCount > 0 {
                    LabeledContent("Offline-Saves", value: String(sync.offlineSaveCount))
                    if let since = sync.offlineSince {
                        Text("Änderungen wurden offline gespeichert seit " + since.formatted(date: .numeric, time: .shortened) + ". Sobald du wieder online bist, synchronisiert iCloud automatisch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Änderungen wurden offline gespeichert. Sobald du wieder online bist, synchronisiert iCloud automatisch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let userID = sync.userRecordIDShort {
                    LabeledContent("User Record", value: userID)
                        .font(.caption)
                }
            }

            Section("Aktionen") {
                Button {
                    Task { await sync.refreshAll() }
                } label: {
                    Label("Status aktualisieren", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    sync.resetOfflineCounters()
                } label: {
                    Label("Offline-Zähler zurücksetzen", systemImage: "trash")
                }

                Button {
                    copyReportToClipboard()
                } label: {
                    Label("Diagnose kopieren", systemImage: "doc.on.doc")
                }
            }

            Section {
                Text("Hinweis: SwiftData synchronisiert im Hintergrund. Diese Diagnose zeigt vor allem iCloud-Status, Netzwerk und lokale Saves, um Probleme schneller einordnen zu können.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Sync-Diagnose")
        .task {
            await sync.refreshIfStale()
        }
    }

    private func copyReportToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = sync.diagnosticsReport()
        #endif
    }
}
