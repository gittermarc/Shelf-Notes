//
//  StatisticsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 03.01.26.
//

import SwiftUI
import SwiftData

#if canImport(Charts)
import Charts
#endif

struct StatisticsView: View {
    @Query private var books: [Book]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var scope: Scope = .all
    @State private var activityMetric: ActivityMetric = .readingDays

    enum Scope: String, CaseIterable, Identifiable {
        case all = "Alle"
        case finished = "Gelesen"
        case reading = "Lese ich"
        case toRead = "Will lesen"
        var id: String { rawValue }
    }

    enum ActivityMetric: String, CaseIterable, Identifiable {
        case readingDays = "Lesetage"
        case completions = "Abschlüsse"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Daten",
                        systemImage: "chart.bar",
                        description: Text("Füge Bücher hinzu — dann wird’s hier schön nerdig. 📈")
                    )
                    .padding(.horizontal)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            headerCard
                            yearAndScopeCard
                            overviewGrid
                            readingChartsCard
                            activityHeatmapCard
                            topListsCard
                            nerdCornerCard
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 18)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Statistiken")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dein Lese-Dashboard")
                        .font(.title3.weight(.semibold))

                    Text(heroSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "sparkline")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if let tease = tinyTeaserLine {
                Text(tease)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var heroSubtitle: String {
        let total = scopedBooks.count
        let fin = scopedBooks.filter { $0.status == .finished }.count
        let pages = totalPages(scopedBooks)
        return "\(total) Bücher • \(fin) gelesen • \(formatInt(pages)) Seiten (wo vorhanden)"
    }

    private var tinyTeaserLine: String? {
        // etwas „nerdig“ aber nicht nervig
        let fin = finishedInSelectedYear
        guard fin.count >= 2 else { return nil }

        let speed = avgPagesPerDayText(for: fin)
        let days = avgDaysPerBookText(for: fin)

        if speed == "–" && days == "–" { return nil }
        return "Ø \(speed) Seiten/Tag • Ø \(days) Tage/Buch (für „Gelesen“ mit Zeitraum)"
    }

    // MARK: - Controls

    private var yearAndScopeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("Jahr", selection: $selectedYear) {
                    ForEach(yearOptions, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Picker("Bereich", selection: $scope) {
                    ForEach(Scope.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("Hinweis: Monats-Charts basieren auf „Gelesen“ (readTo/readFrom).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Overview

    private var overviewGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return LazyVGrid(columns: cols, spacing: 10) {
            MetricCard(title: "Bücher", value: "\(scopedBooks.count)", systemImage: "books.vertical")
            MetricCard(title: "Gelesen", value: "\(scopedBooks.filter { $0.status == .finished }.count)", systemImage: "checkmark.seal")

            MetricCard(title: "Autoren", value: "\(uniqueAuthors(scopedBooks).count)", systemImage: "person.2")
            MetricCard(title: "Verlage", value: "\(uniquePublishers(scopedBooks).count)", systemImage: "building.2")

            MetricCard(title: "Seiten (Jahr)", value: formatInt(totalPages(finishedInSelectedYear)), systemImage: "doc.plaintext")
            MetricCard(title: "Bücher (Jahr)", value: "\(finishedInSelectedYear.count)", systemImage: "calendar")

            MetricCard(title: "Ø Seiten/Buch", value: avgPagesPerBookText(for: finishedInSelectedYear), systemImage: "divide")
            MetricCard(title: "Ø Tage/Buch", value: avgDaysPerBookText(for: finishedInSelectedYear), systemImage: "clock")
        }
    }

    // MARK: - Charts

    private var readingChartsCard: some View {
        let months = monthsForSelectedYear
        let series = monthlySeriesForFinishedSelectedYear(months: months)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lesen pro Monat (\(selectedYear))")
                    .font(.headline)
                Spacer()
                Text("\(months.count) Monate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            #if canImport(Charts)
            Chart {
                ForEach(series) { m in
                    BarMark(
                        x: .value("Monat", m.monthLabel),
                        y: .value("Bücher", m.finishedCount)
                    )
                    .opacity(0.9)
                }
            }
            .frame(height: 180)

            Divider().opacity(0.6)

            Chart {
                ForEach(series) { m in
                    LineMark(
                        x: .value("Monat", m.monthLabel),
                        y: .value("Seiten", m.pages)
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Monat", m.monthLabel),
                        y: .value("Seiten", m.pages)
                    )
                    .opacity(0.12)
                }
            }
            .frame(height: 160)
            #else
            VStack(alignment: .leading, spacing: 8) {
                Text("Charts sind auf dieser Plattform nicht verfügbar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(series) { m in
                    BarListRow(
                        title: m.monthLabel,
                        valueLeft: "\(m.finishedCount) Bücher",
                        valueRight: "\(formatInt(m.pages)) Seiten",
                        fraction: fraction(m.finishedCount, maxValue: series.map(\.finishedCount).max() ?? 1)                    )
                }
            }
            #endif

            Text("Seiten zählen nur, wenn `pageCount` gesetzt ist. Bücher zählen, wenn Status „Gelesen“ + Datum vorhanden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Activity Heatmap & Streaks

    private var activityHeatmapCard: some View {
        let range = heatmapRangeForSelectedYear()
        let counts = activityDailyCounts(metric: activityMetric, range: range)
        let stats = heatmapStats(counts: counts, range: range)
        let weeks = heatmapWeeks(counts: counts, range: range)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aktivität (Heatmap)")
                    .font(.headline)

                Spacer()

                Picker("Metrik", selection: $activityMetric) {
                    ForEach(ActivityMetric.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
            }

            let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: cols, spacing: 10) {
                MetricCard(title: "Aktive Tage", value: "\(stats.activeDays)", systemImage: "calendar.badge.clock")
                MetricCard(title: "Max/Tag", value: "\(stats.maxCount)", systemImage: "sparkles")

                MetricCard(title: "Aktueller Streak", value: "\(stats.currentStreak) Tage", systemImage: "flame")
                MetricCard(title: "Längster Streak", value: "\(stats.longestStreak) Tage", systemImage: "trophy")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Bester Tag:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.bestDayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()

                    Text("Bester Wochentag:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.bestWeekdayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if stats.bestWeekLabel != "–" {
                    Text("Beste Woche: \(stats.bestWeekLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                WeekdayRail()
                    .padding(.top, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(weeks) { week in
                            VStack(spacing: 4) {
                                ForEach(week.days) { day in
                                    HeatmapCellView(
                                        date: day.date,
                                        count: day.count,
                                        level: day.level,
                                        isInRange: day.isInRange
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 2)
                }
            }

            HeatmapLegend(maxCount: stats.maxCount)
                .padding(.top, 2)

            Text(heatmapHintText(range: range))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func heatmapHintText(range: HeatmapRange) -> String {
        switch activityMetric {
        case .readingDays:
            return "„Lesetage“ zählt pro Tag, an dem ein Buch aktiv war (aus readFrom/readTo; bei „Lese ich“ bis heute). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        case .completions:
            return "„Abschlüsse“ zählt pro Tag, an dem ein Buch beendet wurde (readTo/readFrom). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        }
    }

    private struct HeatmapRange {
        let start: Date           // startOfDay
        let end: Date             // startOfDay, inclusive
        let gridStart: Date       // Monday startOfDay
        let gridEnd: Date         // Sunday startOfDay
    }

    private func heatmapRangeForSelectedYear() -> HeatmapRange {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let start = cal.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date.distantPast
        let startDay = cal.startOfDay(for: start)

        let endExclusive = cal.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? Date.distantFuture
        let endOfYear = cal.date(byAdding: .day, value: -1, to: endExclusive) ?? Date.distantFuture
        let today = cal.startOfDay(for: Date())

        let endDay: Date
        if cal.component(.year, from: today) == selectedYear {
            endDay = min(today, cal.startOfDay(for: endOfYear))
        } else {
            endDay = cal.startOfDay(for: endOfYear)
        }

        let gridStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDay)) ?? startDay
        let endWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: endDay)) ?? endDay
        let gridEnd = cal.date(byAdding: .day, value: 6, to: endWeekStart) ?? endDay

        return HeatmapRange(start: startDay, end: endDay, gridStart: gridStart, gridEnd: gridEnd)
    }

    private struct HeatmapDay: Identifiable {
        let id: Date
        let date: Date
        let count: Int
        let level: Int
        let isInRange: Bool
    }

    private struct HeatmapWeek: Identifiable {
        let id: Int
        let days: [HeatmapDay]
    }

    private func activityDailyCounts(metric: ActivityMetric, range: HeatmapRange) -> [Date: Int] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        var counts: [Date: Int] = [:]

        func addDay(_ d: Date) {
            let day = cal.startOfDay(for: d)
            guard day >= range.start && day <= range.end else { return }
            counts[day, default: 0] += 1
        }

        func addRange(from: Date, to: Date) {
            var day = cal.startOfDay(for: from)
            let end = cal.startOfDay(for: to)
            guard day <= end else { return }

            while day <= end {
                addDay(day)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        switch metric {
        case .completions:
            for b in scopedBooks where b.status == .finished {
                if let d = b.readTo ?? b.readFrom {
                    addDay(d)
                }
            }

        case .readingDays:
            for b in scopedBooks {
                switch b.status {
                case .finished:
                    if let from = b.readFrom, let to = b.readTo {
                        addRange(from: from, to: to)
                    } else if let d = b.readTo ?? b.readFrom {
                        addDay(d)
                    }

                case .reading:
                    if let from = b.readFrom {
                        let to = min(range.end, cal.startOfDay(for: Date()))
                        addRange(from: from, to: to)
                    }

                case .toRead:
                    break
                }
            }
        }

        return counts
    }

    private func heatLevel(count: Int, maxCount: Int) -> Int {
        guard count > 0 else { return 0 }
        guard maxCount > 0 else { return 0 }

        if maxCount <= 4 {
            return min(count, 4)
        }

        let r = Double(count) / Double(maxCount)
        if r <= 0.25 { return 1 }
        if r <= 0.50 { return 2 }
        if r <= 0.75 { return 3 }
        return 4
    }

    private func heatmapWeeks(counts: [Date: Int], range: HeatmapRange) -> [HeatmapWeek] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let days = cal.dateComponents([.day], from: range.gridStart, to: range.gridEnd).day ?? 0
        let weekCount = max(1, (days / 7) + 1)

        let maxCount = counts.values.max() ?? 0
        var weeks: [HeatmapWeek] = []
        weeks.reserveCapacity(weekCount)

        for w in 0..<weekCount {
            let weekStart = cal.date(byAdding: .day, value: w * 7, to: range.gridStart) ?? range.gridStart
            var weekDays: [HeatmapDay] = []
            weekDays.reserveCapacity(7)

            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: d, to: weekStart) ?? weekStart
                let day = cal.startOfDay(for: date)

                let inRange = (day >= range.start && day <= range.end)
                let count = inRange ? (counts[day] ?? 0) : 0
                let level = inRange ? heatLevel(count: count, maxCount: maxCount) : 0

                weekDays.append(
                    HeatmapDay(
                        id: day,
                        date: day,
                        count: count,
                        level: level,
                        isInRange: inRange
                    )
                )
            }

            weeks.append(HeatmapWeek(id: w, days: weekDays))
        }

        return weeks
    }

    private struct HeatmapStats {
        let activeDays: Int
        let maxCount: Int
        let currentStreak: Int
        let longestStreak: Int
        let bestDayLabel: String
        let bestWeekdayLabel: String
        let bestWeekLabel: String
    }

    private func heatmapStats(counts: [Date: Int], range: HeatmapRange) -> HeatmapStats {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let maxCount = counts.values.max() ?? 0
        let activeDays = counts.values.filter { $0 > 0 }.count

        // best day
        var bestDay: Date? = nil
        var bestDayCount: Int = 0
        for (d, c) in counts where c > 0 {
            if c > bestDayCount || (c == bestDayCount && (bestDay == nil || d < bestDay!)) {
                bestDay = d
                bestDayCount = c
            }
        }
        let bestDayLabel: String
        if let bestDay {
            bestDayLabel = "\(bestDay.formatted(date: .abbreviated, time: .omitted)) • \(bestDayCount)"
        } else {
            bestDayLabel = "–"
        }

        // weekday sums (Mo..So)
        let weekdayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        var weekdaySums = Array(repeating: 0, count: 7)

        for (d, c) in counts where c > 0 {
            let w = cal.component(.weekday, from: d) // 1=So ... 7=Sa
            let idx = (w + 5) % 7                    // 0=Mo ... 6=So
            weekdaySums[idx] += c
        }

        let bestWeekdayIdx = weekdaySums.enumerated().max(by: { $0.element < $1.element })?.offset
        let bestWeekdayLabel = (bestWeekdayIdx != nil && weekdaySums[bestWeekdayIdx!] > 0)
            ? "\(weekdayLabels[bestWeekdayIdx!]) • \(weekdaySums[bestWeekdayIdx!])"
            : "–"

        // best week (ISO KW)
        var weekSums: [String: Int] = [:]
        for (d, c) in counts where c > 0 {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
            let y = comps.yearForWeekOfYear ?? selectedYear
            let w = comps.weekOfYear ?? 0
            let key = "\(y)-\(w)"
            weekSums[key, default: 0] += c
        }
        var bestWeekKey: String? = nil
        var bestWeekSum = 0
        for (k, s) in weekSums {
            if s > bestWeekSum {
                bestWeekSum = s
                bestWeekKey = k
            }
        }
        let bestWeekLabel: String
        if let bestWeekKey, bestWeekSum > 0 {
            let parts = bestWeekKey.split(separator: "-")
            let y = parts.first.map(String.init) ?? "\(selectedYear)"
            let w = parts.dropFirst().first.map(String.init) ?? "?"
            bestWeekLabel = "KW \(w) (\(y)) • \(bestWeekSum)"
        } else {
            bestWeekLabel = "–"
        }

        func countOn(_ d: Date) -> Int { counts[cal.startOfDay(for: d)] ?? 0 }

        // current streak: from end backwards
        var currentStreak = 0
        var cursor = range.end
        while cursor >= range.start && countOn(cursor) > 0 {
            currentStreak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        // longest streak: scan forward
        var longestStreak = 0
        var running = 0
        var day = range.start
        while day <= range.end {
            if countOn(day) > 0 {
                running += 1
                longestStreak = max(longestStreak, running)
            } else {
                running = 0
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return HeatmapStats(
            activeDays: activeDays,
            maxCount: maxCount,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            bestDayLabel: bestDayLabel,
            bestWeekdayLabel: bestWeekdayLabel,
            bestWeekLabel: bestWeekLabel
        )
    }

    // MARK: - Top lists

    private var topListsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top-Listen")
                .font(.headline)

            let topGenres = topGenresList(scopedBooks, limit: 8)
            let topSubgenres = topSubgenresList(scopedBooks, limit: 8)
            let topAuthors = topAuthorsList(scopedBooks, limit: 8)
            let topPublishers = topPublishersList(scopedBooks, limit: 8)
            let topLanguages = topLanguagesList(scopedBooks, limit: 8)
            let topTags = topTagsList(scopedBooks, limit: 10)

            if topGenres.isEmpty && topSubgenres.isEmpty && topAuthors.isEmpty && topPublishers.isEmpty && topTags.isEmpty {
                Text("Noch nicht genug Metadaten — gib Büchern Kategorien/Verlage/Tags, dann wird’s hier richtig gut.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if !topGenres.isEmpty {
                    DisclosureGroup("Genres / Kategorien") {
                        TopListView(items: topGenres, valueLabel: "Bücher")
                    }
                }

                if !topSubgenres.isEmpty {
                    DisclosureGroup("Subgenres") {
                        TopListView(items: topSubgenres, valueLabel: "Bücher")
                    }
                }

                if !topAuthors.isEmpty {
                    DisclosureGroup("Autoren") {
                        TopListView(items: topAuthors, valueLabel: "Bücher")
                    }
                }

                if !topPublishers.isEmpty {
                    DisclosureGroup("Verlage") {
                        TopListView(items: topPublishers, valueLabel: "Bücher")
                    }
                }

                if !topLanguages.isEmpty {
                    DisclosureGroup("Sprachen") {
                        TopListView(items: topLanguages, valueLabel: "Bücher")
                    }
                }

                if !topTags.isEmpty {
                    DisclosureGroup("Tags") {
                        TopListView(items: topTags, valueLabel: "Treffer")
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Nerd corner

    private var nerdCornerCard: some View {
        let fin = finishedInSelectedYear

        let fastest = fastestBook(fin)
        let slowest = slowestBook(fin)
        let biggest = biggestBook(fin)
        let highestRated = highestRatedBook(scopedBooks)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Nerd Corner")
                .font(.headline)

            NerdStatRow(
                title: "Schnellstes Buch",
                value: fastest?.label ?? "–",
                systemImage: "bolt"
            )

            NerdStatRow(
                title: "Langsamstes Buch",
                value: slowest?.label ?? "–",
                systemImage: "tortoise"
            )

            NerdStatRow(
                title: "Dickstes Buch",
                value: biggest?.label ?? "–",
                systemImage: "book.closed"
            )

            NerdStatRow(
                title: "Bestbewertet",
                value: highestRated?.label ?? "–",
                systemImage: "star.bubble"
            )

            if fin.isEmpty {
                Text("Für „Schnell/Langsam“ brauchst du bei gelesenen Büchern `Von/Bis`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Data plumbing

    private var scopedBooks: [Book] {
        switch scope {
        case .all:
            return books
        case .finished:
            return books.filter { $0.status == .finished }
        case .reading:
            return books.filter { $0.status == .reading }
        case .toRead:
            return books.filter { $0.status == .toRead }
        }
    }

    private var yearOptions: [Int] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let nextYear = currentYear + 1

        var years = Set<Int>()
        years.insert(currentYear)
        years.insert(nextYear)

        for b in books {
            if let d = readKeyDate(b) {
                years.insert(cal.component(.year, from: d))
            }
            if let y = publishedYear(from: b.publishedDate) {
                years.insert(y)
            }
        }

        return years.sorted(by: >)
    }

    private var finishedInSelectedYear: [Book] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date.distantPast
        let end = cal.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? Date.distantFuture

        return scopedBooks.filter { b in
            guard b.status == .finished else { return false }
            guard let d = readKeyDate(b) else { return false }
            return d >= start && d < end
        }
    }

    private func readKeyDate(_ book: Book) -> Date? {
        guard book.status == .finished else { return nil }
        return book.readTo ?? book.readFrom
    }

    private var monthsForSelectedYear: [MonthKey] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let currentMonth = cal.component(.month, from: Date())

        let maxMonth: Int
        if selectedYear < currentYear { maxMonth = 12 }
        else if selectedYear > currentYear { maxMonth = 12 }
        else { maxMonth = max(1, currentMonth) }

        return (1...maxMonth).map { MonthKey(year: selectedYear, month: $0) }
    }

    private struct MonthKey: Hashable, Identifiable {
        let year: Int
        let month: Int
        var id: String { "\(year)-\(month)" }

        var monthLabel: String {
            let cal = Calendar.current
            let d = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
            return d.formatted(.dateTime.month(.abbreviated))
        }
    }

    private struct MonthSeriesPoint: Identifiable {
        let id: String
        let monthLabel: String
        let finishedCount: Int
        let pages: Int
    }

    private func monthlySeriesForFinishedSelectedYear(months: [MonthKey]) -> [MonthSeriesPoint] {
        let cal = Calendar.current
        var countBy: [MonthKey: Int] = [:]
        var pagesBy: [MonthKey: Int] = [:]

        for b in finishedInSelectedYear {
            guard let d = readKeyDate(b) else { continue }
            let y = cal.component(.year, from: d)
            let m = cal.component(.month, from: d)
            let key = MonthKey(year: y, month: m)

            countBy[key, default: 0] += 1
            pagesBy[key, default: 0] += (b.pageCount ?? 0)
        }

        return months.map { mk in
            MonthSeriesPoint(
                id: mk.id,
                monthLabel: mk.monthLabel,
                finishedCount: countBy[mk, default: 0],
                pages: pagesBy[mk, default: 0]
            )
        }
    }

    // MARK: - Aggregations

    private func totalPages(_ input: [Book]) -> Int {
        input.reduce(0) { $0 + ($1.pageCount ?? 0) }
    }

    private func uniqueAuthors(_ input: [Book]) -> Set<String> {
        var out = Set<String>()
        for b in input {
            let s = b.author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.insert(s) }
        }
        return out
    }

    private func uniquePublishers(_ input: [Book]) -> Set<String> {
        var out = Set<String>()
        for b in input {
            let s = (b.publisher ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.insert(s) }
        }
        return out
    }

    private func topGenresList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]

        for b in input {
            for g in extractedGenres(from: b) {
                let n = normalizeLabel(g)
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }

        return sortedCounts(counts, limit: limit)
    }
    private func topSubgenresList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]

        for b in input {
            for g in extractedSubgenres(from: b) {
                let n = normalizeLabel(g)
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }

        return sortedCounts(counts, limit: limit)
    }

    private func extractedGenres(from book: Book) -> [String] {
        // „Genres“: eher die übergeordnete Kategorie (nach Entfernen von sehr generischen Präfixen).
        // Beispiel: "Fiction / Thriller" -> Genre = "Thriller"
        // Beispiel: "Fiction / Thriller / Noir" -> Genre = "Thriller"
        var out: [String] = []

        func add(_ raw: String?) {
            let parsed = parseGenre(raw)
            let g = normalizeLabel(parsed.genre)
            guard !g.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(g) == .orderedSame }) {
                out.append(g)
            }
        }

        add(book.mainCategory)
        for c in book.categories { add(c) }

        return out
    }

    private func extractedSubgenres(from book: Book) -> [String] {
        // „Subgenres“: die spezifischste Stufe (Leaf) – wenn vorhanden.
        // Beispiel: "Fiction / Thriller" -> kein Subgenre
        // Beispiel: "Fiction / Thriller / Noir" -> Subgenre = "Noir"
        var out: [String] = []

        func add(_ raw: String?) {
            let parsed = parseGenre(raw)
            guard let s = parsed.subgenre else { return }
            let n = normalizeLabel(s)
            guard !n.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
                out.append(n)
            }
        }

        add(book.mainCategory)
        for c in book.categories { add(c) }

        return out
    }

    private struct ParsedGenre {
        let genre: String
        let subgenre: String?
    }

    private func parseGenre(_ raw: String?) -> ParsedGenre {
        let tokens = genreTokens(raw)
        guard !tokens.isEmpty else { return ParsedGenre(genre: "", subgenre: nil) }

        // 1) Kopf abschneiden (sehr generische Dinge)
        var trimmed = tokens
        while let first = trimmed.first, isGenericGenreHead(first) && trimmed.count > 1 {
            trimmed.removeFirst()
        }

        // 2) „General“ / ähnliche Enden entfernen, falls sie die Spezifität kaputt machen
        while let last = trimmed.last, isGenericGenreLeaf(last) && trimmed.count > 1 {
            trimmed.removeLast()
        }

        guard !trimmed.isEmpty else {
            return ParsedGenre(genre: tokens.first ?? "", subgenre: nil)
        }

        if trimmed.count == 1 {
            return ParsedGenre(genre: trimmed[0], subgenre: nil)
        }

        // Genre = vorletztes Element, Subgenre = letztes Element
        let genre = trimmed[trimmed.count - 2]
        let subgenre = trimmed.last

        return ParsedGenre(genre: genre, subgenre: subgenre)
    }

    private func genreTokens(_ raw: String?) -> [String] {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return [] }

        // Trennzeichen normalisieren
        let replacements: [(String, String)] = [
            (">", "/"),
            ("•", "/"),
            ("|", "/"),
            ("—", "/"),
            ("–", "/"),
            (":", "/")
        ]
        for (from, to) in replacements { s = s.replacingOccurrences(of: from, with: to) }

        let parts = s
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts
    }

    private func isGenericGenreHead(_ s: String) -> Bool {
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let generic: Set<String> = [
            "fiction",
            "nonfiction",
            "juvenile fiction",
            "juvenile nonfiction",
            "young adult fiction",
            "young adult",
            "general"
        ]
        return generic.contains(v)
    }

    private func isGenericGenreLeaf(_ s: String) -> Bool {
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let generic: Set<String> = [
            "general",
            "miscellaneous",
            "other"
        ]
        return generic.contains(v)
    }

    private func topAuthorsList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            let a = b.author.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !a.isEmpty else { continue }
            counts[a, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    private func topPublishersList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            let p = (b.publisher ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty else { continue }
            counts[p, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    private func topLanguagesList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            let l = (b.language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !l.isEmpty else { continue }
            counts[l, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    private func topTagsList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            for t in b.tags {
                let n = normalizeLabel(t.replacingOccurrences(of: "#", with: ""))
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }
        return sortedCounts(counts, limit: limit)
    }

    private func sortedCounts(_ counts: [String: Int], limit: Int) -> [(label: String, count: Int)] {
        let sorted = counts
            .map { (label: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
            }
        return Array(sorted.prefix(limit))
    }

    private func normalizeLabel(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Nerd metrics

    private func avgPagesPerBookText(for finishedBooks: [Book]) -> String {
        let arr = finishedBooks.filter { ($0.pageCount ?? 0) > 0 }
        guard !arr.isEmpty else { return "–" }
        let pages = arr.reduce(0) { $0 + ($1.pageCount ?? 0) }
        let avg = Double(pages) / Double(arr.count)
        return formatInt(Int(avg.rounded()))
    }

    private func avgDaysPerBookText(for finishedBooks: [Book]) -> String {
        let durations = finishedBooks.compactMap { daysBetween($0.readFrom, $0.readTo) }
        guard !durations.isEmpty else { return "–" }
        let avg = Double(durations.reduce(0, +)) / Double(durations.count)
        return formatInt(Int(avg.rounded()))
    }

    private func avgPagesPerDayText(for finishedBooks: [Book]) -> String {
        // nur wo pages + duration vorhanden
        var speeds: [Double] = []
        for b in finishedBooks {
            guard let pages = b.pageCount, pages > 0 else { continue }
            guard let days = daysBetween(b.readFrom, b.readTo), days > 0 else { continue }
            speeds.append(Double(pages) / Double(days))
        }
        guard !speeds.isEmpty else { return "–" }
        let avg = speeds.reduce(0, +) / Double(speeds.count)
        return formatInt(Int(avg.rounded()))
    }

    private func daysBetween(_ from: Date?, _ to: Date?) -> Int? {
        guard let from, let to else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.startOfDay(for: to)
        let comps = cal.dateComponents([.day], from: start, to: end)
        // +1, damit "von=bis" als 1 Tag zählt (realistischer für "habe es an dem Tag gelesen")
        if let d = comps.day {
            return max(1, d + 1)
        }
        return nil
    }

    private struct NerdPick {
        let label: String
        let sortKey: Int
    }

    private func fastestBook(_ finishedBooks: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in finishedBooks {
            guard let d = daysBetween(b.readFrom, b.readTo) else { continue }
            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title
            let label = "\(name) • \(formatInt(d)) Tage"
            let pick = NerdPick(label: label, sortKey: d)
            if best == nil || pick.sortKey < (best?.sortKey ?? Int.max) {
                best = pick
            }
        }
        return best
    }

    private func slowestBook(_ finishedBooks: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in finishedBooks {
            guard let d = daysBetween(b.readFrom, b.readTo) else { continue }
            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title
            let label = "\(name) • \(formatInt(d)) Tage"
            let pick = NerdPick(label: label, sortKey: d)
            if best == nil || pick.sortKey > (best?.sortKey ?? Int.min) {
                best = pick
            }
        }
        return best
    }

    private func biggestBook(_ finishedBooks: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in finishedBooks {
            let pages = b.pageCount ?? 0
            guard pages > 0 else { continue }
            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title
            let label = "\(name) • \(formatInt(pages)) Seiten"
            let pick = NerdPick(label: label, sortKey: pages)
            if best == nil || pick.sortKey > (best?.sortKey ?? 0) {
                best = pick
            }
        }
        return best
    }

    private func highestRatedBook(_ input: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in input {
            let r = b.averageRating ?? 0
            guard r > 0 else { continue }
            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title
            let cnt = b.ratingsCount ?? 0
            let label = "\(name) • \(String(format: "%.1f", r)) (\(formatInt(cnt)))"
            let pick = NerdPick(label: label, sortKey: Int((r * 10).rounded()))
            if best == nil || pick.sortKey > (best?.sortKey ?? 0) {
                best = pick
            }
        }
        return best
    }

    // MARK: - Misc helpers

    private func publishedYear(from raw: String?) -> Int? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        // häufig: "2019" oder "2019-10-01"
        let digits = raw.prefix(4).filter(\.isNumber)
        guard digits.count == 4, let y = Int(digits) else { return nil }
        return y
    }

    private func formatInt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func fraction(_ value: Int, maxValue: Int) -> Double {
        guard maxValue > 0 else { return 0 }
        return min(Swift.max(Double(value) / Double(maxValue), 0), 1)
    }
}

// MARK: - UI building blocks

private struct WeekdayRail: View {
    var body: some View {
        // GitHub-Style: nur Mo/Mi/Fr beschriften, damit’s nicht zu voll wird
        let labels: [String] = ["Mo", "", "Mi", "", "Fr", "", ""]
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, t in
                Text(t)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: 12, alignment: .leading)
            }
        }
        .frame(width: 22, alignment: .leading)
    }
}

private struct HeatmapCellView: View {
    let date: Date
    let count: Int
    let level: Int
    let isInRange: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(fillColor)
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(.primary.opacity(isInRange ? 0.06 : 0.02), lineWidth: 0.5)
            )
            .accessibilityLabel(accessibilityText)
    }

    private var fillColor: Color {
        guard isInRange else { return .clear }
        switch level {
        case 0: return Color.secondary.opacity(0.10)
        case 1: return Color.accentColor.opacity(0.20)
        case 2: return Color.accentColor.opacity(0.35)
        case 3: return Color.accentColor.opacity(0.55)
        default: return Color.accentColor.opacity(0.78)
        }
    }

    private var accessibilityText: String {
        let d = date.formatted(date: .abbreviated, time: .omitted)
        return "\(d): \(count)"
    }
}

private struct HeatmapLegend: View {
    let maxCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("Weniger")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                HeatmapCellView(date: Date(), count: 0, level: 0, isInRange: true)
                HeatmapCellView(date: Date(), count: 1, level: 1, isInRange: true)
                HeatmapCellView(date: Date(), count: 2, level: 2, isInRange: true)
                HeatmapCellView(date: Date(), count: 3, level: 3, isInRange: true)
                HeatmapCellView(date: Date(), count: 4, level: 4, isInRange: true)
            }

            Text("Mehr")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if maxCount > 0 {
                Text("Max: \(maxCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct BarListRow: View {
    let title: String
    let valueLeft: String
    let valueRight: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueLeft)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• \(valueRight)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(.primary.opacity(0.25))
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 4)
    }
}

private struct TopListView: View {
    let items: [(label: String, count: Int)]
    let valueLabel: String

    var body: some View {
        let maxCount = items.map(\.count).max() ?? 1

        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.label) { item in
                BarListRow(
                    title: item.label,
                    valueLeft: "\(item.count) \(valueLabel)",
                    valueRight: "",
                    fraction: min(max(Double(item.count) / Double(maxCount), 0), 1)
                )
            }
        }
        .padding(.top, 8)
    }
}

private struct NerdStatRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
