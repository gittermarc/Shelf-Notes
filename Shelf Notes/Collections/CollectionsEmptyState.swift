import SwiftUI

struct CollectionsEmptyState: View {
    let hasBooks: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 8) {
                Text("Baue dein erstes kuratiertes Regal")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                benefit("Lesereihen zusammenhalten", systemImage: "books.vertical")
                benefit("Urlaubs- und Themenlisten planen", systemImage: "map")
                benefit("Bücher für später bündeln", systemImage: "bookmark")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                onCreate()
            } label: {
                Label("Liste erstellen", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .frame(maxWidth: 520)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var description: String {
        if hasBooks {
            return "Listen machen aus deiner Bibliothek kleine Kontexte: Thriller für dunkle Abende, New-York-Bücher, Sachbücher für den Urlaub oder Highlights fürs Jahr."
        }

        return "Füge Bücher hinzu und bündle sie danach in Listen für Reihen, Themen, Stimmungen oder konkrete Lesepläne."
    }

    private func benefit(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Text(text)
                .font(.subheadline.weight(.semibold))
        }
    }
}
