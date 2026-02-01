import SwiftUI

#if canImport(Charts)
import Charts
#endif

extension StatisticsView {

    // MARK: - Header

    var headerCard: some View {
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

    var heroSubtitle: String {
        let total = scopedBooks.count
        let fin = scopedBooks.filter { $0.status == .finished }.count
        let pages = totalPages(scopedBooks)
        return "\(total) Bücher • \(fin) gelesen • \(formatInt(pages)) Seiten (wo vorhanden)"
    }

    var tinyTeaserLine: String? {
        // etwas „nerdig“ aber nicht nervig
        let fin = finishedInSelectedYear
        guard fin.count >= 2 else { return nil }

        let speed = avgPagesPerDayText(for: fin)
        let days = avgDaysPerBookText(for: fin)

        if speed == "–" && days == "–" { return nil }
        return "Ø \(speed) Seiten/Tag • Ø \(days) Tage/Buch (für „Gelesen“ mit Zeitraum)"
    }

    // MARK: - Controls

    var yearAndScopeCard: some View {
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

    var overviewGrid: some View {
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

    var readingChartsCard: some View {
        let key = makeStatsCacheKey()
        let cache = statsCache
        let isValid = (cache?.key == key)
        let effective = isValid ? cache : nil

        let monthsCount = monthsForSelectedYear.count
        let series = effective?.monthlySeries ?? []

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lesen pro Monat (\(selectedYear))")
                    .font(.headline)
                Spacer()
                if !isValid && isUpdatingStatsCache {
                    ProgressView()
                        .controlSize(.mini)
                }

                Text("\(monthsCount) Monate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !isValid {
                Text("Berechne Monats-Statistiken …")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                let maxBooks = series.map(\.finishedCount).max() ?? 1

                ForEach(series) { m in
                    BarListRow(
                        title: m.monthLabel,
                        valueLeft: "\(m.finishedCount) Bücher",
                        valueRight: "\(formatInt(m.pages)) Seiten",
                        fraction: fraction(m.finishedCount, maxValue: maxBooks)
                    )
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

    var activityHeatmapCard: some View {
        let key = makeHeatmapCacheKey()
        let cache = heatmapCache
        let isValid = (cache?.key == key)
        let effective = isValid ? cache : nil

        let range = effective?.range ?? heatmapRangeForSelectedYear()
        let stats = effective?.stats ?? HeatmapStats(
            activeDays: 0,
            maxCount: 0,
            currentStreak: 0,
            longestStreak: 0,
            bestDayLabel: "–",
            bestWeekdayLabel: "–",
            bestWeekLabel: "–"
        )
        let weeks = effective?.weeks ?? []

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

                if !isValid && isUpdatingHeatmapCache {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if !isValid {
                Text("Berechne Aktivitäts-Heatmap …")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: cols, spacing: 10) {
                MetricCard(title: "Aktive Tage", value: "\(stats.activeDays)", systemImage: "calendar.badge.clock")
                MetricCard(title: "Max/Tag", value: "\(formatInt(stats.maxCount))\(activityMetric.unitSuffix)", systemImage: "sparkles")

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
                                        isInRange: day.isInRange,
                                        unitSuffix: activityMetric.unitSuffix
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 2)
                }
            }

            HeatmapLegend(maxCount: stats.maxCount, unitSuffix: activityMetric.unitSuffix)
                .padding(.top, 2)

            Text(heatmapHintText(range: range))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Top lists

    var topListsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top-Listen")
                .font(.headline)

            let signature = booksSignature(books)
            let canUseCache = (statsCache?.key.scope == scope && statsCache?.key.booksSignature == signature)

            if !canUseCache {
                HStack(spacing: 8) {
                    if isUpdatingStatsCache { ProgressView().controlSize(.mini) }
                    Text("Berechne Top-Listen …")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                let topGenres = statsCache?.topGenres ?? []
                let topSubgenres = statsCache?.topSubgenres ?? []
                let topAuthors = statsCache?.topAuthors ?? []
                let topPublishers = statsCache?.topPublishers ?? []
                let topLanguages = statsCache?.topLanguages ?? []
                let topTags = statsCache?.topTags ?? []

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
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Nerd corner

    var nerdCornerCard: some View {
        let key = makeStatsCacheKey()
        let canUseCache = (statsCache?.key == key)

        let fastest = canUseCache ? statsCache?.fastest : nil
        let slowest = canUseCache ? statsCache?.slowest : nil
        let biggest = canUseCache ? statsCache?.biggest : nil
        let highestRated = canUseCache ? statsCache?.highestRated : nil

        let fin = finishedInSelectedYear

        return VStack(alignment: .leading, spacing: 12) {
            Text("Nerd Corner")
                .font(.headline)

            if !canUseCache && isUpdatingStatsCache {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text("Aktualisiere Nerd-Stats …")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
}
