import SwiftUI

struct TodoEditFormView: View {
    @Binding var title: String
    @Binding var memo: String
    @Binding var categoryId: String?
    @Binding var date: Date
    @Binding var showDatePicker: Bool
    @Binding var scheduledTime: Date?
    @Binding var alarmOffset: Int?
    @Binding var recurrence: RecurrenceRule?
    @Binding var recurrenceEndDate: Date?
    @Binding var recurrenceCount: Int?
    let categories: [Category]
    var autoFocus: Bool = true
    let isPro: Bool
    let onRepeatTap: () -> Void

    @State private var showTimePicker = false
    @State private var timePickerValue: Date = .now
    @State private var showCustomAlarmInput = false
    @State private var customAlarmNumber = 30
    @State private var customAlarmUnit = 0

    // 반복 설정 로컬 상태
    @State private var recurrenceKind: RecurrenceKind = .none
    @State private var selectedWeekdays: Set<Int> = []
    @State private var endCondition: EndCondition = .none
    @State private var showEndDatePicker = false
    @State private var recurrenceCountInput = 4

    private enum EndCondition { case none, date, count }

    private static let unitNames = ["분", "시간", "일", "주", "개월"]
    private static let unitMultipliers = [1, 60, 1440, 10080, 43200]
    private static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        Section {
            AutoFocusTextField(
                text: $title,
                placeholder: "할일",
                font: .systemFont(ofSize: 20, weight: .medium),
                autoFocus: autoFocus
            )
            .frame(height: 44)

            TextField("메모", text: $memo, axis: .vertical)
                .lineLimit(3...6)
        }

