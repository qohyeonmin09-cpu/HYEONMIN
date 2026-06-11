import SwiftUI

@main
struct TimeTableAlarmApp: App {
    @StateObject private var store = ScheduleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
