import SwiftUI

struct ScheduleEditorView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var selectedWeekday: Weekday = .monday
    @State private var editingEntry: ScheduleEntry?
    @State private var isAddingEntry = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("요일", selection: $selectedWeekday) {
                        ForEach(Weekday.schoolDays) { weekday in
                            Text(weekday.title).tag(weekday)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ForEach(store.data.periods.sorted { $0.periodNumber < $1.periodNumber }) { period in
                        PeriodRow(period: period) { updated in
                            store.updatePeriod(updated)
                        }
                    }
                    .onDelete { offsets in
                        store.deletePeriods(at: offsets)
                    }

                    Button {
                        store.addPeriod()
                    } label: {
                        Label("교시 추가", systemImage: "plus.circle")
                    }
                } header: {
                    Text("수업시간 설정")
                } footer: {
                    Text("교시 시간을 바꾸면 해당 교시를 사용하는 모든 수업 알림 시간이 함께 바뀝니다. 교시를 삭제하면 연결된 수업은 같은 시간의 직접 시간 수업으로 전환됩니다.")
                }

                Section("\(selectedWeekday.title)요일 수업") {
                    let entries = store.entries(for: selectedWeekday)
                    if entries.isEmpty {
                        Text("아직 등록된 수업이 없어요.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                ScheduleEntryRow(entry: entry, periods: store.data.periods)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            store.deleteEntries(at: offsets, weekday: selectedWeekday)
                        }
                    }
                }
            }
            .navigationTitle("시간표")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingEntry = true
                    } label: {
                        Label("수업 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingEntry) {
                EntryEditorSheet(
                    entry: ScheduleEntry(
                        weekday: selectedWeekday,
                        subjectName: "",
                        timeMode: store.data.periods.isEmpty ? .custom : .period,
                        periodID: store.data.periods.first?.id,
                        customStartMinutes: store.data.periods.isEmpty ? 9 * 60 : nil,
                        customEndMinutes: store.data.periods.isEmpty ? 9 * 60 + 50 : nil
                    ),
                    periods: store.data.periods
                ) { entry in
                    store.upsertEntry(entry)
                }
            }
            .sheet(item: $editingEntry) { entry in
                EntryEditorSheet(entry: entry, periods: store.data.periods) { updated in
                    store.upsertEntry(updated)
                }
            }
        }
    }
}

struct PeriodRow: View {
    @State var period: PeriodTemplate
    var onSave: (PeriodTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(period.title)
                .font(.headline)

            HStack {
                DatePicker("시작", selection: startBinding, displayedComponents: .hourAndMinute)
                DatePicker("종료", selection: endBinding, displayedComponents: .hourAndMinute)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: period) { _, newValue in
            onSave(normalized(newValue))
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { Date(minutesFromMidnight: period.startMinutes) },
            set: { period.startMinutes = $0.minutesFromMidnight }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { Date(minutesFromMidnight: period.endMinutes) },
            set: { period.endMinutes = $0.minutesFromMidnight }
        )
    }

    private func normalized(_ period: PeriodTemplate) -> PeriodTemplate {
        var updated = period
        if updated.endMinutes < updated.startMinutes {
            updated.endMinutes = updated.startMinutes
        }
        return updated
    }
}

struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: ScheduleEntry
    var periods: [PeriodTemplate]
    var onSave: (ScheduleEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("수업") {
                    TextField("과목명", text: $entry.subjectName)

                    Picker("요일", selection: $entry.weekday) {
                        ForEach(Weekday.schoolDays) { weekday in
                            Text(weekday.title).tag(weekday)
                        }
                    }

                    Picker("시간 방식", selection: $entry.timeMode) {
                        ForEach(availableTimeModes) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                if entry.timeMode == .period {
                    Section("교시") {
                        Picker("교시", selection: periodIDBinding) {
                            ForEach(periods.sorted { $0.periodNumber < $1.periodNumber }) { period in
                                Text("\(period.title) \(period.startMinutes.timeText)-\(period.endMinutes.timeText)")
                                    .tag(Optional(period.id))
                            }
                        }
                    }
                } else {
                    Section("직접 시간") {
                        DatePicker("시작", selection: customStartBinding, displayedComponents: .hourAndMinute)
                        DatePicker("종료", selection: customEndBinding, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle(entry.subjectName.isEmpty ? "수업 추가" : "수업 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        normalizeEntry()
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(entry.subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if periods.isEmpty {
                entry.timeMode = .custom
            }
        }
    }

    private var availableTimeModes: [ScheduleTimeMode] {
        periods.isEmpty ? [.custom] : ScheduleTimeMode.allCases
    }

    private var periodIDBinding: Binding<UUID?> {
        Binding(
            get: { entry.periodID ?? periods.first?.id },
            set: { entry.periodID = $0 }
        )
    }

    private var customStartBinding: Binding<Date> {
        Binding(
            get: { Date(minutesFromMidnight: entry.customStartMinutes ?? 9 * 60) },
            set: { entry.customStartMinutes = $0.minutesFromMidnight }
        )
    }

    private var customEndBinding: Binding<Date> {
        Binding(
            get: { Date(minutesFromMidnight: entry.customEndMinutes ?? 9 * 60 + 50) },
            set: { entry.customEndMinutes = $0.minutesFromMidnight }
        )
    }

    private func normalizeEntry() {
        entry.subjectName = entry.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.timeMode == .period, !periods.isEmpty {
            entry.periodID = entry.periodID ?? periods.first?.id
            entry.customStartMinutes = nil
            entry.customEndMinutes = nil
        } else {
            entry.timeMode = .custom
            entry.periodID = nil
            entry.customStartMinutes = entry.customStartMinutes ?? 9 * 60
            entry.customEndMinutes = max(entry.customEndMinutes ?? 9 * 60 + 50, entry.customStartMinutes ?? 9 * 60)
        }
    }
}

extension Date {
    init(minutesFromMidnight minutes: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = minutes / 60
        components.minute = minutes % 60
        self = Calendar.current.date(from: components) ?? Date()
    }

    var minutesFromMidnight: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
