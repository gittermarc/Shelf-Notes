import SwiftUI

struct SmartTagSuggestionButton: View {
    let item: TagSuggestionDisplayItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.tag)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(item.reasonLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.detail.isEmpty, item.detail != item.reasonLabel {
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.secondary.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Tag-Vorschlag \(item.tag)"))
        .accessibilityHint(Text("Tippen zum Hinzufügen"))
    }
}

struct TagSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
