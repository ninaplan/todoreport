import SwiftUI
import UserNotifications

struct NotionSaveEditorView: View {
    let reportPeriod: ReportPeriod
    let periodTitle: String
    let period: DateInterval
    let completionRate: Double
    let avgRating: Double
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var comment: String = ""
    @State private var notificationTime: Date = Self.defaultNotificationTime()
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showNotificationDeniedAlert = false

    @AppStorage(ReportNotificationSettings.weeklyEnabledKey)
    private var weeklyNotificationEnabled = false
    @AppStorage(ReportNotificationSettings.monthlyEnabledKey)
    private var monthlyNotificationEnabled = false
    @AppStorage(ReportNotificationSettings.hourKey)
    private var notificationHour = 20
    @AppStorage(ReportNotificationSettings.minuteKey)
    private var notificationMinute = 0
    @AppStorage(ReportNotificationSettings.weeklyWeekdayKey)
    private var weeklyNotificationWeekday = 2
    @AppStorage(ReportNotificationSettings.monthlyTimingKey)
    private var monthlyNotificationTimingRaw = MonthlyReportNotificationTiming.firstDay.rawValue

    @Environment(\.dismiss) private var dismiss

    private var reviewSectionTitle: String {
        reportPeriod == .weekly ? "주간 리뷰" : "월간 리뷰"
    }

    private var reviewPlaceholder: String {
        reportPeriod == .weekly
            ? "이번 주를 돌아보며 적어보세요"
            : "이번 달을 돌아보며 적어보세요"
    }

    private var notificationEnabledBinding: Binding<Bool> {
        switch reportPeriod {
        case .weekly:
            return $weeklyNotificationEnabled
        case .monthly:
            return $monthlyNotificationEnabled
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsSection
                    commentSection
                    notificationSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("노션에 저장하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        onCancel()
                        dismiss()
                    }
                    .toolbarSecondaryActionStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        onConfirm(comment)
                        dismiss()
                    }
                    .toolbarPrimaryActionStyle()
                }
            }
            .task {
                if UserDefaults.standard.object(forKey: ReportNotificationSettings.weeklyWeekdayKey) == nil {
                    weeklyNotificationWeekday = ReportNotificationSettings.weeklyWeekday
                }
                notificationTime = Self.date(fromHour: notificationHour, minute: notificationMinute)
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                notificationAuthStatus = settings.authorizationStatus
            }
            .onChange(of: notificationTime) { _, newValue in
                applyNotificationTime(newValue)
            }
            .onChange(of: weeklyNotificationEnabled) { _, enabled in
                guard reportPeriod == .weekly else { return }
                handleNotificationToggle(enabled)
            }
            .onChange(of: monthlyNotificationEnabled) { _, enabled in
                guard reportPeriod == .monthly else { return }
                handleNotificationToggle(enabled)
            }
            .onChange(of: weeklyNotificationWeekday) { _, _ in
                guard reportPeriod == .weekly, weeklyNotificationEnabled else { return }
                ReportNotificationManager.shared.rescheduleAll()
            }
            .onChange(of: monthlyNotificationTimingRaw) { _, _ in
                guard reportPeriod == .monthly, monthlyNotificationEnabled else { return }
                ReportNotificationManager.shared.rescheduleAll()
            }
            .alert("알림 권한 필요", isPresented: $showNotificationDeniedAlert) {
                Button("설정 열기") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("기기 설정에서 투두리포트 알림을 허용해야 저장 알림을 받을 수 있습니다.")
            }
        }
    }

    // MARK: - 기간 통계

    private var statsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(periodTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 0) {
                statItem(
                    value: "\(Int(completionRate * 100))%",
                    label: "평균 완료율",
                    color: AppTheme.shared.accent
                )
                Divider().frame(height: 40)
                statItem(
                    value: ratingLabel,
                    label: "별점 평균",
                    color: .primary
                )
            }
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ratingLabel: String {
        guard avgRating > 0 else { return "—" }
        return String(format: "%.1f", avgRating)
    }

    // MARK: - 리뷰 입력

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reviewSectionTitle)
                .font(.subheadline.bold())

            ZStack(alignment: .topLeading) {
                TextEditor(text: $comment)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)

                if comment.isEmpty {
                    Text(reviewPlaceholder)
                        .font(.subheadline)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - 저장 알림

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("저장 알림")
                .font(.subheadline.bold())

            VStack(spacing: 0) {
                Toggle("알림 켜기", isOn: notificationEnabledBinding)
                    .tint(AppTheme.shared.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if notificationEnabledBinding.wrappedValue {
                    Divider()
                        .padding(.leading, 16)

                    HStack {
                        Text("알림 시간")
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)

                        HStack(spacing: 4) {
                            if reportPeriod == .weekly {
                                Picker("요일", selection: $weeklyNotificationWeekday) {
                                    ForEach(ReportNotificationSettings.weekdayShortLabels, id: \.value) { option in
                                        Text(option.label).tag(option.value)
                                    }
                                }
                                .labelsHidden()
                                .tint(.secondary)
                            } else {
                                Picker("날짜", selection: $monthlyNotificationTimingRaw) {
                                    ForEach(MonthlyReportNotificationTiming.allCases, id: \.rawValue) { timing in
                                        Text(timing.displayName).tag(timing.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .tint(.secondary)
                            }

                            DatePicker(
                                "시간",
                                selection: $notificationTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .tint(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("기기 설정에서 투두리포트 알림이 허용되어 있어야 합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if notificationAuthStatus == .denied {
                    Text("현재 알림: 거부됨")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(notificationFooterGuide)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notificationFooterGuide: String {
        switch reportPeriod {
        case .weekly:
            return "매주 선택한 요일·시간에 지난 주 리포트 저장을 알려드립니다."
        case .monthly:
            let timing = MonthlyReportNotificationTiming(rawValue: monthlyNotificationTimingRaw) ?? .firstDay
            switch timing {
            case .firstDay:
                return "매월 1일 선택한 시간에 지난 달 리포트 저장을 알려드립니다."
            case .lastDay:
                return "매월 말일 선택한 시간에 이번 달 리포트 저장을 알려드립니다."
            }
        }
    }

    // MARK: - Helpers

    private func handleNotificationToggle(_ enabled: Bool) {
        guard enabled else {
            ReportNotificationManager.shared.rescheduleAll()
            return
        }
        Task {
            let granted = await ReportNotificationManager.shared.ensureAuthorization()
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                notificationAuthStatus = settings.authorizationStatus
                if granted {
                    ReportNotificationManager.shared.rescheduleAll()
                } else {
                    ReportNotificationSettings.setEnabled(false, for: reportPeriod)
                    showNotificationDeniedAlert = true
                }
            }
        }
    }

    private func applyNotificationTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        notificationHour = components.hour ?? 20
        notificationMinute = components.minute ?? 0
        if ReportNotificationSettings.isEnabled(for: reportPeriod) {
            ReportNotificationManager.shared.rescheduleAll()
        }
    }

    private static func defaultNotificationTime() -> Date {
        date(fromHour: 20, minute: 0)
    }

    private static func date(fromHour hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }
}
