//
//  BarcodeScannerSheet.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 20.12.25.
//

import SwiftUI
import Vision

#if canImport(VisionKit)
import VisionKit
#endif

/// Ein simples Sheet, das ISBN-Barcodes scannt und den Roh-String zurückgibt.
/// Nutzt VisionKit DataScanner (iOS 16+). Auf dem Simulator funktioniert das i.d.R. nicht – auf einem echten iPhone testen.
struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onFound: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 16.0, *), canUseDataScanner {
                    DataScannerRepresentable { rawValue in
                        // 1) Normalisieren (digits only, am liebsten 13-stellig)
                        if let isbn = normalizeToLikelyISBN(rawValue) {
                            onFound(isbn)
                            dismiss()
                        }
                    }
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        instructionOverlay
                            .padding(.top, 12)
                    }
                } else {
                    ContentUnavailableView(
                        "Scanner nicht verfügbar",
                        systemImage: "barcode.viewfinder",
                        description: Text("Dieses Gerät/Simulator unterstützt den Kamera-Barcode-Scanner nicht. Bitte auf einem iPhone testen oder später auf AVFoundation-Fallback wechseln.")
                    )
                    .padding()
                }
            }
            .navigationTitle("ISBN scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private var instructionOverlay: some View {
        Text("Halte den Barcode (ISBN) ins Bild.\nSobald er erkannt wurde, springt die Suche auf.")
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
    }

    private var canUseDataScanner: Bool {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        }
        #endif
        return false
    }

    private func normalizeToLikelyISBN(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        // Perfekt: genau 13 oder 10
        if digits.count == 13 || digits.count == 10 { return digits }

        // Häufige Fälle: DataScanner liefert mehr Kontext – wir versuchen 978/979-Block zu finden
        if digits.count > 13 {
            if let isbn = findEAN13(in: digits, prefix: "978") { return isbn }
            if let isbn = findEAN13(in: digits, prefix: "979") { return isbn }
            return String(digits.prefix(13))
        }

        // Zu kurz: eher kein brauchbarer ISBN-Scan
        return nil
    }

    private func findEAN13(in digits: String, prefix: String) -> String? {
        guard digits.count >= 13 else { return nil }
        var start = digits.startIndex
        while start < digits.endIndex {
            let remaining = digits.distance(from: start, to: digits.endIndex)
            guard remaining >= 13 else { break }
            let end = digits.index(start, offsetBy: 13)
            let candidate = String(digits[start..<end])
            if candidate.hasPrefix(prefix) { return candidate }
            start = digits.index(after: start)
        }
        return nil
    }
}

#if canImport(VisionKit)
@available(iOS 16.0, *)
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // Bücher sind meist EAN-13. Wir nehmen EAN-13 plus optional EAN-8 / Code128, falls du mal “komische” Barcodes triffst.
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .code128])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // DataScanner muss aktiv gestartet werden – sonst siehst du nur Kamera-Preview ohne Erkennung.
        guard !uiViewController.isScanning else { return }

        DispatchQueue.main.async {
            do {
                try uiViewController.startScanning()
            } catch {
                print("❌ DataScanner startScanning() failed:", error)
            }
        }
    }


    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onFound: (String) -> Void
        private var didFire = false

        init(onFound: @escaping (String) -> Void) {
            self.onFound = onFound
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(item, dataScanner: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Sobald was auftaucht: nimm das erste Barcode-Item.
            guard let first = addedItems.first else { return }
            handle(first, dataScanner: dataScanner)
        }

        private func handle(_ item: RecognizedItem, dataScanner: DataScannerViewController) {
            guard !didFire else { return }

            if case .barcode(let barcode) = item,
               let payload = barcode.payloadStringValue,
               !payload.isEmpty {
                didFire = true
                dataScanner.stopScanning()
                onFound(payload)
            }
        }
    }
}
#endif
