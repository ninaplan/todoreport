# 투두리포트 (TodoReport) — Claude Code 컨텍스트

## 프로젝트 개요
- **브랜드:** 노크(Nock / nock.kr)
- **앱명:** 투두리포트
- **플랫폼:** iOS 네이티브 (iOS 26+)
- **포인트 컬러:** `#FD6845`
- **핵심 철학:** "앱에서 기록하고, 노션에 쌓아가세요"
- **역할 분리:** iOS 앱 = UI/로컬 상태, Next.js 백엔드 = Notion API 처리

---

## 기술 스택

### iOS 앱
- **언어:** Swift
- **UI:** SwiftUI (Liquid Glass, iOS 26 디자인 언어)
- **아키텍처:** MVVM
- **로컬 저장소:** SwiftData
- **네트워크:** URLSession (Core/Network/APIClient.swift 단일 창구)
- **인증:** Notion OAuth (ASWebAuthenticationSession)
- **결제:** StoreKit 2 (Apple IAP)
- **폰트:** Nanum Square Round

### 백엔드 (별도 레포)
- Next.js 14 App Router + Vercel
- Notion API 서버사이드 전용 호출

---

## 절대 원칙 (위반 금지)

1. **Notion API는 iOS 앱에서 직접 호출하지 않는다**
   → 반드시 Next.js 백엔드 APIClient 경유
2. **외부 API 호출은 캐싱 레이어 경유**
   → CacheManager.swift 사용
3. **모든 쓰기는 SwiftData 먼저 (Offline-First)**
   → SwiftData 저장 → 화면 업데이트 → SyncQueue → 백그라운드 Notion 전송
   → 앱 닫혀도 큐는 SwiftData에 유지, 재실행 시 자동 처리
4. **Force unwrapping 금지** (`!` 사용 금지)
   → Optional binding 또는 guard let 사용
5. **@ObservableObject 사용 금지**
   → iOS 26 기준 @Observable macro 사용
6. **View에서 ViewModel 프로퍼티 직접 수정 금지**
   → 모든 상태 변경은 ViewModel 메서드를 통할 것
   → 예) `viewModel.isPresented = false` ❌ → `viewModel.dismiss()` ✅
7. **alert 상태 프로퍼티는 cancel/confirm 메서드 쌍으로 구현**
   → `showXxxAlert`, `xxxItem` 프로퍼티가 있으면 반드시 `cancelXxx()` / `confirmXxx()` 메서드도 함께 정의
   → View에서 alert 상태 프로퍼티 직접 수정 금지

---

## 프로젝트 구조

```
TodoReport/
├── Core/                          # 기반 레이어 (신중하게 수정)
│   ├── Network/
│   │   └── APIClient.swift        # 백엔드 호출 단일 창구
│   ├── Auth/
│   │   └── NotionAuth.swift       # OAuth 처리
│   ├── Repository/
│   │   ├── DataRepository.swift   # protocol 정의
│   │   ├── NotionRepository.swift # 노션 사용자
│   │   ├── LocalRepository.swift  # 로컬 모드 (SwiftData)
│   │   └── RepositoryFactory.swift
│   ├── Sync/
│   │   ├── SyncQueue.swift        # 미처리 작업 대기열 (SwiftData)
│   │   └── SyncManager.swift      # 큐 처리 / 재시도 / 상태 관리
│   └── Cache/
│       └── CacheManager.swift     # SwiftData + TTL 캐싱
│
├── Features/                      # 기능별 완전 독립 모듈
│   ├── Todo/                      # 투두 (무료)
│   ├── QuickCapture/              # 빠른 캡처 플로팅 시트 (무료)
│   ├── DailyReport/               # 데일리 리포트 (무료)
│   ├── WeeklyReport/              # 주간 리포트 (유료)
│   ├── MonthlyReport/             # 월간 리포트 (유료)
│   ├── Planner/                   # 멀티 플래너 (유료)
│   ├── RecurringTodo/             # 반복 투두 (유료)
│   └── Category/                  # 카테고리 관리 (무료, 앱 전용)
│
├── Widget/                        # 홈 화면 위젯 (별도 Extension Target)
│   ├── TodoWidgetBundle.swift     # 진입점
│   ├── SmallWidget.swift          # 완료율 + ＋ 버튼
│   ├── MediumWidget.swift         # 투두 목록 + 체크박스
│   ├── LargeWidget.swift          # 전체 목록
│   └── WidgetDataProvider.swift   # App Group으로 앱과 데이터 공유
│
├── Shared/                        # 공통 UI
│   ├── Components/
│   │   ├── NockButton.swift
│   │   ├── NockCard.swift
│   │   └── NockTextField.swift
│   └── Theme/
│       ├── Colors.swift           # Color.nockOrange = #FD6845
│       └── Typography.swift
│
└── App/
    └── TodoReportApp.swift
```

