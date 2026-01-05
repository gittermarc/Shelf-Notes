//
//  GoalsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Goals View
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingGoal.year, order: .reverse) private var goals: [ReadingGoal]
    @Query private var books: [Book]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var targetCount: Int = 50

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 62), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    goalCard
                    progressCard
                    slotsGrid
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
                .padding(.top, 12)
            }
            .navigationTitle("Leseziele")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadGoalForSelectedYear() }
            .onChange(of: selectedYear) { _, _ in loadGoalForSelectedYear() }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ziel definieren")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Jahr", selection: $selectedYear) {
                    ForEach(yearOptions, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Stepper(value: $targetCount, in: 1...200, step: 1) {
                    Text("\(targetCount) Bücher")
                        .monospacedDigit()
                }
                .onChange(of: targetCount) { _, newValue in
                    saveGoal(year: selectedYear, targetCount: newValue)
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

    private var progressCard: some View {
        let done = finishedBooksInSelectedYear.count
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
                StatPill(systemImage: "doc.plaintext", title: "Seiten", value: formatInt(pagesReadInSelectedYear))
                StatPill(systemImage: "divide.circle", title: "Ø/Buch", value: avgPagesPerBookText)
                StatPill(systemImage: "calendar", title: "/Monat", value: pagesPerMonthText)
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var slotsGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<targetCount, id: \.self) { index in
                if index < finishedBooksInSelectedYear.count {
                    let book = finishedBooksInSelectedYear[index]
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

    private var yearOptions: [Int] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let nextYear = currentYear + 1

        var years = Set<Int>()
        years.insert(currentYear)
        years.insert(nextYear)

        for b in books {
            guard b.status == .finished else { continue }
            if let d = b.readTo ?? b.readFrom {
                years.insert(cal.component(.year, from: d))
            }
        }

        for g in goals {
            years.insert(g.year)
        }

        return years.sorted(by: >)
    }

    private var finishedBooksInSelectedYear: [Book] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date.distantPast
        let end = cal.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? Date.distantFuture

        let filtered = books.filter { book in
            guard book.status == .finished else { return false }
            let keyDate = book.readTo ?? book.readFrom
            guard let d = keyDate else { return false }
            return d >= start && d < end
        }

        return filtered.sorted { a, b in
            let da = a.readTo ?? a.readFrom ?? a.createdAt
            let db = b.readTo ?? b.readFrom ?? b.createdAt
            return da < db
        }
    }

    private var pagesReadInSelectedYear: Int {
        finishedBooksInSelectedYear.reduce(0) { partial, book in
            partial + (book.pageCount ?? 0)
        }
    }

    private var countedBooksWithPagesInSelectedYear: [Book] {
        finishedBooksInSelectedYear.filter { ($0.pageCount ?? 0) > 0 }
    }

    private var avgPagesPerBookText: String {
        let arr = countedBooksWithPagesInSelectedYear
        guard !arr.isEmpty else { return "–" }
        let pages = arr.reduce(0) { $0 + ($1.pageCount ?? 0) }
        let avg = Double(pages) / Double(arr.count)
        return formatInt(Int(avg.rounded()))
    }

    private var pagesPerMonthText: String {
        let months = monthsCountForSelectedYear()
        guard months > 0 else { return "–" }
        let perMonth = Double(pagesReadInSelectedYear) / Double(months)
        return formatInt(Int(perMonth.rounded()))
    }

    private func monthsCountForSelectedYear() -> Int {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())

        if selectedYear < currentYear { return 12 }
        if selectedYear > currentYear { return 12 }

        let month = cal.component(.month, from: Date())
        return max(1, month)
    }

    private func formatInt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func loadGoalForSelectedYear() {
        if let existing = goals.first(where: { $0.year == selectedYear }) {
            targetCount = max(existing.targetCount, 1)
        } else {
            targetCount = 50
            saveGoal(year: selectedYear, targetCount: targetCount)
        }
    }

    private func saveGoal(year: Int, targetCount: Int) {
        if let existing = goals.first(where: { $0.year == year }) {
            existing.targetCount = targetCount
            existing.updatedAt = Date()
        } else {
            let goal = ReadingGoal(year: year, targetCount: targetCount)
            modelContext.insert(goal)
        }
        try? modelContext.save()
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
