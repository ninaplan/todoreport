import SwiftUI

// MARK: - 설정 뷰

struct SettingsView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    private let isNotionConnected = false
    private let notionAccountEmail = "nina@notion.so"
    private var planners: [Planner] { PlannerService.shared.store }
    #if DEBUG
    private let isPro = true
    #else
    private let isPro = false
    #endif
    private let appleIdEmail = "user@icloud.com"

    @State private var language = "한국어"
    @State private var startWeekday = "월"
    @State private var notificationEnabled = true
    @State private var showLogoutAlert = false

    var body: some View {
        List {
            notionSection
            plannersSection
            globalSettingsSection
            subscriptionSection
            accountFooterSection

            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("설정")
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("로그아웃", role: .destructive) { onboardingCompleted = false }
            Button("취소", role: .cancel) { }
        } message: {
            Text("로그아웃하시겠어요?")
        }
    }

    // MARK: - 노션 연결

    private var notionSection: some View {
        Section("노션 연결") {
            NavigationLink {
                NotionConnectionView(isConnected: isNotionConnected)
            } label: {
                HStack {
                    Text("노션 연결")
                    Spacer()
                    if isNotionConnected {
                        Text(notionAccountEmail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
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
            }
            Button {
                // TODO: Pro 게이트 → Paywall 표시
            } label: {
                Label(isPro ? "플래너 추가" : "플래너 추가  🔒", systemImage: "plus")
                    .foregroundStyle(isPro ? Color.nockOrange : .secondary)
            }
        }
    }

    // MARK: - 전역 설정

    private var globalSettingsSection: some View {
        Section("전역 설정") {
            Picker("언어", selection: $language) {
                Text("한국어").tag("한국어")
                Text("English").tag("English")
            }
            Picker("시작 요일", selection: $startWeekday) {
                Text("일요일").tag("일")
                Text("월요일").tag("월")
            }
            Toggle("알림", isOn: $notificationEnabled)
                .tint(Color.nockOrange)
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
                    // TODO: Paywall
                }
                .foregroundStyle(Color.nockOrange)
            }
        }
    }

    // MARK: - 계정 푸터

    private var accountFooterSection: some View {
        Section {
            VStack(spacing: 14) {
                Text(appleIdEmail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
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
            Button("온보딩 초기화", role: .destructive) {
                onboardingCompleted = false
            }
        }
    }
    #endif
}

// MARK: - 플래너 행

private struct PlannerRow: View {
    let planner: Planner

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: planner.colorHex))
                .frame(width: 10, height: 10)
            Text(planner.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if planner.isNotionConnected {
                NotionBadge()
            }
        }
    }
}

// MARK: - 노션 배지

struct NotionBadge: View {
    var body: some View {
        Text("N")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Color(.label), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}
