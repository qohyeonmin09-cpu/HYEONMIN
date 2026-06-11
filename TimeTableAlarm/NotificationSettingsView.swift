import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var preference = NotificationPreference()
    private let scheduler = LocalNotificationScheduler()

    var body: some View {
        NavigationStack {
            Form {
                Section("권한") {
                    HStack {
                        Text("알림 상태")
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(statusColor)
                    }

                    Button {
                        Task {
                            _ = await scheduler.requestAuthorization()
                            await refreshStatus()
                            store.updateNotificationPreference(preference)
                        }
                    } label: {
                        Label("알림 권한 요청", systemImage: "bell.badge")
                    }
                }

                Section("알림 시간") {
                    Toggle("수업 알림 사용", isOn: $preference.isEnabled)
                    Stepper("수업 시작 \(preference.leadMinutes)분 전", value: $preference.leadMinutes, in: 1...30)
                }

                if authorizationStatus == .denied {
                    Section {
                        Text("알림 권한이 꺼져 있습니다. iOS 설정 앱에서 TimeTableAlarm 알림을 허용해야 예약 알림을 받을 수 있습니다.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("알림")
            .onAppear {
                preference = store.data.notificationPreference
                Task {
                    await refreshStatus()
                }
            }
            .onChange(of: preference) { _, newValue in
                store.updateNotificationPreference(newValue)
            }
        }
    }

    private var statusText: String {
        switch authorizationStatus {
        case .notDetermined: "미설정"
        case .denied: "거부됨"
        case .authorized: "허용됨"
        case .provisional: "임시 허용"
        case .ephemeral: "일시 허용"
        @unknown default: "알 수 없음"
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .red
        default: .secondary
        }
    }

    private func refreshStatus() async {
        authorizationStatus = await scheduler.currentAuthorizationStatus()
    }
}
