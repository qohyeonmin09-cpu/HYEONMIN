import Foundation

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var data: AppData

    private let fileURL: URL
    private let scheduler: NotificationScheduling

    init(
        fileURL: URL = ScheduleStore.defaultFileURL,
        scheduler: NotificationScheduling = LocalNotificationScheduler()
    ) {
        self.fileURL = fileURL
        self.scheduler = scheduler
        self.data = Self.load(from: fileURL)
    }

    static var defaultFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("schedule-data.json")
    }

    func addEntries(_ entries: [ScheduleEntry]) {
        guard !entries.isEmpty else { return }
        data.entries.append(contentsOf: entries)
        mergeSubjects(from: entries)
        persistAndRefreshNotifications()
    }

    func upsertEntry(_ entry: ScheduleEntry) {
        if let index = data.entries.firstIndex(where: { $0.id == entry.id }) {
            data.entries[index] = entry
        } else {
            data.entries.append(entry)
        }
        mergeSubjects(from: [entry])
        persistAndRefreshNotifications()
    }

    func deleteEntries(at offsets: IndexSet, weekday: Weekday? = nil) {
        if let weekday {
            let ids = entries(for: weekday).enumerated()
                .filter { offsets.contains($0.offset) }
                .map(\.element.id)
            data.entries.removeAll { ids.contains($0.id) }
        } else {
            for index in offsets.sorted(by: >) where data.entries.indices.contains(index) {
                data.entries.remove(at: index)
            }
        }
        persistAndRefreshNotifications()
    }

    func updatePeriod(_ period: PeriodTemplate) {
        guard let index = data.periods.firstIndex(where: { $0.id == period.id }) else { return }
        data.periods[index] = period
        data.periods.sort { $0.periodNumber < $1.periodNumber }
        persistAndRefreshNotifications()
    }

    func addPeriod() {
        let lastPeriod = data.periods.max { $0.periodNumber < $1.periodNumber }
        let nextNumber = (lastPeriod?.periodNumber ?? 0) + 1
        let start = min((lastPeriod?.endMinutes ?? 8 * 60 + 50) + 10, 23 * 60)
        let end = min(start + 50, 23 * 60 + 59)

        data.periods.append(
            PeriodTemplate(
                periodNumber: nextNumber,
                startMinutes: start,
                endMinutes: max(end, start)
            )
        )
        data.periods.sort { $0.periodNumber < $1.periodNumber }
        persistAndRefreshNotifications()
    }

    func deletePeriods(at offsets: IndexSet) {
        let sortedPeriods = data.periods.sorted { $0.periodNumber < $1.periodNumber }
        let periodsToDelete = sortedPeriods.enumerated()
            .filter { offsets.contains($0.offset) }
            .map(\.element)

        guard !periodsToDelete.isEmpty else { return }

        for period in periodsToDelete {
            for index in data.entries.indices where data.entries[index].periodID == period.id {
                data.entries[index].timeMode = .custom
                data.entries[index].periodID = nil
                data.entries[index].customStartMinutes = period.startMinutes
                data.entries[index].customEndMinutes = period.endMinutes
            }
        }

        let deletedIDs = Set(periodsToDelete.map(\.id))
        data.periods.removeAll { deletedIDs.contains($0.id) }
        data.periods.sort { $0.periodNumber < $1.periodNumber }
        persistAndRefreshNotifications()
    }

    func updateNotificationPreference(_ preference: NotificationPreference) {
        data.notificationPreference = preference
        persistAndRefreshNotifications()
    }

    func entries(for weekday: Weekday) -> [ScheduleEntry] {
        data.entries
            .filter { $0.weekday == weekday }
            .sorted { lhs, rhs in
                (lhs.startMinutes(periods: data.periods) ?? Int.max) < (rhs.startMinutes(periods: data.periods) ?? Int.max)
            }
    }

    func todayEntries(calendar: Calendar = .current) -> [ScheduleEntry] {
        let weekdayValue = calendar.component(.weekday, from: Date())
        guard let weekday = Weekday(rawValue: weekdayValue) else { return [] }
        let now = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())
        return entries(for: weekday).filter { ($0.endMinutes(periods: data.periods) ?? 0) >= now }
    }

    private func persistAndRefreshNotifications() {
        save()
        Task {
            await scheduler.refreshNotifications(
                entries: data.entries,
                periods: data.periods,
                preference: data.notificationPreference
            )
        }
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save schedule data: \(error)")
        }
    }

    private func mergeSubjects(from entries: [ScheduleEntry]) {
        let palette = ["#2F80ED", "#27AE60", "#EB5757", "#9B51E0", "#F2994A", "#00A8A8", "#4F4F4F"]
        for entry in entries {
            let trimmed = entry.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !data.subjects.contains(where: { $0.name == trimmed }) else { continue }
            data.subjects.append(Subject(name: trimmed, colorHex: palette[data.subjects.count % palette.count]))
        }
    }

    private static func load(from url: URL) -> AppData {
        guard let data = try? Data(contentsOf: url) else {
            return .empty
        }

        do {
            return try JSONDecoder().decode(AppData.self, from: data)
        } catch {
            return .empty
        }
    }
}
