import SwiftUI
import MessageUI

// MARK: - 설정 뷰

struct SettingsView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    private var planners: [Planner] { PlannerService.shared.store }
    private var isPro: Bool { SubscriptionManager.shared.isPro }

    @State private var language = "한국어"
    @AppStorage("startWeekday") private var startWeekday = "월"
    @State private var notificationEnabled = true
    @State private var showLogoutAlert = false
    @State private var showAddPlannerSheet = false
    @State private var showPaywall = false
    @State private var showSupportMail: Bool = false

    #if DEBUG
    @AppStorage("debugIsPro") private var debugIsPro = false
    @State private var showClearQueueConfirm = false
    @State private var clearQueueResultMessage = ""
    @State private var showClearQueueResult = false
    #endif

    var body: some View {
        List {
            subscriptionSection
            plannersSection
            globalSettingsSection
            supportSection
            appInfoSection
            accountFooterSection

            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("설정")
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("로그아웃", role: .destructive) {
                NotionAuthManager.shared.signOut()
                onboardingCompleted = false
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("로그아웃하시겠어요?")
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
        .sheet(isPresented: $showSupportMail) {
            SupportMailView()
        }
    }

    // MARK: - 구독

    private var subscriptionSection: some View {
        Section("구독") {
            LabeledContent("현재 플랜") {
                Text(isPro ? "Pro" : "무료")
                    .foregroundStyle(.secondary)
            }
            if !isPro {
                Button("Pro로 업그레이드") {
                    showPaywall = true
                }
                .foregroundStyle(AppTheme.shared.accent)
            }
            Button("구독 복원") {
                Task { try? await SubscriptionManager.shared.restorePurchases() }
            }
            .foregroundStyle(.secondary)
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
                        ProBadge()
                    }
            }
        }
    }

    // MARK: - 환경 설정

    private var globalSettingsSection: some View {
        Section("환경 설정") {
            Picker("언어", selection: $language) {
                Text("한국어").tag("한국어")
                Text("English").tag("English")
            }
            .tint(.primary)
            Picker("시작 요일", selection: $startWeekday) {
                Text("일요일").tag("일")
                Text("월요일").tag("월")
            }
            .tint(.primary)
            Toggle("알림", isOn: $notificationEnabled)
                .tint(AppTheme.shared.accent)
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
                showSupportMail = true
            } label: {
                LabeledContent("오류신고") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .foregroundStyle(.primary)
            Link(destination: URL(string: "https://nock.kr/updates")!) {
                LabeledContent("업데이트 타임라인") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
        }
        .tint(.primary)
    }

    // MARK: - 앱 정보

    private var appInfoSection: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return Section("앱 정보") {
            LabeledContent("버전") {
                Text(version).foregroundStyle(.secondary)
            }
            LabeledContent("빌드") {
                Text(build).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 계정 푸터

    private var accountFooterSection: some View {
        Section {
            VStack(spacing: 14) {
                Button("로그아웃") {
                    showLogoutAlert = true
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - 개발용

    #if DEBUG
    private var debugSection: some View {
        Section("개발자 도구") {
            Toggle("Pro 모드", isOn: $debugIsPro)
                .tint(AppTheme.shared.accent)
                .onChange(of: debugIsPro) { oldValue, _ in
                    SubscriptionManager.shared.refreshIsProDebug(previousValue: oldValue)
                }
            Button("SyncQueue 비우기") {
                showClearQueueConfirm = true
            }
            .foregroundStyle(.red)
            Button("로그 파일 초기화", role: .destructive) {
                print("[DEBUG] clearLogs 호출")
                AppLogger.shared.resetWithHeader()
                print("[DEBUG] clearLogs 완료")
            }
            Button("온보딩 초기화", role: .destructive) {
                NotionAuthManager.shared.signOut()
                onboardingCompleted = false
            }
        }
        .alert("SyncQueue 비우기", isPresented: $showClearQueueConfirm) {
            Button("비우기", role: .destructive) {
                let count = SyncQueueManager.shared.clearAllReturningCount()
                clearQueueResultMessage = count > 0 ? "\(count)개 항목이 삭제됐습니다." : "삭제할 항목이 없습니다."
                showClearQueueResult = true
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("대기 중인 Notion 동기화 작업을 모두 삭제합니다.")
        }
        .alert("완료", isPresented: $showClearQueueResult) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(clearQueueResultMessage)
        }
    }
    #endif
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

// MARK: - 오류 신고 메일

import UIKit

struct SupportMailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients(["nockcreator@gmail.com"])
        mail.setSubject("투두리포트 오류 신고")

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

        let logContent: String
        if let url = AppLogger.shared.exportLogFileURL(),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            logContent = content
        } else {
            logContent = "(로그 없음)"
        }

        let body = "아래에 증상이나 재현 방법을 적어 주세요:\n\n\n" +
                   "---\n" +
                   "Debug info:\n" +
                   "- 앱 버전: \(version) (\(build))\n" +
                   "- 기기: \(device), iOS \(os)\n" +
                   "- 로케일: \(locale)\n" +
                   "- 시간대: \(timezone)\n" +
                   "- 타임스탬프: \(timestamp)\n\n" +
                   "---\n" +
                   "로그:\n" +
                   logContent

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
