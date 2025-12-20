//
//  CachedAsyncImage.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 20.12.25.
//

import SwiftUI
import UIKit

// MARK: - Memory cache

final class ImageMemoryCache {
    static let shared = ImageMemoryCache()

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

// MARK: - CachedAsyncImage

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
                    .transaction { t in
                        // Some SwiftUI versions only provide the closure-based modifier.
                        t = transaction
                    }
            } else {
                placeholder()
            }
        }
        .onChange(of: url) { _, _ in
            // When url changes on the same view instance, reset state so it can load again.
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
        guard let url else { return }

        // Memory cache
        if let cached = ImageMemoryCache.shared.image(for: url) {
            uiImage = cached
            onLoadResult?(true)
            return
        }

        isLoading = true
        defer { isLoading = false }

        // URLCache
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                onLoadResult?(false)
                return
            }

            guard let img = UIImage(data: data) else {
                onLoadResult?(false)
                return
            }

            ImageMemoryCache.shared.setImage(img, for: url)
            uiImage = img
            onLoadResult?(true)
        } catch {
            onLoadResult?(false)
        }
    }
}

// MARK: - CoverCandidatesImage (tries the next URL if loading fails)

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

    private var cleaned: [String] {
        var out: [String] = []
        for s in urlStrings {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }
        return out
    }

    private var currentURL: URL? {
        let arr = cleaned
        guard index >= 0, index < arr.count else { return nil }
        return URL(string: arr[index])
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

        // We can't set @State directly here, but we can compute an initial index via a helper:
        // the actual initialization happens in .onAppear below.
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
                .id(url) // force a fresh instance when switching candidates
            } else {
                placeholder()
            }
        }
        .onAppear {
            // pick the preferred URL if it's in the list, otherwise start at 0
            let arr = cleaned
            if let preferredURLString {
                let pref = preferredURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                if let i = arr.firstIndex(where: { $0.caseInsensitiveCompare(pref) == .orderedSame }) {
                    index = i
                }
            }
        }
        .onChange(of: cleaned) { _, _ in
            // if candidate list changes, restart
            index = 0
            resolved = false
        }
    }

    private func advance() {
        let arr = cleaned
        if index + 1 < arr.count {
            withAnimation(.easeInOut(duration: 0.15)) {
                index += 1
            }
        }
    }
}
