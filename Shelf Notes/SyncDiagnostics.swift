//
//  SyncDiagnostics.swift
//  Shelf Notes
//
//  Minimal sync diagnostics for SwiftData + iCloud (CloudKit).
//  SwiftData does not expose detailed CloudKit progress, so we surface the
//  most useful signals for debugging in the app UI.
//

import Foundation
import CloudKit
import Network
import Combine
import UIKit

@MainActor
final class SyncDiagnostics: ObservableObject {
    static let shared = SyncDiagnostics()

    // MARK: Persisted keys
    private enum Keys {
        static let lastLocalSave = "syncdiag_last_local_save_v1"
        static let lastLocalSaveSource = "syncdiag_last_local_save_source_v1"
        static let lastLocalSaveError = "syncdiag_last_local_save_error_v1"
        static let offlineSaveCount = "syncdiag_offline_save_count_v1"
        static let offlineSince = "syncdiag_offline_since_v1"
        static let accountStatus = "syncdiag_account_status_v1"
        static let accountStatusChecked = "syncdiag_account_status_checked_v1"
        static let userRecordShort = "syncdiag_user_record_short_v1"
        static let userRecordChecked = "syncdiag_user_record_checked_v1"
        static let networkLastChanged = "syncdiag_network_last_changed_v1"
    }

