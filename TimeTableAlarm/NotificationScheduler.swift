import Foundation
import UserNotifications

protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    func refreshNotifications(entries: [ScheduleEntry], periods: [PeriodTemplate], preference: NotificationPreference) async
}

struct PlannedNotification: Equatable {
    var identifier: String
    var weekday: Int
    var hour: Int
    var minute: Int
    var title: String
    var body: String
}

struct NotificationPlanner {
    static let identifierPrefix = "schedule-entry-"

    static func plannedNotifications(
        entries: [ScheduleEntry],
        periods: [PeriodTemplate],
        preference: NotificationPreference
    ) -> [PlannedNotification] {
        guard preference.isEnabled else { return [] }

        return entries.compactMap { entry in
            guard let start = entry.startMinutes(periods: periods) else { return nil }
            let alertMinutes = wrappedMinutes(start - preference.leadMinutes)
            let weekdayOffset = start - preference.leadMinutes < 0 ? -1 : 0
            let weekday = wrappedWeekday(entry.weekday.rawValue + weekdayOffset)

            return PlannedNotification(
                identifier: "\(identifierPrefix)\(entry.id.uuidString)",
                weekday: weekday,
                hour: alertMinutes / 60,
                minute: alertMinutes % 60,
                title: "곧 \(entry.subjectName) 시간이에요",
                body: "\(preference.leadMinutes)분 후 수업이 시작됩니다."
            )
        }
    }

    private static func wrappedMinutes(_ minutes: Int) -> Int {
        let day = 24 * 60
        return ((minutes % day) + day) % day
    }

    private static func wrappedWeekday(_ weekday: Int) -> Int {
        if weekday < 1 { return 7 }
        if weekday > 7 { return 1 }
        return weekday
    }
}

final class LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func refreshNotifications(entries: [ScheduleEntry], periods: [PeriodTemplate], preference: NotificationPreference) async {
        let pending = await center.pendingNotificationRequests()
        let ownedIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(NotificationPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ownedIdentifiers)

        let planned = NotificationPlanner.plannedNotifications(
            entries: entries,
            periods: periods,
            preference: preference
        )

        for notification in planned {
            var date = DateComponents()
            date.weekday = notification.weekday
            date.hour = notification.hour
            date.minute = notification.minute

            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
