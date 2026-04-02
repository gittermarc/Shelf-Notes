import SwiftUI

struct BookNotesEditorToolbar: ToolbarContent {
    let onApply: (BookNotesTemplate) -> Void
    let onClear: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            ForEach(BookNotesTemplate.toolbarActions) { template in
                Button {
                    onApply(template)
                } label: {
                    Image(systemName: template.systemImage)
                }
                .help(template.title)
            }

            Spacer()

            Button(role: .destructive) {
                onClear()
            } label: {
                Image(systemName: "trash")
            }
            .help("Notiz leeren")
        }
    }
}