---

## 각 Feature 모듈 구조 패턴

모든 Feature는 아래 3파일 패턴을 따른다:

```
FeatureName/
├── FeatureNameView.swift       # SwiftUI View (UI만)
├── FeatureNameViewModel.swift  # @Observable, 상태 관리
└── FeatureNameService.swift    # APIClient 호출, 데이터 처리
```

**예시 (Todo):**
```swift
// TodoViewModel.swift
@Observable
final class TodoViewModel {
    var todos: [Todo] = []
    var isLoading = false

    private let service = TodoService()

    func fetchTodos(for date: Date) async {
        isLoading = true
        defer { isLoading = false }
        todos = await service.fetchTodos(for: date)
    }
}
```

---

## 데이터 모델

### Todo
```swift
struct Todo: Identifiable, Codable {
    let id: String
    var title: String
    var memo: String?              // 투두 메모 (Notion 페이지 텍스트 블록)
    var isCompleted: Bool
    var date: Date
    var categoryId: String?
    var notionPageId: String
}
```

### DailyReport
```swift
struct DailyReport: Identifiable, Codable {
    let id: String
    let date: Date
    var review: String             // 하루 리뷰
    var completionRate: Double     // 로컬 계산값
    var dayRating: DayRating?      // 별점
    var photoURLs: [String]        // v2 대비 (항상 [] 반환)
    var notionPageId: String
}

enum DayRating: String, CaseIterable, Codable {
    case one   = "⭐"
    case two   = "⭐⭐"
    case three = "⭐⭐⭐"
    case four  = "⭐⭐⭐⭐"
    case five  = "⭐⭐⭐⭐⭐"
}
```

---

## 데이터 레이어 — Repository 패턴

ViewModel은 저장 위치를 몰라도 된다. DataRepository 프로토콜만 바라본다.

```swift
// protocol 정의
protocol DataRepository {
    func fetchTodos(for date: Date) async throws -> [Todo]
    func saveTodo(_ todo: Todo) async throws
    func fetchDailyReport(for date: Date) async throws -> DailyReport?
    func saveDailyReport(_ report: DailyReport) async throws
}

// 노션 연결 사용자
final class NotionRepository: DataRepository { ... }

// 로컬 모드 사용자 (SwiftData)
final class LocalRepository: DataRepository { ... }
```

**ViewModel에서 사용:**
```swift
@Observable
final class TodoViewModel {
    private let repository: DataRepository  // 어떤 구현인지 모름

    init(repository: DataRepository = RepositoryFactory.current) {
        self.repository = repository
    }
}
```

**Repository 전환:**
```swift
// RepositoryFactory.swift
final class RepositoryFactory {
    static var current: DataRepository {
        UserDefaults.standard.bool(forKey: "notionConnected")
            ? NotionRepository()
            : LocalRepository()
    }
}
```

---

## 계정 구조

| 사용자 유형 | 로그인 | 데이터 저장 |
|---|---|---|
| 노션 사용자 | Sign in with Apple + Notion OAuth | Notion DB |
| 로컬 사용자 | Sign in with Apple | SwiftData (기기) |

> Sign in with Apple은 모든 사용자 필수.
> Apple IAP 구독이 Apple ID에 묶임 → 기기 변경 후 구독 복원 가능.

---



```swift
// Core/Network/APIClient.swift 의 단일 창구만 사용
// 직접 URLSession 호출 금지

let todos = try await APIClient.shared.get("/api/notion/todo", params: ["date": date])
let _ = try await APIClient.shared.patch("/api/notion/todo/\(id)", body: ["완료": true])
```

---

## SyncQueue 사용 패턴 (Offline-First)

