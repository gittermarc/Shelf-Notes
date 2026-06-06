import SwiftUI

struct StatisticsControlsSection: View {
    let yearOptions: [Int]
    @Binding var selectedYear: Int
    @Binding var scope: StatisticsScope

    var body: some View {
        StatisticsSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Jahr", selection: $selectedYear) {
                        ForEach(yearOptions, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    Picker("Bereich", selection: $scope) {
                        ForEach(StatisticsScope.allCases) { statisticsScope in
                            Text(statisticsScope.rawValue).tag(statisticsScope)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text("Hinweis: Monats-Charts basieren auf abgeschlossenen Lesedurchgängen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