        Section {
            // 카테고리
            Picker("카테고리", selection: $categoryId) {
                Text("없음").tag(Optional<String>.none)
                ForEach(categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .simultaneousGesture(TapGesture().onEnded { resignKeyboard() })

            // 날짜
            Button {
                resignKeyboard()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { showDatePicker.toggle() }
            } label: {
                HStack {
                    Text("날짜").foregroundStyle(.primary)
                    Spacer()
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            if showDatePicker {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(AppTheme.shared.accent)
            }

            // 시간
            Button {
                resignKeyboard()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation {
                    if scheduledTime == nil {
                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
                        comps.hour = 9
                        comps.minute = 0
                        let defaultTime = Calendar.current.date(from: comps) ?? date
                        scheduledTime = defaultTime
                        timePickerValue = defaultTime
                        showTimePicker = true
                    } else {
                        timePickerValue = scheduledTime ?? date
                        showTimePicker.toggle()
                    }
                }
            } label: {
                HStack {
                    Text("시간").foregroundStyle(.primary)
                    Spacer()
                    if let st = scheduledTime {
                        Text(st, format: .dateTime.hour().minute())
                            .foregroundStyle(.primary)
                    } else {
                        Text("없음").foregroundStyle(.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showTimePicker {
                HStack {
                    Button("없음") {
                        withAnimation { clearTime() }
                    }
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("완료") {
                        let cal = Calendar.current
                        var comps = cal.dateComponents([.year, .month, .day], from: date)
                        let timeComps = cal.dateComponents([.hour, .minute], from: timePickerValue)
                        comps.hour = timeComps.hour
                        comps.minute = timeComps.minute
                        if let confirmed = cal.date(from: comps) {
                            scheduledTime = confirmed
                        }
                        withAnimation { showTimePicker = false }
                    }
                    .tint(AppTheme.shared.accent)
                    .fontWeight(.semibold)
                }

                DatePicker(
                    "",
                    selection: $timePickerValue,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(AppTheme.shared.accent)
            }

            // 알림 (시간 설정 시에만 표시)
            if scheduledTime != nil {
                Picker("알림", selection: Binding(
                    get: { alarmPickerSelection },
                    set: { value in
                        resignKeyboard()
                        if value == Optional(-1) {
                            customAlarmNumber = 30
                            customAlarmUnit = 0
                            alarmOffset = 30
                            showCustomAlarmInput = true
                        } else {
                            alarmOffset = value
                            showCustomAlarmInput = false
                        }
                    }
                )) {
                    Text("없음").tag(Optional<Int>.none)
                    Text("정시").tag(Optional(0))
                    Text("5분 전").tag(Optional(5))
                    Text("10분 전").tag(Optional(10))
                    Text("15분 전").tag(Optional(15))
                    Text("30분 전").tag(Optional(30))
                    Text("1시간 전").tag(Optional(60))
                    Text("2시간 전").tag(Optional(120))
                    Text("1일 전").tag(Optional(1440))
                    Text("2일 전").tag(Optional(2880))
                    Text("1주 전").tag(Optional(10080))
                    Text("직접 입력").tag(Optional(-1))
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .simultaneousGesture(TapGesture().onEnded { resignKeyboard() })

                if showCustomAlarmInput {
                    HStack(spacing: 0) {
                        Picker("", selection: $customAlarmNumber) {
                            ForEach(1...999, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("", selection: $customAlarmUnit) {
                            ForEach(0..<Self.unitNames.count, id: \.self) { i in
                                Text(Self.unitNames[i]).tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 150)
                    .onChange(of: customAlarmNumber) { _, _ in updateCustomAlarm() }
                    .onChange(of: customAlarmUnit) { _, _ in updateCustomAlarm() }
                }
            }
        }

        Section {
            if isPro {
                // 반복 종류
                Picker("반복", selection: $recurrenceKind) {
                    ForEach(RecurrenceKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .tint(recurrence != nil ? AppTheme.shared.accent : .primary)
                .simultaneousGesture(TapGesture().onEnded { resignKeyboard() })
                .onChange(of: recurrenceKind) { _, _ in syncRecurrenceBinding() }

                // 요일 선택 (매주/격주)
                if recurrenceKind.needsWeekdaySelection {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let isSelected = selectedWeekdays.contains(i)
                            Button {
                                if isSelected { selectedWeekdays.remove(i) }
                                else { selectedWeekdays.insert(i) }
                                syncRecurrenceBinding()
                            } label: {
                                Text(Self.weekdayNames[i])
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 32, height: 32)
                                    .background(isSelected ? AppTheme.shared.accent : Color(.systemGray5))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 종료 조건
                Picker("종료", selection: $endCondition) {
                    Text("없음").tag(EndCondition.none)
                    Text("날짜 지정").tag(EndCondition.date)
                    Text("횟수 지정").tag(EndCondition.count)
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .simultaneousGesture(TapGesture().onEnded { resignKeyboard() })
                .onChange(of: endCondition) { _, newVal in
                    switch newVal {
                    case .none:  recurrenceEndDate = nil; recurrenceCount = nil
                    case .date:  recurrenceCount = nil
                    case .count: recurrenceEndDate = nil
                    }
                }

                if endCondition == .date {
                    Button {
                        resignKeyboard()
                        withAnimation { showEndDatePicker.toggle() }
                    } label: {
                        HStack {
                            Text("종료 날짜").foregroundStyle(.primary)
                            Spacer()
                            Text((recurrenceEndDate ?? Date()).formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    if showEndDatePicker {
                        DatePicker("", selection: Binding(
                            get: { recurrenceEndDate ?? Date() },
                            set: { recurrenceEndDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(AppTheme.shared.accent)
                    }
                }

                if endCondition == .count {
                    Stepper("\(recurrenceCountInput)회 반복", value: $recurrenceCountInput, in: 1...999)
                        .onChange(of: recurrenceCountInput) { _, v in recurrenceCount = v }
                }

                // 시간 미설정 경고
                if recurrence != nil && scheduledTime == nil {
                    Text("알림을 받으려면 시간을 설정하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(action: onRepeatTap) {
                    HStack {
                        Text("반복 설정").foregroundStyle(.primary)
                        Spacer()
                        Text("🔒 Pro").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { loadRecurrenceState() }
    }

    // MARK: - Private

    private func loadRecurrenceState() {
        guard let rule = recurrence else {
            recurrenceKind = .none
            selectedWeekdays = []
            return
        }
        recurrenceKind = rule.kind
        selectedWeekdays = Set(rule.weekdayIndices)
        if let count = recurrenceCount {
            endCondition = .count
            recurrenceCountInput = count
        } else if recurrenceEndDate != nil {
            endCondition = .date
        } else {
            endCondition = .none
        }
    }

    private func syncRecurrenceBinding() {
        if recurrenceKind == .none {
            recurrence = nil
            return
        }
        if recurrenceKind.needsWeekdaySelection {
            let weekdays = selectedWeekdays.isEmpty
                ? [Calendar.current.component(.weekday, from: date) - 1]
                : Array(selectedWeekdays)
            recurrence = recurrenceKind.toRule(weekdays: weekdays)
        } else {
            recurrence = recurrenceKind.toRule()
        }
    }

    private var alarmPickerSelection: Int? {
        guard let offset = alarmOffset else { return nil }
        let presets = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080]
        return presets.contains(offset) ? offset : Optional(-1)
    }

    private func resignKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func clearTime() {
        withAnimation {
            scheduledTime = nil
            alarmOffset = nil
            showTimePicker = false
            showCustomAlarmInput = false
        }
    }

    private func clearAlarm() {
        withAnimation {
            alarmOffset = nil
            showCustomAlarmInput = false
        }
    }

    private func selectPreset(_ offset: Int?) {
        alarmOffset = offset
        showCustomAlarmInput = false
    }

    private func updateCustomAlarm() {
        alarmOffset = customAlarmNumber * Self.unitMultipliers[customAlarmUnit]
    }

    private func alarmLabel(_ offset: Int?) -> String {
        guard let offset else { return "없음" }
        switch offset {
        case 0:     return "정시"
        case 5:     return "5분 전"
        case 10:    return "10분 전"
        case 15:    return "15분 전"
        case 30:    return "30분 전"
        case 60:    return "1시간 전"
        case 120:   return "2시간 전"
        case 1440:  return "1일 전"
        case 2880:  return "2일 전"
        case 10080: return "1주 전"
        default:    return customLabel(offset)
        }
    }

    private func customLabel(_ minutes: Int) -> String {
        if minutes % 43200 == 0 { return "\(minutes / 43200)개월 전" }
        if minutes % 10080 == 0 { return "\(minutes / 10080)주 전" }
        if minutes % 1440 == 0  { return "\(minutes / 1440)일 전" }
        if minutes % 60 == 0    { return "\(minutes / 60)시간 전" }
        return "\(minutes)분 전"
    }
}
