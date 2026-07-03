//
//  LibraryQuickFilterChipsView.swift
//  Shelf Notes
//
//  Compact Smart Shelf shortcuts for tags and collections.
//

import SwiftUI

struct LibraryQuickFilterChipsView: View {
    let snapshot: LibraryView.LibraryQuickFilterSnapshot
    let onSelectTag: (String) -> Void
    let onSelectCollection: (String) -> Void

    var body: some View {
        if snapshot.isEmpty == false {
            VStack(alignment: .leading, spacing: 9) {
                Label("Schnell finden", systemImage: "magnifyingglass.circle")
                    .font(.subheadline.weight(.semibold))

                if snapshot.tagItems.isEmpty == false {
                    quickFilterRow(title: "Tags", items: snapshot.tagItems) { item in
                        onSelectTag(item.title)
                    }
                }

                if snapshot.collectionItems.isEmpty == false {
                    quickFilterRow(title: "Listen", items: snapshot.collectionItems) { item in
                        onSelectCollection(item.title)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.secondary.opacity(0.14), lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func quickFilterRow(
        title: String,
        items: [LibraryView.LibraryQuickFilterItem],
        onSelect: @escaping (LibraryView.LibraryQuickFilterItem) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            chip(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title), \(item.count) Bücher")
                        .accessibilityHint("Filtert die Bibliothek")
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func chip(_ item: LibraryView.LibraryQuickFilterItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.systemImage)
                .imageScale(.small)

            Text(item.kind == .tag ? "#\(item.title)" : item.title)
                .lineLimit(1)

            Text("\(item.count)")
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.secondary.opacity(0.16), lineWidth: 1)
        }
        .contentShape(Capsule())
    }
}
