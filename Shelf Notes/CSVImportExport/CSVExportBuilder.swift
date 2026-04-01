import Foundation

enum CSVExportBuilder {
    static func rows(from books: [Book]) -> [CSVRow] {
        books.map { book in
            CSVRow(title: book.title, isbn: book.isbn13 ?? "")
        }
    }

    static func data(
        from books: [Book],
        delimiter: Character = ",",
        includeHeader: Bool = true
    ) -> Data {
        CSVCodec.encode(rows(from: books), delimiter: delimiter, includeHeader: includeHeader)
    }
}
