import SwiftUI

struct CollectionDetailBookFilterBar: View {
    @Binding var searchText: String
    @Binding var statusFilter: CollectionDetailStatusFilter
    @Binding var sortMode: CollectionDetailSortMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Bücher in dieser Liste suchen", text: $searchText)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suche löschen")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Picker("Status", selection: $statusFilter) {
                ForEach(CollectionDetailStatusFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Label("Sortierung", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Picker("Sortierung", selection: $sortMode) {
                    ForEach(CollectionDetailSortMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, 4)
        }
    }
}
