//
//  ReadingIntegrationsSettingsView.swift
//  Shelf Notes
//

import SwiftUI

struct ReadingIntegrationsSettingsView: View {
    private let states = ReadingIntegrationPresentationBuilder.makeAll()

    var body: some View {
        List {
            Section {
                ForEach(states) { state in
                    ReadingIntegrationSettingsRow(state: state)
                }
            } footer: {
                Text("Shelf Notes zeigt nur Fähigkeiten, die in diesem Stand wirklich umgesetzt sind. Es gibt noch keine Kontosynchronisierung und keine Share Extension.")
            }
        }
        .navigationTitle("Lesequellen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReadingIntegrationSettingsRow: View {
    let state: ReadingIntegrationPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(state.title)
                            .font(.subheadline.weight(.semibold))

                        Text(state.availabilityTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }

                    Text(state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 5) {
                LabeledContent("Verfügbarkeit", value: state.availabilityDetail)
                LabeledContent("Fortschritt", value: state.progressModeTitle)
                Text(state.progressModeDetail)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            if state.capabilityTitles.isEmpty {
                Text("Aktuell keine automatischen Fähigkeiten aktiviert")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ReadingIntegrationCapabilityChips(titles: state.capabilityTitles)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ReadingIntegrationCapabilityChips: View {
    let titles: [String]

    var body: some View {
        FlowLayout(spacing: 6, rowSpacing: 6) {
            ForEach(titles, id: \.self) { title in
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [LayoutItem] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }

            items.append(LayoutItem(index: index, origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return LayoutResult(size: CGSize(width: maxWidth, height: y + rowHeight), items: items)
    }

    private struct LayoutItem {
        let index: Int
        let origin: CGPoint
        let size: CGSize
    }

    private struct LayoutResult {
        let size: CGSize
        let items: [LayoutItem]
    }
}

#Preview {
    NavigationStack {
        ReadingIntegrationsSettingsView()
    }
}