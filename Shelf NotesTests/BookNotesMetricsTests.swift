import Testing
@testable import Shelf_Notes

struct BookNotesMetricsTests {
    @Test func emptyTextUsesFriendlyFallbackLines() {
        let metrics = BookNotesMetrics(text: "  \n \n")

        #expect(metrics.isEmpty)
        #expect(metrics.wordCount == 0)
        #expect(metrics.paragraphCount == 0)
        #expect(metrics.summaryLine == "Noch keine Notiz")
        #expect(metrics.detailLine == "Platz für Gedanken, Zitate und kleine Aha-Momente.")
    }

    @Test func metricsCountWordsParagraphsAndPreviewDeterministically() {
        let text = "Erster Gedanke zum Buch.\n\nDas Ende war mutig und ziemlich konsequent."
        let metrics = BookNotesMetrics(text: text)

        #expect(!metrics.isEmpty)
        #expect(metrics.wordCount == 11)
        #expect(metrics.paragraphCount == 2)
        #expect(metrics.previewText == "Erster Gedanke zum Buch. Das Ende war mutig und ziemlich konsequent.")
        #expect(metrics.summaryLine == "11 Wörter · 2 Absätze")
        #expect(metrics.detailLine == "69 Zeichen · 2 Absätze")
    }
}
