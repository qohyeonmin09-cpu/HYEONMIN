# TimeTableAlarm

SwiftUI iOS app for importing a school timetable photo, reviewing OCR candidates, editing the timetable, and scheduling local class reminders.

## Open

Open `TimeTableAlarm.xcodeproj` in Xcode on macOS.

## Run on this PC

Run `run-webapp.bat`, then open `http://localhost:5173/` in a browser.

## Run

1. Select the `TimeTableAlarm` scheme.
2. Choose an iPhone simulator or a real iPhone.
3. Run the app.
4. In the app, allow notifications from the `알림` tab.

## Test

Run the `TimeTableAlarmTests` target in Xcode. The included tests cover notification planning, including the Monday 09:00 class -> 08:55 reminder scenario.

## Notes

- OCR uses Apple's on-device Vision framework.
- Timetable data is stored locally as JSON in the app's documents directory.
- Class times can be edited from the `시간표` tab. Users can change period start/end times, add or delete periods, or set a custom time for an individual class.
- The web app includes a faster setup flow for a 50-minute class plus 10-minute break rhythm. By default it starts 1st period at 08:20, inserts a 60-minute lunch after 4th period, and starts 5th period at 13:10. Alerts default to 5 minutes into the break, which is also 5 minutes before the next class.
- The web app can read timetable photos with browser OCR through Tesseract.js when internet access is available, then lets the user confirm parsed timetable candidates.
- iCloud sync, account login, and book-name mapping are intentionally out of scope for this MVP.
