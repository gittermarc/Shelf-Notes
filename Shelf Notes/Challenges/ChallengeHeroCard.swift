//
//  ChallengeHeroCard.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeHeroCard: View {
    let hero: ChallengeDashboardHero?
    let completedCount: Int
    let unclaimedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let hero {
                activeHero(hero)
            } else {
                calmHero
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Challenge Board")
                    .font(.title2.weight(.bold))

                Text("Deine kleinen Lese-Missionen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if unclaimedCount > 0 {
                    Label("\(unclaimedCount)", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }

                Label("\(completedCount)", systemImage: "trophy.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
            }
            .labelStyle(.titleAndIcon)
        }
    }

    private func activeHero(_ hero: ChallengeDashboardHero) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: 76, height: 76)

                Image(systemName: hero.systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(hero.title)
                        .font(.headline)

                    if hero.isRewardReady {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                }

                Text(hero.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressView(value: hero.progressFraction)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                HStack {
                    Text(hero.progressText)
                        .monospacedDigit()
                    Spacer()
                    Text(hero.actionText)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var calmHero: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Bereit für den nächsten Lauf")
                    .font(.headline)

                Text("Sobald aktuelle Wochen- und Monats-Challenges vorbereitet sind, siehst du hier deinen nächsten erreichbaren Sieg.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
