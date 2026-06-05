//
//  ChallengeHistorySection.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeHistorySection: View {
    let items: [ChallengeDashboardItem]
    var onClaim: ((ChallengeDashboardItem) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Letzte Läufe")
                        .font(.headline)
                    Text("Was zuletzt passiert ist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    historyRow(item)
                }
            }
        }
    }

    private func historyRow(_ item: ChallengeDashboardItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.metric.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isCompleted ? Color.accentColor : Color.secondary)
                .frame(width: 34, height: 34)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text("\(item.kind.displayName) • \(item.periodLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                if item.isRewardReady, let onClaim {
                    Button {
                        onClaim(item)
                    } label: {
                        Label("Abholen", systemImage: "sparkles")
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                } else {
                    Label(item.statusText, systemImage: item.statusSystemImage)
                        .font(.caption.weight(.semibold))
                        .labelStyle(.iconOnly)
                        .foregroundStyle(item.isCompleted ? Color.accentColor : Color.secondary)
                        .accessibilityLabel(item.statusText)
                }

                Text(item.progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}
