import Foundation

extension StatisticsView {

    // MARK: - Misc helpers

    func publishedYear(from raw: String?) -> Int? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        // häufig: "2019" oder "2019-10-01"
        let digits = raw.prefix(4).filter(\.isNumber)
        guard digits.count == 4, let y = Int(digits) else { return nil }
        return y
    }

    private static let _intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f
    }()

    func formatInt(_ n: Int) -> String {
        Self._intFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    func fraction(_ value: Int, maxValue: Int) -> Double {
        guard maxValue > 0 else { return 0 }
        return min(Swift.max(Double(value) / Double(maxValue), 0), 1)
    }
}
