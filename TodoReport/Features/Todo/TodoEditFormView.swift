import SwiftUI

struct TodoEditFormView: View {
    @Binding var title: String
    @Binding var memo: String
    @Binding var categoryId: String?
    @Binding var date: Date
    @Binding var showDatePicker: Bool
    @Binding var scheduledTime: Date?
    @Binding var alarmOffset: Int?
    let categories: [Category]
    var autoFocus: Bool = true

    private var localizedCalendar: Calendar { AppCalendar.localized }

    @State private var showTimePicker = false
    @State private var timePickerValue: Date = .now
    @State private var showCustomAlarmInput = false
    @State private var customAlarmNumber = 30
    @State private var customAlarmUnit = 0

    private static let unitNames = ["분", "시간", "일", "주", "개월"]
    private static let unitMultipliers = [1, 60, 1440, 10080, 43200]

    var body: some View {
        Section {
            AutoFocusTextField(
                text: $title,
                placeholder: "할일",
                textStyle: .title3,
                autoFocus: autoFocus,
                axis: .vertical
            )

            TextField("메모", text: $memo, axis: .vertical)
                .lineLimit(3...6)
        }

        Section {
            // 카테고리
            Picker("카테고리", selection: $categoryId) {
                Text("없음").foregroundStyle(.secondary).tag(Optional<String>.none)
                ForEach(categories) { category in
                    Text(category.name).foregroundStyle(.secondary).tag(Optional(category.id))
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
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
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6), in: Capsule())
                }
            }
            .buttonStyle(.plain)

            if showDatePicker {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(AppTheme.shared.accent)
                    .environment(\.calendar, localizedCalendar)
            }

            // 시간
            HStack {
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
                                .foregroundStyle(.secondary)
                        } else {
                            Text("없음").foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if scheduledTime != nil {
                    Button {
                        withAnimation { clearTime() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

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
                .environment(\.calendar, localizedCalendar)
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
                    Text("없음").foregroundStyle(.secondary).tag(Optional<Int>.none)
                    Text("정시").foregroundStyle(.secondary).tag(Optional(0))
                    Text("5분 전").foregroundStyle(.secondary).tag(Optional(5))
                    Text("10분 전").foregroundStyle(.secondary).tag(Optional(10))
                    Text("15분 전").foregroundStyle(.secondary).tag(Optional(15))
                    Text("30분 전").foregroundStyle(.secondary).tag(Optional(30))
                    Text("1시간 전").foregroundStyle(.secondary).tag(Optional(60))
                    Text("2시간 전").foregroundStyle(.secondary).tag(Optional(120))
                    Text("1일 전").foregroundStyle(.secondary).tag(Optional(1440))
                    Text("2일 전").foregroundStyle(.secondary).tag(Optional(2880))
                    Text("1주 전").foregroundStyle(.secondary).tag(Optional(10080))
                    Text("직접 입력").foregroundStyle(.secondary).tag(Optional(-1))
                }
                .pickerStyle(.menu)
                .tint(.secondary)
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

    }

    // MARK: - Private

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
