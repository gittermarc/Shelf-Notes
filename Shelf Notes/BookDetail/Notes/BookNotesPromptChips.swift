import SwiftUI

struct BookNotesPromptChips: View {
    let onApply: (BookNotesTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Starthilfe")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BookNotesTemplate.prompts) { template in
                        Button {
                            onApply(template)
                        } label: {
                            Label(template.title, systemImage: template.systemImage)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }
}