```swift
// 모든 쓰기는 이 패턴을 따른다

// ❌ 금지: Notion 응답 기다리며 화면 블로킹
let result = try await notionAPI.createTodo(todo)
todos.append(result)

// ✅ 올바른 방법: 로컬 먼저, 백그라운드 동기화
// 1. SwiftData 즉시 저장
context.insert(todo)
try context.save()

// 2. UI 즉시 업데이트
todos.append(todo)

// 3. SyncQueue 백그라운드 처리
SyncManager.shared.enqueue(.createTodo(todo))
// → 인터넷 있으면 즉시 전송 시도
// → 없거나 실패하면 SwiftData 큐에 보관
// → 앱 재실행 or 인터넷 연결 시 자동 재처리
```

---

## 유료 기능 게이팅 패턴

```swift
// 유료 기능 진입 전 항상 체크
guard SubscriptionManager.shared.isPro else {
    // 구독 유도 화면 표시
    showProPaywall = true
    return
}
```

**유료 기능 목록:**
- 다른 날 투두 확인 (날짜 이동)
- 주간 리포트
- 월간 리포트
- 멀티 플래너 (2개 이상)
- 반복 투두

---

## 네비게이션 바 구조

```
투두 탭:
좌측: 플래너 이름 ▼ (탭 → 플래너 전환)
우측: ☰ (탭 → 슬라이드 다운 보기 옵션)

보기 옵션 (슬라이드 다운):
- ✓ 완료 숨기기 (토글)
- ✓ 카테고리별로 보기 (토글)
- 정렬 옵션 › (하위 뷰)
```

---

## 날짜 이동 (투두 탭)

```
날짜 좌측 공간 탭 → 이전 날 (유료)
날짜 우측 공간 탭 → 다음 날 (유료)
날짜 텍스트 탭    → 달력 피커 (유료)
화면 스와이프     → 금지 (투두 아이템 스와이프와 충돌)
```

---

## 투두 아이템 제스처

```
탭           → 완료/미완료 토글
좌로 스와이프 → [내일하기] [날짜변경] [삭제]
길게 누르기   → 편집 모드
```

---

## 완료율 계산 원칙

```
// 로컬에서 즉시 계산 (Notion 응답 기다리지 않음)
var completionRate: Double {
    guard !todos.isEmpty else { return 0 }
    return Double(todos.filter(\.isCompleted).count) / Double(todos.count)
}
// 이후 백그라운드에서 Notion 비동기 저장
```

---

## Notion 속성 매핑

속성명 변경 시 이 목록만 수정 (iOS 코드 변경 불필요):

| 앱 내부 키 | Notion 속성명 |
|---|---|
| review | 하루 리뷰 |
| dayRating | 별점 |
| photoURLs | 사진URL (v2) |
| completionRateApp | 완료율_앱 |

> Notion 속성명은 언어 설정과 무관하게 한국어 고정.
> (속성명 변경 시 기존 사용자 데이터 연결 끊김)

---

## 코딩 컨벤션

- **접근 제어:** 모든 프로퍼티/메서드에 명시 (private, internal, public)
- **비동기:** async/await 사용 (completion handler 금지)
- **에러 처리:** throws + do-catch (fatalError 금지)
- **주석:** 복잡한 로직에만 한국어 주석
- **파일당 타입:** 1파일 1타입 원칙
- **MVVM:** View에 비즈니스 로직 작성 금지 → ViewModel로 이동

---

## 자주 실수하는 것들

```swift
// ❌ 금지
@StateObject var viewModel = TodoViewModel()  // ObservableObject 구 방식
let result = try! service.fetch()             // Force try
let value = optional!                         // Force unwrap

// ✅ 올바른 방법
@State var viewModel = TodoViewModel()        // @Observable 새 방식
guard let result = try? service.fetch() else { return }
guard let value = optional else { return }
```

---

## 개발 우선순위 (MVP)

```
Phase 1 (핵심 기반)
  - Sign in with Apple + Notion OAuth 연동
  - APIClient + Repository 패턴 구현
  - 온보딩 플로우 (로컬/노션 선택)

Phase 2 (무료 핵심 기능)
  - 투두 기록 → Notion 저장
  - 빠른 캡처 (플로팅 ＋ 버튼)
  - 투두 메모
  - 데일리 리포트 (완료율 + 별점 + 리뷰)
  - 카테고리 관리

Phase 3 (위젯)
  - WidgetKit Extension 설정
  - App Group 데이터 공유
  - Small / Medium / Large 위젯
  - Interactive 체크박스

Phase 4 (유료 기능)
  - StoreKit 2 구독 (월간 + 연간)
  - 주간/월간 리포트 자동 생성
  - 멀티 플래너
  - 반복 투두
  - 다른 날 투두 확인

Phase 5 (출시)
  - App Store Connect 설정
  - Privacy Policy / Terms of Service
  - 심사 제출
```

