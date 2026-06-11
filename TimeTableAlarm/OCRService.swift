import Foundation
import UIKit
import Vision

final class OCRService {
    func recognizeSchedule(from image: UIImage, periods: [PeriodTemplate]) async throws -> OCRImportResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let observations = try await recognizeText(in: cgImage)
        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let rawText = lines.joined(separator: "\n")
        let candidates = ScheduleTextParser.parse(lines: lines, periods: periods)
        return OCRImportResult(rawText: rawText, candidates: candidates)
    }

    private func recognizeText(in image: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: observations)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "이미지를 읽을 수 없습니다."
    }
}

enum ScheduleTextParser {
    private static let weekdayTokens: [(Weekday, [String])] = [
        (.monday, ["월", "월요일", "mon", "monday"]),
        (.tuesday, ["화", "화요일", "tue", "tuesday"]),
        (.wednesday, ["수", "수요일", "wed", "wednesday"]),
        (.thursday, ["목", "목요일", "thu", "thursday"]),
        (.friday, ["금", "금요일", "fri", "friday"])
    ]

    static func parse(lines: [String], periods: [PeriodTemplate]) -> [ScheduleEntry] {
        var entries: [ScheduleEntry] = []
        var currentWeekday: Weekday?
        var currentPeriod = periods.first

        for line in lines {
            let normalized = line.lowercased()
            if let weekday = weekday(in: normalized) {
                currentWeekday = weekday
            }

            if let periodNumber = periodNumber(in: normalized),
               let period = periods.first(where: { $0.periodNumber == periodNumber }) {
                currentPeriod = period
            }

            let subject = subjectName(from: line)
            guard
                let weekday = currentWeekday,
                let period = currentPeriod,
                !subject.isEmpty,
                !isLikelyHeader(subject)
            else {
                continue
            }

            let entry = ScheduleEntry(
                weekday: weekday,
                subjectName: subject,
                timeMode: .period,
                periodID: period.id,
                customStartMinutes: nil,
                customEndMinutes: nil
            )

            if !entries.contains(where: { $0.weekday == entry.weekday && $0.periodID == entry.periodID && $0.subjectName == entry.subjectName }) {
                entries.append(entry)
            }
        }

        return entries
    }

    private static func weekday(in text: String) -> Weekday? {
        weekdayTokens.first { _, tokens in
            tokens.contains { text.contains($0) }
        }?.0
    }

    private static func periodNumber(in text: String) -> Int? {
        let pattern = #"([1-9])\s*(교시|period|class)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let numberRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Int(text[numberRange])
    }

    private static func subjectName(from line: String) -> String {
        var subject = line
        let removals = ["월요일", "화요일", "수요일", "목요일", "금요일", "월", "화", "수", "목", "금", "교시"]
        for token in removals {
            subject = subject.replacingOccurrences(of: token, with: " ")
        }
        subject = subject.replacingOccurrences(of: #"\d{1,2}[:：]\d{2}"#, with: " ", options: .regularExpression)
        subject = subject.replacingOccurrences(of: #"\b[1-9]\b"#, with: " ", options: .regularExpression)
        subject = subject.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return subject.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelyHeader(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return ["시간표", "timetable", "schedule", "period"].contains { lowered.contains($0) }
    }
}
