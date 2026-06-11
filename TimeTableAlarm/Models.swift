import Foundation
import SwiftUI

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sunday: "일"
        case .monday: "월"
        case .tuesday: "화"
        case .wednesday: "수"
        case .thursday: "목"
        case .friday: "금"
        case .saturday: "토"
        }
    }

    static var schoolDays: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }
}

struct Subject: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

struct PeriodTemplate: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var periodNumber: Int
    var startMinutes: Int
    var endMinutes: Int

    var title: String {
        "\(periodNumber)교시"
    }
}

enum ScheduleTimeMode: String, Codable, CaseIterable, Identifiable {
    case period
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .period: "교시"
        case .custom: "직접 시간"
        }
    }
}

struct ScheduleEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekday: Weekday
    var subjectName: String
    var timeMode: ScheduleTimeMode
    var periodID: UUID?
    var customStartMinutes: Int?
    var customEndMinutes: Int?

    func startMinutes(periods: [PeriodTemplate]) -> Int? {
        switch timeMode {
        case .period:
            guard let periodID else { return nil }
            return periods.first(where: { $0.id == periodID })?.startMinutes
        case .custom:
            return customStartMinutes
        }
    }

    func endMinutes(periods: [PeriodTemplate]) -> Int? {
        switch timeMode {
        case .period:
            guard let periodID else { return nil }
            return periods.first(where: { $0.id == periodID })?.endMinutes
        case .custom:
            return customEndMinutes
        }
    }
}

struct NotificationPreference: Codable, Hashable {
    var isEnabled: Bool = true
    var leadMinutes: Int = 5
}

struct OCRImportResult: Identifiable, Hashable {
    var id: UUID = UUID()
    var rawText: String
    var candidates: [ScheduleEntry]
}

struct AppData: Codable {
    var subjects: [Subject]
    var periods: [PeriodTemplate]
    var entries: [ScheduleEntry]
    var notificationPreference: NotificationPreference

    static let empty = AppData(
        subjects: [],
        periods: PeriodTemplate.defaultSchoolPeriods,
        entries: [],
        notificationPreference: NotificationPreference()
    )
}

extension PeriodTemplate {
    static var defaultSchoolPeriods: [PeriodTemplate] {
        [
            PeriodTemplate(periodNumber: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 50),
            PeriodTemplate(periodNumber: 2, startMinutes: 10 * 60, endMinutes: 10 * 60 + 50),
            PeriodTemplate(periodNumber: 3, startMinutes: 11 * 60, endMinutes: 11 * 60 + 50),
            PeriodTemplate(periodNumber: 4, startMinutes: 12 * 60, endMinutes: 12 * 60 + 50),
            PeriodTemplate(periodNumber: 5, startMinutes: 13 * 60 + 50, endMinutes: 14 * 60 + 40),
            PeriodTemplate(periodNumber: 6, startMinutes: 14 * 60 + 50, endMinutes: 15 * 60 + 40),
            PeriodTemplate(periodNumber: 7, startMinutes: 15 * 60 + 50, endMinutes: 16 * 60 + 40)
        ]
    }
}

extension Int {
    var timeText: String {
        let hour = self / 60
        let minute = self % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let intValue = Int(value, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((intValue >> 16) & 0xFF) / 255,
            green: Double((intValue >> 8) & 0xFF) / 255,
            blue: Double(intValue & 0xFF) / 255
        )
    }
}
