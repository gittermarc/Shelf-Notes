//
//  AppContainerHostView.swift
//  Shelf Notes
//
//  Robust SwiftData container bootstrap:
//  - No fatalError on launch
//  - Clear error screen with retry
//  - Optional explicit local-only fallback without iCloud/CloudKit
//

import SwiftUI
import SwiftData

struct AppContainerHostView: View {
    @StateObject private var bootstrapper = AppBootstrapper()
    @State private var showingLocalOnlyNotice = false

    var body: some View {
        switch bootstrapper.phase {
        case .loading:
            ProgressView("Shelf Notes wird vorbereitet …")
                .padding()

        case .ready(let container, let mode):
            RootView()
                .modelContainer(container)
                .task(id: mode) {
                    if let scope = mode.collectionRepairScope {
                        await CollectionMembershipRepair.repairIfNeeded(modelContext: container.mainContext, scope: scope)
                    }

                    await ReadingAttemptRepair.repairIfNeeded(modelContext: container.mainContext)

                    // Challenges: ensure current weekly/monthly challenges exist.
                    await ChallengeRefreshCoordinator.prepareCurrentChallenges(modelContext: container.mainContext)
                }
                .overlay(alignment: .top) {
                    if mode == .localOnly {
                        LocalOnlyBanner()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .onAppear {
                    showingLocalOnlyNotice = (mode == .localOnly)
                }
                .alert("Offline-Modus", isPresented: $showingLocalOnlyNotice) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Du nutzt Shelf Notes aktuell ohne iCloud/CloudKit. Änderungen werden lokal gespeichert und nicht synchronisiert. Wichtig: Das ist ein eigener lokaler Datenstand (separat vom iCloud-Speicher).")
                }

        case .failed(let error):
            ModelContainerFailureView(
                error: error,
                retry: { bootstrapper.retryCloudKit() },
                startLocalOnly: { bootstrapper.startLocalOnly() },
                startInMemory: { bootstrapper.startInMemory() }
            )
        }
    }
}
