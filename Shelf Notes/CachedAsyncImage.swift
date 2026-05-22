//
//  CachedAsyncImage.swift
//  Shelf Notes
//

import SwiftUI
import UIKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let transaction: Transaction
    let contentMode: ContentMode
    let onLoadResult: ((Bool) -> Void)?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil
    @State private var isLoading: Bool = false

    init(
        url: URL?,
        transaction: Transaction = Transaction(),
        contentMode: ContentMode = .fill,
        onLoadResult: ((Bool) -> Void)? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.transaction = transaction
        self.contentMode = contentMode
        self.onLoadResult = onLoadResult
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if let uiImage {
                let image = Image(uiImage: uiImage)
                content(image)
                    .aspectRatio(contentMode: contentMode)
                    .transaction { value in
                        value = transaction
                    }
            } else {
                placeholder()
            }
        }
        .onChange(of: url) { _, _ in
            uiImage = nil
            isLoading = false
        }
        .task(id: url) {
            await loadIfNeeded()
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard !isLoading else { return }
        guard uiImage == nil else { return }
        guard let url else { return }

        isLoading = true
        defer { isLoading = false }

        let image = await CoverImageLoader.loadImage(for: url)

        if Task.isCancelled { return }

        if let image {
            uiImage = image
            onLoadResult?(true)
        } else {
            onLoadResult?(false)
        }
    }
}
