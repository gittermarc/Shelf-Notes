import SwiftUI

// MARK: - UI building blocks

struct WeekdayRail: View {
    var body: some View {
        // GitHub-Style: nur Mo/Mi/Fr beschriften, damit’s nicht zu voll wird
        let labels: [String] = ["Mo", "", "Mi", "", "Fr", "", ""]
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, t in
                Text(t)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: 12, alignment: .leading)
            }
        }
        .frame(width: 22, alignment: .leading)
    }
}

struct HeatmapCellView: View {
    let date: Date
    let count: Int
    let level: Int
    let isInRange: Bool
    var unitSuffix: String = ""

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(fillColor)
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(.primary.opacity(isInRange ? 0.06 : 0.02), lineWidth: 0.5)
            )
            .accessibilityLabel(accessibilityText)
    }

    var fillColor: Color {
        guard isInRange else { return .clear }
        switch level {
        case 0: return Color.secondary.opacity(0.10)
        case 1: return Color.accentColor.opacity(0.20)
        case 2: return Color.accentColor.opacity(0.35)
        case 3: return Color.accentColor.opacity(0.55)
        default: return Color.accentColor.opacity(0.78)
        }
    }

    var accessibilityText: String {
        let d = date.formatted(date: .abbreviated, time: .omitted)
        return "\(d): \(count)\(unitSuffix)"
    }
}

struct HeatmapLegend: View {
    let maxCount: Int
    let unitSuffix: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Weniger")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                HeatmapCellView(date: Date(), count: 0, level: 0, isInRange: true)
                HeatmapCellView(date: Date(), count: 1, level: 1, isInRange: true)
                HeatmapCellView(date: Date(), count: 2, level: 2, isInRange: true)
                HeatmapCellView(date: Date(), count: 3, level: 3, isInRange: true)
                HeatmapCellView(date: Date(), count: 4, level: 4, isInRange: true)
            }

            Text("Mehr")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if maxCount > 0 {
                Text("Max: \(maxCount)\(unitSuffix)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct BarListRow: View {
    let title: String
    let valueLeft: String
    let valueRight: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueLeft)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• \(valueRight)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(.primary.opacity(0.25))
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 4)
    }
}

struct TopListView: View {
    let items: [(label: String, count: Int)]
    let valueLabel: String

    var body: some View {
        let maxCount = items.map(\.count).max() ?? 1

        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.label) { item in
                BarListRow(
                    title: item.label,
                    valueLeft: "\(item.count) \(valueLabel)",
                    valueRight: "",
                    fraction: min(max(Double(item.count) / Double(maxCount), 0), 1)
                )
            }
        }
        .padding(.top, 8)
    }
}

struct NerdStatRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
