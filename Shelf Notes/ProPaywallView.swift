//
//  ProPaywallView.swift
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

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pro: ProManager

    var onPurchased: (() -> Void)? = nil

    @State private var localError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 38))
                        .padding(.top, 6)

                    Text("Mehr Listen freischalten")
                        .font(.title2)
                        .bold()

                    Text("Kostenlos: bis zu \(ProManager.maxFreeCollections) Listen.\nMit Einmalkauf: unbegrenzt.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow("Unbegrenzte Collections/Listen")
                    featureRow("Ideal für Reihen, Themen, Challenges")
                    featureRow("Kauf gilt auf iPhone & iPad (Apple-ID)")
                }
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        Task {
                            localError = nil
                            let ok = await pro.purchase()
                            if ok {
                                dismiss()
                                onPurchased?()
                            } else if let err = pro.lastError, !err.isEmpty {
                                localError = err
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if pro.isBusy {
                                ProgressView()
                            } else {
                                Text(buyButtonTitle)
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pro.isBusy || pro.hasPro)

                    Button {
                        Task { await pro.restore() }
                    } label: {
                        Text("Käufe wiederherstellen")
                    }
                    .disabled(pro.isBusy)

                    if pro.hasPro {
                        Text("Pro ist bereits aktiv ✅")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let localError, !localError.isEmpty {
                        Text(localError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
            }
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task {
                await pro.refreshEntitlements()
                await pro.loadProductIfNeeded()
            }
        }
    }

    private var buyButtonTitle: String {
        if pro.hasPro { return "Bereits freigeschaltet" }
        if let product = pro.product {
            return "Einmalkauf \(product.displayPrice)"
        }
        return "Einmalkauf"
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
            Text(text)
            Spacer()
        }
        .font(.subheadline)
    }
}
