//
//  ReadingTimelineMiniMapView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 25.01.26.
//

import SwiftUI

/// Mini-Map: thin, compact year bar that highlights the current year.
/// Tap a year to jump to it.
struct ReadingTimelineMiniMapBar: View {
    let years: [Int]
    @Binding var selectedYear: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(years, id: \.self) { y in
                        let isSelected = (selectedYear == y)

                        Button {
                            onSelect(y)
                        } label: {
                            Text(String(y))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? Color.primary : Color.secondary.opacity(0.12))
                                }
                                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                        }
                        .buttonStyle(.plain)
                        .id(y)
                        .accessibilityLabel("Jahr \(y)")
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 0)
            }
            .scrollClipDisabled()
            .contentMargins(.vertical, 0, for: .scrollContent)
            .onChange(of: selectedYear) { _, newValue in
                guard let y = newValue else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo(y, anchor: .center)
                }
            }
        }
    }
}
