import SwiftUI

struct TodayScheduleView: View {
    @EnvironmentObject private var store: ScheduleStore

    var body: some View {
        NavigationStack {
            List {
                let entries = store.todayEntries()
                if entries.isEmpty {
                    ContentUnavailableView("오늘 남은 수업이 없어요", systemImage: "checkmark.circle")
                } else {
                    Section("다음 수업") {
                        if let next = entries.first {
                            ScheduleEntryRow(entry: next, periods: store.data.periods, isProminent: true)
                        }
                    }

                    Section("오늘 남은 시간표") {
                        ForEach(entries) { entry in
                            ScheduleEntryRow(entry: entry, periods: store.data.periods)
                        }
                    }
                }
            }
            .navigationTitle("오늘")
        }
    }
}

struct ScheduleEntryRow: View {
    var entry: ScheduleEntry
    var periods: [PeriodTemplate]
    var isProminent: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.subjectName)
                    .font(isProminent ? .title3.bold() : .body)
                Text(timeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.weekday.title)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue, in: Circle())
        }
        .padding(.vertical, isProminent ? 8 : 2)
    }

    private var timeText: String {
        guard let start = entry.startMinutes(periods: periods), let end = entry.endMinutes(periods: periods) else {
            return "시간 미설정"
        }

        if entry.timeMode == .period,
           let periodID = entry.periodID,
           let period = periods.first(where: { $0.id == periodID }) {
            return "\(period.title) · \(start.timeText)-\(end.timeText)"
        }

        return "\(start.timeText)-\(end.timeText)"
    }
}
