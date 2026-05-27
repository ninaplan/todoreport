import SwiftUI

struct SettingsView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showLogoutAlert = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        List {
            plannerSection
            appSettingsSection
            categorySection
            subscriptionSection
            accountSection
            infoSection

            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("설정")
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("로그아웃", role: .destructive) { }
            Button("취소", role: .cancel) { }
        } message: {
            Text("로그아웃하시겠어요?")
        }
    }

    // MARK: - 내 플래너

    private var plannerSection: some View {
        Section("내 플래너") {
            LabeledContent("플래너 이름") {
                Text("내 플래너")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("투두DB") {
                Text("할일 목록")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("데일리리포트DB") {
                Text("데일리리포트")
                    .foregroundStyle(.secondary)
            }
            Button {
                // TODO: 유료 게이트 → Paywall 표시
            } label: {
                Label("플래너 추가하기 🔒", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 앱 설정

    private var appSettingsSection: some View {
        Section("앱 설정") {
            LabeledContent("언어") {
                Text("한국어")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("시작 요일") {
                Text("월요일")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("주간 리포트 알림") {
                Text("일 밤 10시")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 카테고리 관리

    private var categorySection: some View {
        Section {
            NavigationLink {
                CategoryView()
            } label: {
                Text("카테고리 관리")
            }
        }
    }

    // MARK: - 구독

    private var subscriptionSection: some View {
        Section("구독") {
            LabeledContent("현재 플랜") {
                Text("무료")
                    .foregroundStyle(.secondary)
            }
            Button("구독 관리") {
                // TODO: StoreKit 2 구독 관리 시트
            }
            Button("구매 복원") {
                // TODO: StoreKit 2 restore purchases
            }
        }
    }

    // MARK: - 계정

    private var accountSection: some View {
        Section("계정") {
            LabeledContent("Apple ID") {
                Text("user@icloud.com")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("노션 연결") {
                Text("미연결")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("기기에만 저장됩니다. 기기 변경 시 데이터를 불러올 수 없어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.orange.opacity(0.08))
            Button("로그아웃", role: .destructive) {
                showLogoutAlert = true
            }
        }
    }

    // MARK: - 정보

    private var infoSection: some View {
        Section("정보") {
            LabeledContent("버전") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            Button("개인정보처리방침") {
                // TODO: nock.kr/privacy 링크 연결
            }
            Button("이용약관") {
                // TODO: nock.kr/terms 링크 연결
            }
        }
    }

    // MARK: - 개발용 (DEBUG 빌드 전용)

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
