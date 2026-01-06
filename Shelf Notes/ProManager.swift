//
//  ProManager.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Pro / Paywall (Einmalkauf für extra Listen)

@MainActor
final class ProManager: ObservableObject {
    /// ⚠️ TODO: Setze hier später genau die Product ID aus App Store Connect ein.
    static let productID = "001"
    static let maxFreeCollections = 5

    @Published private(set) var hasPro: Bool = false
    @Published private(set) var product: Product?
    @Published private(set) var isBusy: Bool = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await refreshEntitlements()
            await loadProductIfNeeded()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProductIfNeeded() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var entitled = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            // wenn revoked -> nicht gültig
            if transaction.revocationDate == nil {
                entitled = true
                break
            }
        }

        hasPro = entitled
    }

    func purchase() async -> Bool {
        lastError = nil
        await loadProductIfNeeded()

        guard let product else {
            lastError = "Produkt ist (noch) nicht verfügbar. Prüfe die Product ID und App Store Connect."
            return false
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return true

            case .userCancelled:
                return false

            case .pending:
                lastError = "Kauf ausstehend (z.B. Familienfreigabe/Bestätigung)."
                return false

            @unknown default:
                lastError = "Unbekanntes Kauf-Ergebnis."
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        lastError = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                // Entitlement-Status aktualisieren, dann finishen
                await refreshEntitlements()
                await transaction.finish()
            } catch {
                // ignore invalid transactions
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signed):
            return signed
        }
    }
}

