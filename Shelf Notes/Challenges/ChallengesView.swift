//
//  ChallengesView.swift
//  Shelf Notes
//
//  Simple motivation layer: weekly + monthly challenges.
//

import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)])
    private var allChallenges: [ChallengeRecord]

    @State private var progressByID: [UUID: ChallengeEngine.ChallengeProgress] = [:]
    @State private var didInitialRefresh = false

    var body: some View {
        List {
            if !activeChallenges.isEmpty {
                Section("Aktiv") {
                    ForEach(activeChallenges) { ch in
                        ChallengeCard(challenge: ch, progress: progressByID[ch.id], onRefresh: refresh)
                    }
                }
            }

            let past = pastChallenges
            if !past.isEmpty {
                Section("Vergangenheit") {
                    ForEach(past) { ch in
                        ChallengeCompactRow(challenge: ch, progress: progressByID[ch.id])
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wie das funktioniert")
                        .font(.headline)

                    Text("Challenges werden pro Woche/Monat automatisch erzeugt. Die Ziele passen sich grob an dein Verhalten an (letzte Wochen/Monate). Fortschritt wird aus deinen Sessions und (bei Buch-Challenges) aus 'Gelesen + readTo' berechnet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !didInitialRefresh {
                didInitialRefresh = true
                ChallengeEngine.ensureCurrentChallenges(modelContext: modelContext)
                refresh()
            }
        }
        .refreshable {
            refresh()
        }
    }

    private var activeChallenges: [ChallengeRecord] {
        allChallenges
            .filter { $0.isActive }
            .sorted { $0.kindRawValue < $1.kindRawValue }
    }

    private var pastChallenges: [ChallengeRecord] {
        // Show last ~12 entries; active ones are already shown above.
        let now = Date()
        return allChallenges
            .filter { $0.periodEnd <= now }
            .prefix(12)
            .map { $0 }
    }

    @MainActor
    private func refresh() {
        ChallengeEngine.ensureCurrentChallenges(modelContext: modelContext)
        ChallengeEngine.refreshCompletionForActiveChallenges(modelContext: modelContext)

        // Compute progress for visible entries (active + recent past)
        var newMap: [UUID: ChallengeEngine.ChallengeProgress] = progressByID

        let interesting = activeChallenges + pastChallenges
        for ch in interesting {
            newMap[ch.id] = ChallengeEngine.computeProgress(for: ch, modelContext: modelContext)
        }

        progressByID = newMap
    }
}

// MARK: - UI pieces

private struct ChallengeCard: View {
    @Environment(\.modelContext) private var modelContext

    let challenge: ChallengeRecord
    let progress: ChallengeEngine.ChallengeProgress?
    let onRefresh: () -> Void

    @State private var showClaimToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: challenge.metric.systemImage)
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.headline)

                    Text("\(challenge.kind.displayName) • \(challenge.periodLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if challenge.isCompleted {
                    Label("Erledigt", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }

            Text(challenge.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider().opacity(0.6)

            let p = progress ?? ChallengeEngine.computeProgress(for: challenge, modelContext: modelContext)

            ProgressView(value: p.fraction(target: challenge.targetValue))
                .progressViewStyle(.linear)

            HStack {
                Text(p.valueText(target: challenge.targetValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                if let remaining = p.remainingText(target: challenge.targetValue) {
                    Text(remaining)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Ziel erreicht")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let hint = suggestionText(progress: p) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if challenge.isCompleted && !challenge.isClaimed {
                    Button {
                        ChallengeEngine.claim(challenge, modelContext: modelContext)
                        showClaimToast = true
                        onRefresh()
                    } label: {
                        Label("Abholen", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if challenge.canReroll {
                    Button {
                        ChallengeEngine.reroll(challenge, modelContext: modelContext)
                        onRefresh()
                    } label: {
                        Label("Neu würfeln", systemImage: "dice")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .padding(.vertical, 6)
        .alert("Challenge abgehakt!", isPresented: $showClaimToast) {
            Button("Nice.", role: .cancel) { }
        } message: {
            Text("Das war kein Zufall. Das war Disziplin. 😄")
        }
    }

    private func suggestionText(progress: ChallengeEngine.ChallengeProgress) -> String? {
        let remaining = max(0, challenge.targetValue - progress.value)
        guard remaining > 0 else { return "✅ Sauber. Jetzt einfach nur noch so tun, als wäre das völlig normal." }

        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let today = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: challenge.periodEnd)
        let daysLeft = max(0, cal.dateComponents([.day], from: today, to: end).day ?? 0)

        switch challenge.metric {
        case .readingMinutes:
            guard daysLeft > 0 else { return nil }
            let perDay = Int((Double(remaining) / Double(daysLeft)).rounded(.up))
            return "Wenn du ab heute ~\(perDay) Min/Tag liest, bist du safe im Ziel."

        case .readingDays:
            return "Noch \(remaining) Lesetag(e). Heute wäre ein guter Tag – nur so als Idee."

        case .sessions:
            guard daysLeft > 0 else { return nil }
            return "Noch \(remaining) Session(s). Mini-Sessions zählen auch: 5 Minuten sind 5 Minuten."

        case .pagesRead:
            return "Noch \(remaining) Seiten. Klingt viel – ist aber meistens nur ein Kapitel und ein Kaffee."

        case .booksFinished:
            return "Noch \(remaining) Buch/Bücher. Vielleicht das aktuelle einfach gnadenlos zu Ende bringen?"
        }
    }
}

private struct ChallengeCompactRow: View {
    let challenge: ChallengeRecord
    let progress: ChallengeEngine.ChallengeProgress?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: challenge.metric.systemImage)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(challenge.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text("\(challenge.kind.displayName) • \(challenge.periodLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let p = progress {
                    Text(p.valueText(target: challenge.targetValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
