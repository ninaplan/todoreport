import SwiftUI

struct RecurrenceSettingsSection: View {
    @Binding var recurrenceRule: RecurrenceRule?
    @Binding var recurrenceEndDate: Date?
    @Binding var recurrenceCount: Int?
    @Binding var date: Date?
    var scrollToAnchor: ((String) -> Void)? = nil

    @State private var showPaywall = false
    @State private var showEndDatePicker = false
    private var isPro: Bool { SubscriptionManager.shared.isPro }
    private var localizedCalendar: Calendar { AppCalendar.localized }

    private static let endDatePickerAnchor = "todoEditEndDatePicker"

    private static let kindOrder: [RecurrenceKind] = [
        .none, .daily, .weekly, .biweekly, .monthly, .weekdays, .weekends, .yearly
    ]

    private enum EndKind: Hashable {
        case never
        case onDate
        case afterCount
    }

    var body: some View {
        Section {
            Picker(selection: kindBinding) {
                ForEach(Self.kindOrder, id: \.self) { kind in
                    Text(title(for: kind)).tag(kind)
                }
            } label: {
                HStack(spacing: 6) {
                    Text("반복")
                    if !isPro { ProBadge() }
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
            .simultaneousGesture(TapGesture().onEnded { resignKeyboard() })

            if selectedKind.needsWeekdaySelection {
                weekdayPicker
            }

            if let caption = patternCaption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if recurrenceRule != nil {
                Picker("종료", selection: endKindBinding) {
                    Text("없음").tag(EndKind.never)
                    Text("날짜까지").tag(EndKind.onDate)
                    Text("횟수까지").tag(EndKind.afterCount)
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .simultaneousGesture(TapGesture().onEnded { resignKeyboard() })

                if selectedEndKind == .onDate {
                    Button {
                        resignKeyboard()
                        withAnimation { showEndDatePicker.toggle() }
                    } label: {
                        HStack {
                            Text("종료일").foregroundStyle(.primary)
                            Spacer()
                            Text(endDateBinding.wrappedValue.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6), in: Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showEndDatePicker {
                        DatePicker(
                            "",
                            selection: endDateBinding,
                            in: endDateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(AppTheme.shared.accent)
                        .environment(\.calendar, localizedCalendar)
                        .id(Self.endDatePickerAnchor)
                    }
                }

                if selectedEndKind == .afterCount {
                    Stepper(value: countBinding, in: 1...999) {
                        Text("\(countBinding.wrappedValue)번")
                    }
                }
            }
        }
        .onChange(of: showEndDatePicker) { _, shown in
            guard shown else { return }
            scrollToAnchor?(Self.endDatePickerAnchor)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(message: String(localized: "반복 할 일은 Pro 기능입니다."))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Kind

    private var selectedKind: RecurrenceKind {
        recurrenceRule?.kind ?? .none
    }

    private var kindBinding: Binding<RecurrenceKind> {
        Binding(
            get: { selectedKind },
            set: { applyKind($0) }
        )
    }

    private func applyKind(_ kind: RecurrenceKind) {
        if kind == .none {
            recurrenceRule = nil
            recurrenceEndDate = nil
            recurrenceCount = nil
            showEndDatePicker = false
            return
        }
        guard isPro else { showPaywall = true; return }
        if date == nil {
            date = Calendar.current.startOfDay(for: .now)
        }
        let fallback = weekdayIndex(for: date ?? .now)
        let existing = recurrenceRule?.weekdayIndices ?? []
        let weekdays = existing.isEmpty ? [fallback] : existing
        recurrenceRule = kind.toRule(weekdays: weekdays)
    }

    private func title(for kind: RecurrenceKind) -> String {
        switch kind {
        case .none: return String(localized: "반복 안함")
        case .daily: return String(localized: "매일")
        case .weekdays: return String(localized: "평일만")
        case .weekends: return String(localized: "주말만")
        case .weekly: return String(localized: "매주")
        case .biweekly: return String(localized: "격주")
        case .monthly: return String(localized: "매월")
        case .yearly: return String(localized: "매년")
        }
    }

    private var patternCaption: String? {
        guard let date else { return nil }
        let cal = Calendar.current
        switch selectedKind {
        case .monthly:
            let day = cal.component(.day, from: date)
            return String(localized: "매월 \(day)일에 반복됩니다.")
        case .yearly:
            let month = cal.component(.month, from: date)
            let day = cal.component(.day, from: date)
            return String(localized: "매년 \(month)월 \(day)일에 반복됩니다.")
        default:
            return nil
        }
    }

    // MARK: - Weekdays

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("요일")
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                ForEach(weekdaysInDisplayOrder, id: \.self) { index in
                    weekdayButton(index)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "요일"))
    }

    private var weekdaysInDisplayOrder: [Int] {
        let first = localizedCalendar.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 }
    }

    private var selectedWeekdays: Set<Int> {
        Set(recurrenceRule?.weekdayIndices ?? [])
    }

    private func weekdayButton(_ index: Int) -> some View {
        let selected = selectedWeekdays.contains(index)
        return Button {
            toggleWeekday(index)
        } label: {
            Text(weekdayShortName(index))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selected ? AppTheme.shared.accent : Color(.systemGray6),
                    in: Circle()
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekdayShortName(index))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func toggleWeekday(_ index: Int) {
        var days = selectedWeekdays
        if days.contains(index) {
            guard days.count > 1 else { return }
            days.remove(index)
        } else {
            days.insert(index)
        }
        let sorted = days.sorted()
        switch selectedKind {
        case .weekly:
            recurrenceRule = .weekly(sorted)
        case .biweekly:
            recurrenceRule = .biweekly(sorted)
        default:
            break
        }
    }

    private func weekdayShortName(_ index: Int) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        guard index >= 0, index < names.count else { return "" }
        return String(localized: String.LocalizationValue(names[index]))
    }

    private func weekdayIndex(for date: Date) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    // MARK: - End condition

    private var selectedEndKind: EndKind {
        if recurrenceEndDate != nil { return .onDate }
        if recurrenceCount != nil { return .afterCount }
        return .never
    }

    private var endKindBinding: Binding<EndKind> {
        Binding(
            get: { selectedEndKind },
            set: { applyEndKind($0) }
        )
    }

    private func applyEndKind(_ kind: EndKind) {
        switch kind {
        case .never:
            recurrenceEndDate = nil
            recurrenceCount = nil
            showEndDatePicker = false
        case .onDate:
            recurrenceCount = nil
            if recurrenceEndDate == nil {
                recurrenceEndDate = Calendar.current.startOfDay(for: date ?? .now)
            }
        case .afterCount:
            recurrenceEndDate = nil
            recurrenceCount = recurrenceCount ?? 10
            showEndDatePicker = false
        }
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { recurrenceEndDate ?? Calendar.current.startOfDay(for: date ?? .now) },
            set: { recurrenceEndDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var endDateRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: date ?? .now)
        return start...Date.distantFuture
    }

    private var countBinding: Binding<Int> {
        Binding(
            get: { recurrenceCount ?? 10 },
            set: { recurrenceCount = $0 }
        )
    }

    // MARK: - Keyboard

    private func resignKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
