import Foundation

struct BookNotesTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let snippet: String

    static let prompts: [BookNotesTemplate] = [
        BookNotesTemplate(id: "thought", title: "Gedanke", systemImage: "lightbulb", snippet: "Gedanke:\n"),
        BookNotesTemplate(id: "quote", title: "Zitat", systemImage: "text.quote", snippet: "Zitat:\n“”\n"),
        BookNotesTemplate(id: "characters", title: "Charaktere", systemImage: "person.2", snippet: "Charaktere:\n- \n"),
        BookNotesTemplate(id: "theme", title: "Thema", systemImage: "tag", snippet: "Thema:\n- \n"),
        BookNotesTemplate(id: "remember", title: "Merken", systemImage: "bookmark", snippet: "Merken:\n- \n")
    ]

    static let toolbarActions: [BookNotesTemplate] = [
        BookNotesTemplate(id: "bullet", title: "Liste", systemImage: "list.bullet", snippet: "• "),
        BookNotesTemplate(id: "dash", title: "Gedankenstrich", systemImage: "minus", snippet: "– "),
        BookNotesTemplate(id: "quoteBlock", title: "Zitatblock", systemImage: "text.quote", snippet: "„“"),
        BookNotesTemplate(id: "spacer", title: "Leerzeile", systemImage: "arrow.turn.down.left", snippet: "\n\n")
    ]
}

enum BookNotesInsertion {
    static func applying(template: BookNotesTemplate, to text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return template.snippet }

        switch template.id {
        case "spacer":
            if text.hasSuffix("\n\n") {
                return text
            }
            if text.hasSuffix("\n") {
                return text + "\n"
            }
            return text + "\n\n"
        case "bullet", "dash":
            if text.hasSuffix("\n") {
                return text + template.snippet
            }
            return text + "\n" + template.snippet
        default:
            if text.hasSuffix("\n\n") {
                return text + template.snippet
            }
            if text.hasSuffix("\n") {
                return text + "\n" + template.snippet
            }
            return text + "\n\n" + template.snippet
        }
    }
}
