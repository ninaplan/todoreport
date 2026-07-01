import SwiftUI
import SwiftData
import MessageUI
import UserNotifications

// MARK: - 설정 뷰

struct SettingsView: View {
    let onAccountDeleted: () -> Void

    private var planners: [Planner] { PlannerService.shared.store }
    @State private var subscriptionManager = SubscriptionManager.shared
    private var isPro: Bool { subscriptionManager.isPro }

    @AppStorage("startWeekday") private var startWeekday = "월"
    @AppStorage(StreakCriteria.storageKey) private var streakCriteriaRaw = StreakCriteria.allCompleted.rawValue
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showAddPlannerSheet = false
    @State private var showPaywall = false
    @State private var activeMailSheet: SupportMailKind? = nil
    @State private var showFeedbackForm = false
    @State private var restoreAlertMessage: String?
    @State private var isRestoringSubscription = false
    @State private var settingsViewModel: SettingsViewModel
    @Environment(\.modelContext) private var modelContext

    init(onAccountDeleted: @escaping () -> Void = {}) {
        self.onAccountDeleted = onAccountDeleted
        _settingsViewModel = State(initialValue: SettingsViewModel(onAccountDeleted: onAccountDeleted))
    }

    var body: some View {
        @Bindable var vm = settingsViewModel
        List {
            subscriptionSection
            plannersSection
            globalSettingsSection
            supportSection
            appInfoSection
            Section {
                Button("구독 복원") {
                    Task { await restoreSubscription() }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.secondary)
                .disabled(isRestoringSubscription)
            }
            accountDeletionSection
            #if DEBUG
            DebugDeveloperOptionsSection()
            #endif
        }
        .navigationTitle("설정")
        .overlay {
            if vm.isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("삭제 중...")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .sheet(isPresented: $showAddPlannerSheet) {
            PlannerAddView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $activeMailSheet) { kind in
            SupportMailView(kind: kind)
        }
        .sheet(isPresented: $showFeedbackForm) {
            SafariView(url: URL(string: "https://paperlog.notion.site/1aea0117a683440ea5f1432e4842a9ba")!)
        }
        .alert("구독 복원", isPresented: Binding(
            get: { restoreAlertMessage != nil },
            set: { if !$0 { restoreAlertMessage = nil } }
        )) {
            Button("확인", role: .cancel) { restoreAlertMessage = nil }
        } message: {
            Text(restoreAlertMessage ?? "")
        }
        .alert("데이터 및 계정 삭제", isPresented: $vm.showDeleteAccountAlert) {
            Button("취소", role: .cancel) { settingsViewModel.cancelDeleteAccount() }
            Button("계속") { settingsViewModel.confirmDeleteAccountWarning() }
        } message: {
            Text("앱의 모든 투두·리포트·플래너·노션 연결 정보가 삭제됩니다. 노션에 저장된 페이지는 삭제되지 않습니다.")
        }
        .alert("정말 삭제할까요?", isPresented: $vm.showDeleteAccountFinalAlert) {
            Button("취소", role: .cancel) { settingsViewModel.cancelDeleteAccount() }
            Button("삭제하기", role: .destructive) {
                Task { await settingsViewModel.performDeleteAccount(context: modelContext) }
            }
        } message: {
            Text("이 작업은 되돌릴 수 없습니다.")
        }
        .alert("삭제 실패", isPresented: Binding(
            get: { vm.deleteAccountError != nil },
            set: { if !$0 { settingsViewModel.dismissDeleteAccountError() } }
        )) {
            Button("확인") { settingsViewModel.dismissDeleteAccountError() }
        } message: {
            Text(vm.deleteAccountError ?? "")
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationAuthStatus = settings.authorizationStatus
            await subscriptionManager.loadProducts()
        }
    }

    // MARK: - 구독

    private var subscriptionSection: some View {
        Section("구독") {
            Button {
                if isPro {
                    Task { await subscriptionManager.showManageSubscriptions() }
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(isPro ? AppTheme.shared.accent : Color(.tertiaryLabel))
                    if isPro {
                        Text("Pro 플랜")
                            .foregroundStyle(.primary)
                        Spacer()
                        if let expirationText = subscriptionManager.expirationDateText {
                            Text("\(expirationText) 만료")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Pro로 업그레이드하기")
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func restoreSubscription() async {
        isRestoringSubscription = true
        defer { isRestoringSubscription = false }
        do {
            try await subscriptionManager.restorePurchases()
            restoreAlertMessage = subscriptionManager.isPro
                ? "구독이 복원되었습니다."
                : "복원할 구독이 없습니다."
        } catch {
            AppLogger.shared.error("SettingsView", "restorePurchases 실패: \(error)")
            #if DEBUG
            restoreAlertMessage = "복원 실패: \(error.localizedDescription)"
            #else
            restoreAlertMessage = "복원 중 오류가 발생했어요. 다시 시도해 주세요."
            #endif
        }
    }

    // MARK: - 플래너

    private var plannersSection: some View {
        Section("플래너") {
            ForEach(planners) { planner in
                NavigationLink {
                    PlannerDetailView(planner: planner)
                } label: {
                    PlannerRow(planner: planner)
                }
                .disabled(planner.isReadOnly)
                .opacity(planner.isReadOnly ? 0.4 : 1.0)
            }
            Button {
                guard isPro else { showPaywall = true; return }
                showAddPlannerSheet = true
            } label: {
                HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(isPro ? AppTheme.shared.accent : .secondary)
                        Text("플래너 추가")
                            .foregroundStyle(isPro ? AppTheme.shared.accent : .secondary)
                        if !isPro { ProBadge() }
                    }
            }
        }
    }

    // MARK: - 환경 설정

    private var globalSettingsSection: some View {
        Section {
            Picker("시작 요일", selection: $startWeekday) {
                Text("일요일").tag("일")
                Text("월요일").tag("월")
            }
            .tint(.secondary)
            .onChange(of: startWeekday) { _, _ in
                ReportNotificationManager.shared.rescheduleAll()
            }

            Picker("연속 달성 기준", selection: $streakCriteriaRaw) {
                ForEach(StreakCriteria.allCases, id: \.rawValue) { criteria in
                    Text(criteria.displayName).tag(criteria.rawValue)
                }
            }
            .tint(.secondary)

            Picker("외관 모드", selection: $appColorScheme) {
                Text("시스템").tag("system")
                Text("라이트").tag("light")
                Text("다크").tag("dark")
            }
            .tint(.secondary)

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                LabeledContent("알림") {
                    HStack(spacing: 4) {
                        Text(notificationAuthStatus.displayText)
                            .foregroundStyle(notificationAuthStatus == .denied ? .red : .secondary)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        } header: {
            Text("환경 설정")
        } footer: {
            Text("리포트의 연속 달성은 어제까지 기준으로 계산됩니다.")
        }
    }

    // MARK: - 계정 삭제

    private var accountDeletionSection: some View {
        Section {
            Button(role: .destructive) {
                settingsViewModel.requestDeleteAccount()
            } label: {
                Text("데이터 및 계정 삭제")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } footer: {
            Text("투두, 리포트, 플래너, 노션 연결 정보가 모두 삭제됩니다. 노션에 저장된 페이지는 삭제되지 않으며 노션에서 직접 관리할 수 있습니다.")
        }
    }

    // MARK: - 고객지원

    private var supportSection: some View {
        Section("고객지원") {
            Link(destination: URL(string: "https://nock.kr/privacy")!) {
                LabeledContent("개인정보처리방침") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            Link(destination: URL(string: "https://nock.kr/terms")!) {
                LabeledContent("이용약관") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            Button {
                activeMailSheet = .errorReport
            } label: {
                LabeledContent("오류신고") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                showFeedbackForm = true
            } label: {
                LabeledContent("피드백 및 기능 제안") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .tint(.primary)
    }

    // MARK: - 앱 정보

    private var appInfoSection: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return Section("앱 정보") {
            NavigationLink {
                WhatsNewView()
            } label: {
                Text("업데이트 내역")
            }
            LabeledContent("버전") {
                Text(version).foregroundStyle(.secondary)
            }
            LabeledContent("빌드") {
                Text(build).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 플래너 행

private struct PlannerRow: View {
    let planner: Planner

    var body: some View {
        HStack(spacing: 10) {
            PlannerIconView(
                iconType: planner.iconType,
                iconImageData: planner.iconImageData,
                colorHex: planner.colorHex,
                size: 28
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(planner.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if planner.isReadOnly {
                    Text("Pro 구독 시 다시 활성화됩니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if planner.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if planner.isNotionConnected {
                NotionBadge()
            }
        }
    }
}

// MARK: - 노션 배지

struct NotionBadge: View {
    var body: some View {
        Image(systemName: "n.square.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black)
            .font(.system(size: 16, weight: .bold))
    }
}

// MARK: - 고객지원 메일 종류

enum SupportMailKind: Identifiable {
    case errorReport
    case feedback

    var id: Self { self }

    var subject: String {
        switch self {
        case .errorReport: return "투두리포트 오류 신고"
        case .feedback:    return "피드백 및 기능 제안"
        }
    }

    var bodyPrefix: String {
        switch self {
        case .errorReport:
            return "아래에 증상이나 재현 방법을 적어 주세요:\n\n\n"
        case .feedback:
            return "아래에 피드백이나 기능 제안 내용을 적어 주세요:\n\n\n"
        }
    }

    var includesLogs: Bool {
        switch self {
        case .errorReport: return true
        case .feedback:    return false
        }
    }
}

// MARK: - 오류 신고 / 피드백 메일

import UIKit

struct SupportMailView: UIViewControllerRepresentable {
    let kind: SupportMailKind
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients(["nockcreator@gmail.com"])
        mail.setSubject(kind.subject)

        let version  = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build    = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device   = UIDevice.current.model
        let os       = UIDevice.current.systemVersion
        let locale   = Locale.current.identifier
        let timezone = TimeZone.current.identifier

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let timestamp = formatter.string(from: Date())

        var body = kind.bodyPrefix +
                   "---\n" +
                   "Debug info:\n" +
                   "- 앱 버전: \(version) (\(build))\n" +
                   "- 기기: \(device), iOS \(os)\n" +
                   "- 로케일: \(locale)\n" +
                   "- 시간대: \(timezone)\n" +
                   "- 타임스탬프: \(timestamp)\n"

        if kind.includesLogs {
            let logContent: String
            if let url = AppLogger.shared.exportLogFileURL(),
               let content = try? String(contentsOf: url, encoding: .utf8) {
                logContent = content
            } else {
                logContent = "(로그 없음)"
            }
            body += "\n---\n로그:\n\(logContent)"
        }

        mail.setMessageBody(body, isHTML: false)
        return mail
    }

    func updateUIViewController(_ uvc: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            dismiss()
        }
    }
}

// MARK: - UNAuthorizationStatus 표시 텍스트

private extension UNAuthorizationStatus {
    var displayText: String {
        switch self {
        case .authorized, .provisional, .ephemeral: return "허용됨"
        case .denied:                                return "거부됨"
        default:                                     return "설정 안 됨"
        }
    }
}
