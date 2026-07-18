//
//  ReadingShareInboxView.swift
//  Shelf Notes
//

import SwiftUI
import SwiftData

struct ReadingShareInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var items: [ReadingShareInboxItem]
    @State private var currentIndex = 0
    @State private var attachCanonicalReference = true
    @State private var message: String?
    @State private var importQuery: String?

    let onFinished: () -> Void

    init(items: [ReadingShareInboxItem], onFinished: @escaping () -> Void) {
        _items = State(initialValue: items)
        self.onFinished = onFinished
    }

    var body: some View {
        NavigationStack {
            Group {
                if let state = currentState {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            header(state)
                            payloadPreview(state)
                            resolutionSection(state)
                            actionSection(state)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Inbox leer",
                        systemImage: "tray",
                        description: Text("Alle geteilten Inhalte wurden verarbeitet.")
                    )
                }
            }
            .navigationTitle("Geteilte Inhalte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { finishIfNeeded() }
                }
            }
            .alert("Hinweis", isPresented: Binding(
                get: { message != nil },
                set: { newValue in
                    if !newValue { message = nil }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
            .sheet(item: Binding(
                get: { importQuery.map(ReadingShareImportRoute.init(query:)) },
                set: { route in importQuery = route?.query }
            )) { route in
                BookImportView(
                    onPick: { _ in },
                    initialQuery: route.query,
                    initialQueryOrigin: .userTyped,
                    autoSearchOnAppear: true
                )
            }
        }
    }

    private var currentItem: ReadingShareInboxItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    private var currentState: ReadingShareInboxPresentationState? {
        guard let currentItem else { return nil }
        let resolution = ReadingShareInboxProcessor.resolve(item: currentItem, modelContext: modelContext)
        return ReadingShareInboxPresentationBuilder.make(item: currentItem, resolution: resolution)
    }

    private func header(_ state: ReadingShareInboxPresentationState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(state.providerTitle, systemImage: "square.and.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(state.title)
                .font(.title3.weight(.semibold))

            Text(state.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func payloadPreview(_ state: ReadingShareInboxPresentationState) -> some View {
        if let text = state.previewText, !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Auswahl oder Notiz")
                    .font(.headline)
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func resolutionSection(_ state: ReadingShareInboxPresentationState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zuordnung")
                .font(.headline)

            switch state.resolution {
            case .matched(let match):
                matchRow(match, badge: "Sicher")

            case .needsConfirmation(let match):
                matchRow(match, badge: "Bitte prüfen")
                Text("Titel- und Autorentreffer sind unsicher. Speichere den Inhalt nur, wenn dies wirklich das richtige Buch ist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .needsImport(let preparedImport):
                Label("Kein sicherer Treffer", systemImage: "questionmark.folder")
                    .font(.subheadline.weight(.semibold))
                Text("Du kannst eine Google-Books-Suche mit \"\(preparedImport.query)\" vorbereiten oder den Eintrag bewusst verwerfen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if state.item.payload.canonicalURL != nil {
                Toggle("Kanonische URL am Buch speichern", isOn: $attachCanonicalReference)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func matchRow(_ match: ReadingShareBookMatch, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }
            if !match.author.isEmpty {
                Text(match.author)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(match.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func actionSection(_ state: ReadingShareInboxPresentationState) -> some View {
        VStack(spacing: 10) {
            switch state.resolution {
            case .matched(let match), .needsConfirmation(let match):
                Button {
                    save(state.item, bookID: match.bookID)
                } label: {
                    Label("Als Annotation speichern", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

            case .needsImport(let preparedImport):
                Button {
                    importQuery = preparedImport.query
                } label: {
                    Label("Import vorbereiten", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                discard(state.item)
            } label: {
                Label("Eintrag verwerfen", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func save(_ item: ReadingShareInboxItem, bookID: UUID) {
        do {
            _ = try ReadingShareInboxProcessor.saveAnnotation(
                for: item,
                bookID: bookID,
                modelContext: modelContext,
                attachCanonicalReference: attachCanonicalReference
            )
            advance(afterRemoving: item)
        } catch ReadingShareInboxProcessingError.duplicateAnnotation {
            message = "Dieser Share wurde bereits gespeichert. Der Inbox-Eintrag wurde bereinigt."
            advance(afterRemoving: item)
        } catch {
            message = "Der geteilte Inhalt konnte nicht gespeichert werden."
        }
    }

    private func discard(_ item: ReadingShareInboxItem) {
        do {
            try ReadingShareInboxProcessor.discard(item)
            advance(afterRemoving: item)
        } catch {
            message = "Der Inbox-Eintrag konnte nicht verworfen werden."
        }
    }

    private func advance(afterRemoving item: ReadingShareInboxItem) {
        items.removeAll { $0.id == item.id }
        if currentIndex >= items.count {
            currentIndex = max(0, items.count - 1)
        }
        attachCanonicalReference = true
        if items.isEmpty {
            finishIfNeeded()
        }
    }

    private func finishIfNeeded() {
        onFinished()
        dismiss()
    }
}

private struct ReadingShareImportRoute: Identifiable {
    var query: String
    var id: String { query }
}
