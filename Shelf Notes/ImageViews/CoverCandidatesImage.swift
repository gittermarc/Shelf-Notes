//
//  CoverCandidatesImage.swift
//  Shelf Notes
//

import Foundation
import SwiftUI

/// Tries the next URL if loading fails.
struct CoverCandidatesImage<Content: View, Placeholder: View>: View {
    let urlStrings: [String]
    let preferredURLString: String?
    let transaction: Transaction
    let contentMode: ContentMode
    let onResolvedURL: ((String) -> Void)?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var index: Int = 0
    @State private var resolved: Bool = false

    private var sequence: CoverCandidateSequence {
        CoverCandidateSequence(urlStrings)
    }

    private var cleaned: [String] {
        sequence.candidates
    }

    private var currentURL: URL? {
        sequence.url(at: index)
    }

    init(
        urlStrings: [String],
        preferredURLString: String? = nil,
        transaction: Transaction = Transaction(),
        contentMode: ContentMode = .fill,
        onResolvedURL: ((String) -> Void)? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlStrings = urlStrings
        self.preferredURLString = preferredURLString
        self.transaction = transaction
        self.contentMode = contentMode
        self.onResolvedURL = onResolvedURL
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let url = currentURL {
                CachedAsyncImage(
                    url: url,
                    transaction: transaction,
                    contentMode: contentMode,
                    onLoadResult: { success in
                        guard !resolved else { return }
                        if success {
                            resolved = true
                            onResolvedURL?(url.absoluteString)
                        } else {
                            advance()
                        }
                    },
                    content: content,
                    placeholder: placeholder
                )
                .id(url)
            } else {
                placeholder()
            }
        }
        .onAppear {
            index = sequence.initialIndex(preferredURLString: preferredURLString)
        }
        .onChange(of: cleaned) { _, _ in
            index = 0
            resolved = false
        }
    }

    private func advance() {
        let candidates = cleaned
        if index + 1 < candidates.count {
            withAnimation(.easeInOut(duration: 0.15)) {
                index += 1
            }
        }
    }
}
