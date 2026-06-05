import SwiftUI

struct CollectionsSmartActionsSection: View {
    let actions: [CollectionsSmartAction]
    let collectionForID: (UUID) -> BookCollection?

    var body: some View {
        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gut zu wissen")
                            .font(.headline)

                        Text("Kleine Hinweise, damit deine Listen nicht nur hübsch aussehen, sondern dir Arbeit abnehmen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(actions) { action in
                        CollectionsSmartActionCard(
                            action: action,
                            destinationCollection: destinationCollection(for: action)
                        )
                    }
                }
            }
        }
    }

    private func destinationCollection(for action: CollectionsSmartAction) -> BookCollection? {
        guard let collectionID = action.collectionID else { return nil }
        return collectionForID(collectionID)
    }
}

private struct CollectionsSmartActionCard: View {
    let action: CollectionsSmartAction
    let destinationCollection: BookCollection?

    var body: some View {
        if let destinationCollection {
            NavigationLink {
                CollectionDetailView(collection: destinationCollection)
            } label: {
                cardContent(showChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            cardContent(showChevron: false)
        }
    }

    private func cardContent(showChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: action.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(action.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(action.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if let ctaTitle = action.ctaTitle {
                    Label(ctaTitle, systemImage: "arrow.right.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 1)
        )
    }
}