    private let defaults = UserDefaults.standard
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "de.marcfechner.shelfnotes.syncdiag.nwpath")

    // MARK: Published state
    @Published private(set) var accountStatus: CKAccountStatus? = nil
    @Published private(set) var accountStatusLastChecked: Date? = nil
    @Published private(set) var userRecordIDShort: String? = nil
    @Published private(set) var userRecordIDLastChecked: Date? = nil

    @Published private(set) var networkStatus: NWPath.Status = .requiresConnection
    @Published private(set) var networkIsExpensive: Bool = false
    @Published private(set) var networkIsConstrained: Bool = false
    @Published private(set) var networkLastChanged: Date? = nil

    @Published private(set) var lastLocalSave: Date? = nil
    @Published private(set) var lastLocalSaveSource: String? = nil
    @Published private(set) var lastLocalSaveError: String? = nil

    @Published private(set) var offlineSaveCount: Int = 0
    @Published private(set) var offlineSince: Date? = nil

    private init() {
        loadPersisted()
        startNetworkMonitor()

        // Best-effort initial refresh.
        Task {
            await refreshIfStale()
        }
    }

    // MARK: Public

    var isOnline: Bool {
        networkStatus == .satisfied
    }

    func refreshIfStale() async {
        // Avoid spamming CloudKit APIs; refresh if older than 10 minutes.
        let maxAge: TimeInterval = 10 * 60
        let now = Date()

        if accountStatusLastChecked == nil || now.timeIntervalSince(accountStatusLastChecked ?? .distantPast) > maxAge {
            await refreshAccountStatus(force: true)
        }

        if userRecordIDLastChecked == nil || now.timeIntervalSince(userRecordIDLastChecked ?? .distantPast) > maxAge {
            await refreshUserRecordID(force: true)
        }
    }

    func refreshAll() async {
        await refreshAccountStatus(force: true)
        await refreshUserRecordID(force: true)
    }

    func recordLocalSave(success: Bool, error: Error? = nil, source: String? = nil) {
        let now = Date()
        lastLocalSave = now
        lastLocalSaveSource = source
        defaults.set(now, forKey: Keys.lastLocalSave)
        defaults.set(source, forKey: Keys.lastLocalSaveSource)

        if success {
            lastLocalSaveError = nil
            defaults.removeObject(forKey: Keys.lastLocalSaveError)
        } else if let error {
            lastLocalSaveError = error.localizedDescription
            defaults.set(error.localizedDescription, forKey: Keys.lastLocalSaveError)
        }

        // If the device is offline when saving, keep a small counter.
        if !isOnline {
            offlineSaveCount += 1
            defaults.set(offlineSaveCount, forKey: Keys.offlineSaveCount)
            if offlineSince == nil {
                offlineSince = now
                defaults.set(now, forKey: Keys.offlineSince)
            }
        }
    }

    func resetOfflineCounters() {
        offlineSaveCount = 0
        offlineSince = nil
        defaults.set(0, forKey: Keys.offlineSaveCount)
        defaults.removeObject(forKey: Keys.offlineSince)
    }

    func resetAll() {
        lastLocalSave = nil
        lastLocalSaveSource = nil
        lastLocalSaveError = nil
        offlineSaveCount = 0
        offlineSince = nil
        accountStatus = nil
        accountStatusLastChecked = nil
        userRecordIDShort = nil
        userRecordIDLastChecked = nil
        networkLastChanged = nil

        defaults.removeObject(forKey: Keys.lastLocalSave)
        defaults.removeObject(forKey: Keys.lastLocalSaveSource)
        defaults.removeObject(forKey: Keys.lastLocalSaveError)
        defaults.set(0, forKey: Keys.offlineSaveCount)
        defaults.removeObject(forKey: Keys.offlineSince)
        defaults.removeObject(forKey: Keys.accountStatus)
        defaults.removeObject(forKey: Keys.accountStatusChecked)
        defaults.removeObject(forKey: Keys.userRecordShort)
        defaults.removeObject(forKey: Keys.userRecordChecked)
        defaults.removeObject(forKey: Keys.networkLastChanged)
    }

    func diagnosticsReport() -> String {
        var lines: [String] = []

        let bundleID = Bundle.main.bundleIdentifier ?? "(unknown)"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "(unknown)"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "(unknown)"
        lines.append("App: " + bundleID)
        lines.append("Version: " + version + " (" + build + ")")

        #if canImport(UIKit)
        lines.append("Device: " + UIDevice.current.model)
        lines.append("System: " + UIDevice.current.systemName + " " + UIDevice.current.systemVersion)
        #endif

        lines.append("Online: " + (isOnline ? "yes" : "no"))
        lines.append("Network: " + networkStatusShort)
        if networkIsConstrained { lines.append("Network constrained: yes") }
        if networkIsExpensive { lines.append("Network expensive: yes") }
        if let d = networkLastChanged { lines.append("Network changed: " + d.formatted(date: .numeric, time: .shortened)) }

        lines.append("iCloud: " + accountStatusShort)
        if let d = accountStatusLastChecked { lines.append("iCloud checked: " + d.formatted(date: .numeric, time: .shortened)) }
        if let id = userRecordIDShort { lines.append("User record: " + id) }
        if let d = userRecordIDLastChecked { lines.append("User record checked: " + d.formatted(date: .numeric, time: .shortened)) }

        if let d = lastLocalSave { lines.append("Last local save: " + d.formatted(date: .numeric, time: .shortened)) }
        if let src = lastLocalSaveSource { lines.append("Last save source: " + src) }
        if let err = lastLocalSaveError { lines.append("Last save error: " + err) }

        lines.append("Offline saves: " + String(offlineSaveCount))
        if let d = offlineSince { lines.append("Offline since: " + d.formatted(date: .numeric, time: .shortened)) }

        return lines.joined(separator: "\n")
    }

    // MARK: Presentation helpers

    var accountStatusShort: String {
        guard let status = accountStatus else { return "…" }
        switch status {
        case .available: return "angemeldet"
        case .noAccount: return "nicht angemeldet"
        case .restricted: return "eingeschränkt"
        case .couldNotDetermine: return "unklar"
        case .temporarilyUnavailable: return "vorübergehend nicht verfügbar"
        @unknown default: return "unbekannt"
        }
    }

    var accountStatusHint: String? {
        guard let status = accountStatus else { return nil }
        switch status {
        case .available:
            return "iCloud ist verfügbar. SwiftData synchronisiert im Hintergrund."
        case .noAccount:
            return "Du bist nicht in iCloud eingeloggt. Sync funktioniert dann nicht."
        case .restricted:
            return "iCloud ist eingeschränkt (z. B. Screen Time / Firmenprofil)."
        case .couldNotDetermine:
            return "Der iCloud-Status konnte nicht bestimmt werden. Versuche es später erneut."
        case .temporarilyUnavailable:
            return "iCloud ist gerade vorübergehend nicht verfügbar."
        @unknown default:
            return nil
        }
    }

    var networkStatusShort: String {
        switch networkStatus {
        case .satisfied: return "online"
        case .unsatisfied: return "offline"
        case .requiresConnection: return "Verbindung nötig"
        @unknown default: return "unbekannt"
        }
    }

    var lastLocalSaveShort: String {
        guard let d = lastLocalSave else { return "—" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: Internal

    private func loadPersisted() {
        lastLocalSave = defaults.object(forKey: Keys.lastLocalSave) as? Date
        lastLocalSaveSource = defaults.string(forKey: Keys.lastLocalSaveSource)
        lastLocalSaveError = defaults.string(forKey: Keys.lastLocalSaveError)
        offlineSaveCount = defaults.integer(forKey: Keys.offlineSaveCount)
        offlineSince = defaults.object(forKey: Keys.offlineSince) as? Date

        if let raw = defaults.object(forKey: Keys.accountStatus) as? Int {
            accountStatus = CKAccountStatus(rawValue: raw)
        }
        accountStatusLastChecked = defaults.object(forKey: Keys.accountStatusChecked) as? Date
        userRecordIDShort = defaults.string(forKey: Keys.userRecordShort)
        userRecordIDLastChecked = defaults.object(forKey: Keys.userRecordChecked) as? Date
        networkLastChanged = defaults.object(forKey: Keys.networkLastChanged) as? Date
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                self.networkStatus = path.status
                self.networkIsExpensive = path.isExpensive
                self.networkIsConstrained = path.isConstrained
                let now = Date()
                self.networkLastChanged = now
                self.defaults.set(now, forKey: Keys.networkLastChanged)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func refreshAccountStatus(force: Bool) async {
        let now = Date()
        accountStatusLastChecked = now
        defaults.set(now, forKey: Keys.accountStatusChecked)

        do {
            let status = try await fetchAccountStatus()
            accountStatus = status
            defaults.set(status.rawValue, forKey: Keys.accountStatus)
        } catch {
            // Keep previous value; the UI will show the cached one.
        }
    }

    private func refreshUserRecordID(force: Bool) async {
        let now = Date()
        userRecordIDLastChecked = now
        defaults.set(now, forKey: Keys.userRecordChecked)

        do {
            let recordID = try await fetchUserRecordID()
            let name = recordID.recordName
            // Do not expose the full identifier in UI; show a short suffix.
            let short = name.count <= 10 ? name : String(name.suffix(10))
            userRecordIDShort = short
            defaults.set(short, forKey: Keys.userRecordShort)
        } catch {
            // Keep previous value.
        }
    }

    private func fetchAccountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func fetchUserRecordID() async throws -> CKRecord.ID {
        try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().fetchUserRecordID { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let recordID {
                    continuation.resume(returning: recordID)
                } else {
                    continuation.resume(throwing: NSError(domain: "SyncDiagnostics", code: 1))
                }
            }
        }
    }
}