- [x] Phase 1: Notion OAuth + APIClient + 온보딩 + Sign in with Apple
- [x] Phase 2: 투두 기록 + 빠른 캡처 + 데일리 리포트 + 카테고리 (무료)
- [x] Phase 3: 홈 화면 위젯 (WidgetKit + App Group)
- [ ] Phase 4: StoreKit 2 + 반복 투두 (유료)
- [ ] Phase 5: App Store 심사 제출

---

## 현재 진행 상태 (2026-05-31 기준)

**Phase 1 ✅ 완료**
- Sign in with Apple (개발용 로그인 포함)
- 온보딩 플로우 (로컬/노션 선택 → OAuth → DB선택 → 속성매핑)
- MainTabView, Colors, APIClient 기반 세팅

**Phase 2 ✅ 완료**
- ✅ 투두 화면 (TodoView/ViewModel/Service) + 날짜이동/플래너전환/카테고리필터
- ✅ 퀵캡처 바텀시트 (QuickCaptureView/ViewModel)
- ✅ 데일리리포트 (DailyReportView/ViewModel/Service + Notion 동기화)
- ✅ 카테고리 관리 (CategoryView/ViewModel/Service)
- ✅ 설정 탭 + 플래너 관리 (Add/Detail/Migration/NotionSettings)
- ✅ SwiftData 실제 연동 (TodoItem, DailyReportItem, CategoryItem, PlannerItem, SyncQueueItem)
- ✅ SyncQueue Offline-First (SyncQueueManager + SyncQueueProcessor)
- ✅ Notion API 연동 (NotionAPIClient → 백엔드 → Notion)
- ✅ NotionAuthManager (SFSafariViewController OAuth, planner별 토큰)
- ✅ PlannerService (SwiftData CRUD, 레거시 마이그레이션, plannerId backfill)

**Phase 3 ✅ 완료** 홈 화면 위젯
- ✅ WidgetDataProvider (App Group UserDefaults 공유, main app 타겟)
- ✅ TodoWidgetBundle / TodoWidgetProvider (widget extension 타겟: TodoReportWidget/)
- ✅ Small / Medium / Large 위젯 뷰 (SmallWidgetView, MediumWidgetView, LargeWidgetView)
- ✅ TodoViewModel.updateWidget() — 투두 fetch/toggle/add/delete 후 자동 갱신
- ⚠️ App Groups capability: 두 타겟 모두 Xcode > Signing & Capabilities에서 수동 활성화 필요
  → App Group ID: group.kr.nock.TodoReport

**Phase 4 ✅ 일부 선행 완료**
- ✅ 주간/월간 리포트 (ReportView/ViewModel/Service + Charts)
- ✅ Pro 게이팅 (월간, 날짜이동, 이전기간 조회)
- ❌ StoreKit 2 구독 결제
- ❌ 반복 투두

**Phase 5 ❌** 앱스토어 출시

---

## Widget Extension 설정 (Xcode 수동 작업 필요)

Widget Extension 타겟(`TodoReportWidget`)은 이미 생성되어 있음.
소스 파일도 `TodoReportWidget/`에 배치 완료 (PBXFileSystemSynchronizedRootGroup으로 자동 포함).

**남은 수동 작업: App Groups capability 활성화**
```
1. TodoReport 타겟 선택 → Signing & Capabilities → + App Groups
   → + 버튼 → group.kr.nock.TodoReport
2. TodoReportWidget 타겟 선택 → 동일하게 반복
3. 빌드 후 위젯 시뮬레이터에서 확인
```

**위젯 파일 구조:**
```
TodoReportWidget/         ← widget extension 타겟 (자동 포함)
├── TodoWidgetBundle.swift   # @main WidgetBundle
├── TodoWidgetProvider.swift # TimelineProvider + Widget declarations
├── SmallWidgetView.swift
├── MediumWidgetView.swift
└── LargeWidgetView.swift

TodoReport/Widget/        ← main app 타겟
└── WidgetDataProvider.swift # update() App Group에 씀 + reloadAllTimelines()
```
