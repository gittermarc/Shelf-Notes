import SwiftUI

struct CollectionsExplorerControls: View {
    @Binding var sortMode: CollectionsDashboardSortMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Listen durchsuchen")
                .font(.headline)

            Picker("Sortierung", selection: $sortMode) {
                ForEach(CollectionsDashboardSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
