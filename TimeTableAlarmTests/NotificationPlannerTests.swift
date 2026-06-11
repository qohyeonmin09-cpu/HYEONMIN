import XCTest
@testable import TimeTableAlarm

final class NotificationPlannerTests: XCTestCase {
    func testPlansFiveMinuteLeadForMondayFirstPeriod() {
        let period = PeriodTemplate(periodNumber: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 50)
        let entry = ScheduleEntry(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            weekday: .monday,
            subjectName: "수학",
            timeMode: .period,
            periodID: period.id
        )

        let planned = NotificationPlanner.plannedNotifications(
            entries: [entry],
            periods: [period],
            preference: NotificationPreference(isEnabled: true, leadMinutes: 5)
        )

        XCTAssertEqual(planned.count, 1)
        XCTAssertEqual(planned[0].weekday, Weekday.monday.rawValue)
        XCTAssertEqual(planned[0].hour, 8)
        XCTAssertEqual(planned[0].minute, 55)
        XCTAssertEqual(planned[0].title, "곧 수학 시간이에요")
    }

    func testDisablesPlanningWhenPreferenceIsOff() {
        let period = PeriodTemplate(periodNumber: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 50)
        let entry = ScheduleEntry(weekday: .monday, subjectName: "영어", timeMode: .period, periodID: period.id)

        let planned = NotificationPlanner.plannedNotifications(
            entries: [entry],
            periods: [period],
            preference: NotificationPreference(isEnabled: false, leadMinutes: 5)
        )

        XCTAssertTrue(planned.isEmpty)
    }

    func testWrapsNotificationToPreviousWeekdayWhenLeadCrossesMidnight() {
        let entry = ScheduleEntry(
            weekday: .monday,
            subjectName: "자습",
            timeMode: .custom,
            periodID: nil,
            customStartMinutes: 3,
            customEndMinutes: 50
        )

        let planned = NotificationPlanner.plannedNotifications(
            entries: [entry],
            periods: [],
            preference: NotificationPreference(isEnabled: true, leadMinutes: 5)
        )

        XCTAssertEqual(planned[0].weekday, Weekday.sunday.rawValue)
        XCTAssertEqual(planned[0].hour, 23)
        XCTAssertEqual(planned[0].minute, 58)
    }
}
