//
//  LibraryView+Header.swift
//  Shelf Notes
//
//  Extracted from LibraryView.swift to reduce file size and improve maintainability.
//

import SwiftUI
import Foundation

extension LibraryView {

    // MARK: Quick segment (optional)

    enum QuickSortMode: String, CaseIterable, Identifiable {
        case added = "Zuletzt hinzugefügt"
        case read = "Zuletzt gelesen"
        var id: String { rawValue }
    }

    var quickSortModeBinding: Binding<QuickSortMode> {
        Binding(
            get: { sortField == .readDate ? .read : .added },
            set: { mode in
                withAnimation {
                    sortField = (mode == .read) ? .readDate : .createdAt
                    // sensible default: newest first
                    sortAscending = false
                }
            }
        )
    }

    var isHomeState: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty && selectedStatus == nil && selectedTag == nil && !onlyWithNotes
    }

    var shouldShowQuickSortSegment: Bool {
        // only show when it actually adds value
        books.count >= 8 && finishedCount > 0
    }

    // MARK: Header text + counts

    var heroSubtitle: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if books.isEmpty { return "Dein ruhiges, soziales-freies Lesetagebuch." }
        if !trimmed.isEmpty { return "Suche: „\(trimmed)“" }
        if let selectedTag { return "Filter: #\(selectedTag)" }
        if let selectedStatus { return "Filter: \(selectedStatus.displayName)" }
        if onlyWithNotes { return "Filter: nur mit Notizen" }
        return "Dein Regal — \(books.count) Bücher"
    }

    var toReadCount: Int {
        books.filter { $0.status == .toRead }.count
    }

    var readingCount: Int {
        books.filter { $0.status == .reading }.count
    }

    var finishedCount: Int {
        books.filter { $0.status == .finished }.count
    }

    func toggleStatusFilter(_ status: ReadingStatus) {
        if selectedStatus == status {
            selectedStatus = nil
        } else {
            selectedStatus = status
        }
    }

    func toggleHeaderExpanded() {
        withAnimation(.easeInOut(duration: 0.22)) {
            headerExpanded.toggle()
        }
    }

    // MARK: Header UI

    @ViewBuilder
    var filterBar: some View {
        switch libraryHeaderStyle {
        case .hidden:
            EmptyView()
        case .compact:
            compactFilterBar
        case .standard:
            standardFilterBar
        }
    }

    private var standardFilterBar: some View {
        VStack(alignment: .leading, spacing: headerExpanded ? 10 : 8) {
            headerTopRowStandard

            if headerExpanded {
                expandedHeaderContent
            } else {
                collapsedHeaderContent
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var compactFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerTopRowCompact

            if shouldShowQuickSortSegment {
                Picker("", selection: quickSortModeBinding) {
                    Text(QuickSortMode.added.rawValue).tag(QuickSortMode.added)
                    Text(QuickSortMode.read.rawValue).tag(QuickSortMode.read)
                }
                .pickerStyle(.segmented)
            }

            activeFilterChips
            countLine
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private var headerTopRowStandard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meine Bücher")
                    .font(.title3.weight(.semibold))

                Text(heroSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(headerExpanded ? 2 : 1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buch hinzufügen")

                Button {
                    toggleHeaderExpanded()
                } label: {
                    Image(systemName: headerExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(headerExpanded ? "Header einklappen" : "Header ausklappen")
            }
        }
    }

    private var headerTopRowCompact: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meine Bücher")
                    .font(.headline.weight(.semibold))

                Text(heroSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Buch hinzufügen")
        }
    }

    private var collapsedHeaderContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Count line (always visible)
            countLine

            if shouldShowQuickSortSegment {
                Picker("", selection: quickSortModeBinding) {
                    Text(QuickSortMode.added.rawValue).tag(QuickSortMode.added)
                    Text(QuickSortMode.read.rawValue).tag(QuickSortMode.read)
                }
                .pickerStyle(.segmented)
            }

            activeFilterChips
        }
    }

    private var expandedHeaderContent: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Status overview (tap = quick filter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    LibraryStatCard(
                        title: "Will ich lesen",
                        value: toReadCount,
                        systemImage: "bookmark",
                        isActive: selectedStatus == .toRead
                    ) {
                        withAnimation {
                            toggleStatusFilter(.toRead)
                        }
                    }

                    LibraryStatCard(
                        title: "Lese ich gerade",
                        value: readingCount,
                        systemImage: "book",
                        isActive: selectedStatus == .reading
                    ) {
                        withAnimation {
                            toggleStatusFilter(.reading)
                        }
                    }

                    LibraryStatCard(
                        title: "Gelesen",
                        value: finishedCount,
                        systemImage: "checkmark.seal",
                        isActive: selectedStatus == .finished
                    ) {
                        withAnimation {
                            toggleStatusFilter(.finished)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            activeFilterChips

            countLine

            if shouldShowQuickSortSegment {
                Picker("", selection: quickSortModeBinding) {
                    Text(QuickSortMode.added.rawValue).tag(QuickSortMode.added)
                    Text(QuickSortMode.read.rawValue).tag(QuickSortMode.read)
                }
                .pickerStyle(.segmented)
            }

            // Mini shelf (adds visual warmth without heavy UI)
            if isHomeState && displayedBooks.count >= 6 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(displayedBooks.prefix(12).enumerated()), id: \.element.id) { _, b in
                            NavigationLink {
                                BookDetailView(book: b)
                            } label: {
                                LibraryCoverThumb(book: b)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var activeFilterChips: some View {
        // Active filters (chips)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedStatus {
                    TagChip(text: selectedStatus.displayName, systemImage: "flag.fill") {
                        withAnimation { self.selectedStatus = nil }
                    }
                }

                if let selectedTag {
                    TagChip(text: "#\(selectedTag)", systemImage: "tag.fill") {
                        withAnimation { self.selectedTag = nil }
                    }
                }

                if onlyWithNotes {
                    TagChip(text: "mit Notizen", systemImage: "note.text") {
                        withAnimation { self.onlyWithNotes = false }
                    }
                }

                // When collapsed and there are no active filters, keep it tiny.
                if (selectedStatus == nil && selectedTag == nil && !onlyWithNotes) {
                    Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Filter: keine (noch 😄)" : "Filter aktiv")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                if selectedStatus != nil || selectedTag != nil || onlyWithNotes || !searchText.isEmpty {
                    Button("Zurücksetzen") {
                        withAnimation {
                            selectedTag = nil
                            selectedStatus = nil
                            onlyWithNotes = false
                            searchText = ""
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var countLine: some View {
        HStack(spacing: 10) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)

            Text("Bücher in deiner Liste: \(displayedBooks.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if shouldShowAlphaIndexHint {
                Text("A–Z")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }

    var alphaIndexHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "textformat.abc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("A–Z Index aktiv")
                    .font(.caption.weight(.semibold))
                Text("Tippe rechts auf einen Buchstaben, um schnell zu springen.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
