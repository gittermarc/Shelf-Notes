//
//  ShareExtensionItemReader.swift
//  ShelfNotesShareExtension
//

import Foundation
import UniformTypeIdentifiers

struct ShareExtensionReadResult: Equatable {
    var title: String?
    var text: String?
    var url: URL?
}

enum ShareExtensionItemReader {
    static func read(extensionItems: [NSExtensionItem]) async -> ShareExtensionReadResult {
        let title = extensionItems
            .compactMap { item in
                item.attributedTitle?.string ?? item.attributedContentText?.string
            }
            .first

        var texts: [String] = []
        var firstURL: URL?

        for item in extensionItems {
            let providers = item.attachments ?? []
            for provider in providers {
                if firstURL == nil,
                   provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = await loadURL(from: provider) {
                    firstURL = url
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = await loadText(from: provider) {
                    texts.append(text)
                }
            }
        }

        return ShareExtensionReadResult(
            title: title,
            text: texts.joined(separator: "\n"),
            url: firstURL
        )
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                    return
                }

                if let data = item as? Data,
                   let value = String(data: data, encoding: .utf8),
                   let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    continuation.resume(returning: url)
                    return
                }

                if let value = item as? String,
                   let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    continuation.resume(returning: url)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                    return
                }

                if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }
}
