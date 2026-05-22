//
//  GoalsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData

// MARK: - Goals View
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingGoal.year, order: .reverse) private var goals: [ReadingGoal]
    @Query private var books: [Book]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var targetCount: Int = ReadingGoalDraftPolicy.defaultTargetCount
    @State private var pendingInsertedGoalsByYear: [Int: ReadingGoal] = [:]
    @State private var saveDebouncer = ModelContextSaveDebouncer()

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 62), spacing: 10)
    ]

    var body: some View {
        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: selectedYear,
            books: books,
            goals: goals
        )

        return ScrollView {
            VStack(spacing: 14) {
                goalCard(metrics: metrics)
                progressCard(metrics: metrics)
                slotsGrid(metrics: metrics)
            }
            .padding(.horizontal)
            .padding(.bottom, 18)
            .padding(.top, 12)
        }
        .navigationTitle("Leseziele")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadGoalForSelectedYear() }
        .onChange(of: selectedYear) { _, _ in
            flushPendingGoalSave()
            loadGoalForSelectedYear()
        }
        .onDisappear { flushPendingGoalSave() }
    }

    private func goalCard(metrics: GoalsYearMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ziel definieren")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Jahr", selection: $selectedYear) {
                    ForEach(metrics.availableYears, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Stepper(value: targetCountBinding, in: 1...200, step: 1) {
                    Text("\(targetCount) Bücher")
                        .monospacedDigit()
                }
            }

            Text("Tip: Füllt sich automatisch, sobald du bei „Gelesen“ den Zeitraum setzt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func progressCard(metrics: GoalsYearMetrics) -> some View {
        let done = metrics.finishedBooks.count
        let total = max(targetCount, 1)
        let pct = min(Double(done) / Double(total), 1.0)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fortschritt \(String(selectedYear))")
                    .font(.headline)
                Spacer()
                Text("\(done) / \(targetCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: pct)

            HStack(spacing: 10) {
                StatPill(systemImage: "doc.plaintext", title: "Seiten", value: formatInt(metrics.pagesReadInSelectedYear))
                StatPill(systemImage: "divide.circle", title: "Ø/Buch", value: formatOptionalInt(metrics.averagePagesPerBook))
                StatPill(systemImage: "calendar", title: "/Monat", value: formatInt(metrics.pagesPerMonth))
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func slotsGrid(metrics: GoalsYearMetrics) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<targetCount, id: \.self) { index in
                if index < metrics.finishedBooks.count {
                    let book = metrics.finishedBooks[index]
                    NavigationLink {
                        BookDetailView(book: book)
                    } label: {
                        GoalSlotView(book: book, isFilled: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    GoalSlotView(book: nil, isFilled: false)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func formatInt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatOptionalInt(_ value: Int?) -> String {
        guard let value else { return "–" }
        return formatInt(value)
    }

    private var targetCountBinding: Binding<Int> {
        Binding(
            get: { targetCount },
            set: { newValue in
                guard targetCount != newValue else {
                    return
                }

                targetCount = newValue
                saveGoal(year: selectedYear, targetCount: newValue)
            }
        )
    }

    private func loadGoalForSelectedYear() {
        let draft = ReadingGoalDraftPolicy.draftForLoading(
            year: selectedYear,
            existingGoal: goal(for: selectedYear)
        )
        targetCount = draft.targetCount
    }

    private func saveGoal(year: Int, targetCount: Int) {
        guard let change = ReadingGoalDraftPolicy.changeForUserTargetEdit(
            year: year,
            targetCount: targetCount,
            existingGoal: goal(for: year)
        ) else {
            return
        }

        switch change {
        case .insert(let year, let targetCount):
            let goal = ReadingGoal(year: year, targetCount: targetCount)
            pendingInsertedGoalsByYear[year] = goal
            modelContext.insert(goal)
        case .update(let year, let targetCount):
            guard let existing = goal(for: year) else {
                return
            }
            existing.targetCount = targetCount
            existing.updatedAt = Date()
        }

        saveDebouncer.schedule {
            modelContext.saveWithDiagnostics()
        }
    }

    private func goal(for year: Int) -> ReadingGoal? {
        goals.first(where: { $0.year == year }) ?? pendingInsertedGoalsByYear[year]
    }

    private func flushPendingGoalSave() {
        saveDebouncer.flush()
    }
}

private struct StatPill: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct GoalSlotView: View {
    @Environment(\.modelContext) private var modelContext

    let book: Book?
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(isFilled ? 0.18 : 0.12)

            if let book {
                GeometryReader { geo in
                    BookCoverThumbnailView(
                        book: book,
                        size: geo.size,
                        cornerRadius: 12,
                        contentMode: .fill
                    )
                }
            } else {
                Image(systemName: "book")
                    .opacity(0.45)
            }
        }
        .aspectRatio(2.0/3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
