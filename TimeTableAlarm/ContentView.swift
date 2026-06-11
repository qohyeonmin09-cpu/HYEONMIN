import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayScheduleView()
                .tabItem {
                    Label("오늘", systemImage: "clock")
                }

            ScheduleImportView()
                .tabItem {
                    Label("가져오기", systemImage: "camera.viewfinder")
                }

            ScheduleEditorView()
                .tabItem {
                    Label("시간표", systemImage: "calendar")
                }

            NotificationSettingsView()
                .tabItem {
                    Label("알림", systemImage: "bell")
                }
        }
    }
}
