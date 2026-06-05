//
//  AppBootstrapper.swift
//  Shelf Notes
//
//  Owns the startup phase for the SwiftData model container.
//

import Combine
import SwiftData

@MainActor
final class AppBootstrapper: ObservableObject {
    enum Phase {
        case loading
        case ready(container: ModelContainer, mode: StorageMode)
        case failed(error: Error)
    }

    @Published private(set) var phase: Phase = .loading

    init() {
        // We try CloudKit first. If it fails, we show a non-crashing error screen.
        start(mode: .cloudKit)
    }

    func retryCloudKit() {
        start(mode: .cloudKit)
    }

    func startLocalOnly() {
        start(mode: .localOnly)
    }

    func startInMemory() {
        start(mode: .inMemory)
    }

    private func start(mode: StorageMode) {
        phase = .loading

        do {
            let container = try ModelContainerFactory.makeContainer(mode: mode)
            phase = .ready(container: container, mode: mode)
        } catch {
            phase = .failed(error: error)
        }
    }
}
