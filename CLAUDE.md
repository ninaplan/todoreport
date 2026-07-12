# 투두리포트 (TodoReport) — Claude Code 컨텍스트

## 현재 상황 (2026-07-11 기준)

### 앱 상태
- v1.0.4 App Store 제출 완료
- v1.0.5 제출 예정 (빌드 11) — Xcode에서 MARKETING_VERSION 1.05 · CURRENT_PROJECT_VERSION 11 설정 후 Archive

### v1.0.5 변경 내용
- Notion 동기화 안정성 개선 — 날짜 이동 후 할일이 이전 상태로 되돌아가거나 사라지던 문제 수정 (Version Guard, push 큐 대기)
- 오프라인에서 편집한 내용이 Notion에 반영되지 않던 문제 수정 (NetworkMonitor, 큐 손실·고아 항목 복구)

### v1.0.4 변경 내용
- 다크/라이트 모드 선택 기능
- 투두/리포트 날짜 이동 제한 전면 해제
- 위젯 Pro 잠금 버그 수정
- 페이월 전면 재설계
  - 다크 고정 (.preferredColorScheme(.dark))
  - NavigationStack + CloseButton 표준화
  - 기능 카드 + 무료 제공 목록
  - 하단 가격 카드 + CTA 고정
- 리포트 탭 최초 진입 시 빈 화면으로 오래 대기하던 문제 수정
  - 원인: calculateStreak()가 365일치를 동기 조회하며 MainActor를 막아 첫 프레임 렌더링 자체가 지연됨
  - 조치: fetchReport()에 Task.yield() 추가해 로딩 상태를 최소 1프레임 먼저 그리도록 함 (임시 완화, 근본 원인인 스트릭 계산 범위 축소는 별도 예정)
- 투두 탭 날짜(달력) 클릭 시 날짜 이동 제한을 해제했는데도 페이월이 뜨던 버그 수정
  - 원인: requestDatePicker()에 예전 Pro 가드가 남아있었음
  - 조치: 가드 및 showDatePaywall/datePaywallMessage/dismissDatePaywall() 관련 코드 전체 제거

### 다음 할 일
- v1.0.5 App Store Archive·제출 (1.05 / 빌드 11)
- 노션 업로드 마이그레이션 버그 수정 — `PlannerMigrationViewModel.uploadToNotion()`에서 `plannerId`가 nil인 기존 투두가 `SyncQueueManager`의 `isPlannerNotionConnected(nil)` 가드에 걸려 조용히 스킵됨 (설계만 완료, 미적용)
- 노션 연결 시작 전 안내 팝업 추가 — 기존 "같은 워크스페이스" 인라인 문구를 조건부 alert("페이지 선택 시 주의해주세요")로 교체 (설계만 완료, 미적용)
- 구독 상태 카드 (설정 화면) 페이월 스타일 통일
- 리포트 스트릭 계산 범위 축소/캐싱 (365일 전체 스캔 근본 개선)

### 최근 완료 작업
- 플래너 관리 화면 신설 + 구독 다운그레이드 버그 수정 (2026-07-11, 커밋 ab6021c → 56fb69a): 상세 내용은 아래 "구독 만료 감지" / "플래너 관리" / "노션 연결 해제" 섹션 참고
- NotionWorkspaceConnection 1·2단계 (2026-07-10, 커밋 15c9a98): 워크스페이스 단위 토큰 공유 + revoke 안전장치(마지막 참조 플래너가 아니면 revoke 스킵)
- Notion 동기화 Version Guard (2026-07-08): notionLastEditedTime 필드, push 성공 시 저장, pull upsert Version Guard, debounce pull 큐 대기. V2 Tombstone은 미해결(유령 항목 부활 케이스).
- 오프라인 동기화 큐 손실 버그 완전 해결 (2026-07-07): NetworkMonitor.swift 신규 생성(NWPathMonitor 기반 재연결 자동 감지), SyncQueueProcessor.swift에 네트워크 에러 전용 분기 추가(retryCount 미증가, 오프라인 중 무한 재귀 방지), SyncQueueManager.swift에 recoverStuckProcessingItems() 추가(processing 고아 상태 앱 시작 시 자동 복구). 개발자 옵션에 동기화 큐 상태(pending/processing/failed 개수) 디버그 UI 추가.
- [해결 확인됨, 2026-07-07 실기기 테스트 완료] AutoFocusTextField가 @FocusState 없이 UIViewRepresentable로 UITextField/UITextView를 직접 감싸고 becomeFirstResponder()를 수동 호출하는 방식으로 구조 변경되어 있음을 확인. markedTextRange == nil 체크로 IME 조합 중 텍스트 동기화를 막아 문제 해결됨. 실기기 한글 입력 테스트 완료.
- [해결 완료, 2026-07-07] 원인이 두 가지였음: 1) 네트워크 에러와 API 에러를 구분 안 하고 동일하게 retryCount를 증가시켜 오프라인 중 재시도 예산이 소진되면 clearFailedItems()가 데이터를 삭제 2) processing 상태에서 앱 종료 등으로 중단되면 영구 고아 상태가 되어 어떤 재시도 로직에도 안 걸림. 해결: NetworkMonitor.swift(NWPathMonitor) 신규 추가로 재연결 자동 감지, SyncQueueProcessor.swift에 isNetworkUnavailable() 판별 추가로 네트워크 에러는 retryCount 미증가, SyncQueueManager.swift init()에 recoverStuckProcessingItems() 추가로 앱 시작 시 processing 고아 항목을 pending으로 자동 복구. 실기기 비행모드 테스트로 검증 완료.

### 알려진 버그
- 노션 업로드 마이그레이션 시 plannerId가 nil인 기존 투두가 노션에 안 올라감 (원인 파악됨, 수정 미적용 — 위 "다음 할 일" 참고)
- 콜드 스타트 시 Notion 동기화 로딩 인디케이터 미표시 (투두 탭)
- 투두 날짜 이동 후 목적지 날짜 미표시 (간헐적)

### 주요 파일
- SPEC.md — 앱 전체 스펙
- CLAUDE.md — 개발 원칙 및 진행 상태
- CHANGELOG.md — 버전별 수정 내역
- V2-IDEAS.md — v2 백로그

---

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
- **디버그:** 설정 → 개발자 옵션 → 동기화 큐 상태에서 pending/processing/failed 개수 실시간 확인 가능 (#if DEBUG 전용)

### 백엔드 (별도 레포)
- Next.js 14 App Router + Vercel
- Notion API 서버사이드 전용 호출

---

## 절대 원칙 (위반 금지)

0. **기존 코드 무단 변경 금지** — 요청하지 않은 기존 UI·로직·코드 구조·아키텍처(Picker 스타일, 레이아웃, 컴포넌트 설계, 함수 구조 등 모든 것)를 임의로 바꾸지 않는다. 구현 방식 변경이 불가피한 경우 반드시 먼저 이유를 설명하고 사용자 승인을 받은 후 진행한다.

0. **모듈 독립성 제1원칙** — 기능별(UI/백엔드/StoreKit 등) 완전 독립 모듈로 구현.
   하나를 수정해도 다른 기능에 영향이 없어야 한다.
   유지보수 용이성이 모든 설계 결정의 최우선 기준.

0. **백엔드-iOS 버전 호환성 제2원칙** — 백엔드는 항상 먼저 배포되고, iOS 업데이트는 사용자별로 며칠~몇 주씩 지연될 수 있다. "구버전 앱이 영원히 신버전 백엔드를 쏠 수도 있다"고 가정하고 설계한다.
   → API 응답 구조 변경 시 기존 필드 삭제·이름변경 금지 (추가만 허용)
   → 응답 형식을 크게 바꿔야 하면 deprecation 기간을 두고 신/구 필드 병행 제공
   → 호환 안 되는 변경이 꼭 필요하면 단계적 출시(Phased Release) 또는 API 버전 분기 고려

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
│   ├── Cache/
│   │   └── CacheManager.swift     # SwiftData + TTL 캐싱
│   ├── Notion/
│   │   ├── CategoryNotionSync.swift   # 카테고리 select/status 옵션 동기화
│   │   └── TodoPropsMappingAutoFill.swift
│   └── Logging/
│       └── AppLogger.swift        # 파일 기반 로그 (Documents/app_logs.txt, 500KB 자동 트림)
│
├── Features/                      # 기능별 완전 독립 모듈
│   ├── Todo/                      # 투두 (무료)
│   ├── QuickCapture/              # 빠른 캡처 플로팅 시트 (무료)
│   ├── DailyReport/               # 데일리 리포트 (무료)
│   ├── WeeklyReport/              # 주간 리포트 (유료)
│   ├── MonthlyReport/             # 월간 리포트 (유료)
│   ├── Planner/                   # 멀티 플래너 (유료)
│   ├── RecurringTodo/             # 반복 투두 (유료)
│   ├── Subscription/              # 구독 관련 UI
│   │   ├── SubscriptionManager.swift     # StoreKit 2, isPro, 만료 감지
│   │   ├── PaywallView.swift             # 구독 유도 화면
│   │   ├── PlannerDowngradeView.swift    # 구독 만료 시 플래너 선택
│   │   └── PlannerDowngradeViewModel.swift
│   └── Category/                  # 카테고리 관리 (무료, SwiftData + 노션 옵션 동기화)
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

### Category
```swift
struct Category: Identifiable, Codable {
    let id: String
    var name: String
    var colorHex: String       // 기본 #FD6845
    var icon: String           // 기본 tag.fill
    var status: CategoryStatus // active / archived / completed(v2)
    var plannerId: String?
    var notionOptionId: String?
    var notionOptionName: String?
}
```

**노션 연동 플래너:** `CategoryNotionSync`가 투두 DB select/status 옵션과 동기화.
- 이름 일치 → 병합, 노션 전용 신규 옵션 → 앱 카테고리 자동 추가
- **삭제** → 노션 옵션도 삭제 (`remove-select-option`)
- **보관** → 앱만 숨김, 노션 유지, 재실행 후 자동 활성화 없음

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

| 사용자 유형 | 인증 | 데이터 저장 |
|---|---|---|
| 노션 사용자 | Notion OAuth | Notion DB |
| 로컬 사용자 | 없음 (앱만 사용) | SwiftData (기기) |

> 별도 앱 계정 로그인(Sign in with Apple 등) 없음. Notion OAuth는 노션 연결 선택 시에만 필요.
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

## SyncQueue 아키텍처 원칙

**원칙 1: 동기화 작업은 selectedPlanner(UI 상태)에 절대 의존하지 않는다**

SyncQueue는 백그라운드·포그라운드 전환, 앱 재실행 시 처리되므로 실행 시점에 selectedPlanner가 달라져 있을 수 있다.
→ 반드시 `todo.plannerId` 기준으로 `PlannerService.shared.store`에서 해당 플래너를 직접 조회한다.

```swift
// ❌ 금지: UI 상태에서 읽기
let token = PlannerService.shared.selectedPlanner?.resolvedNotionToken

// ✅ 올바른 방법: 큐 항목의 plannerId 기준 조회
guard let planner = PlannerService.shared.store.first(where: { $0.id == item.plannerId }),
      let token = planner.resolvedNotionToken else { return }
```

**원칙 2: `TodoItem.update(from:)`은 사용자 편집 가능 필드만 업데이트한다**

다음 필드는 각 담당 로직이 단독 관리하므로 `update(from:)`에서 절대 덮어쓰지 않는다:
- `notionPageId` — SyncQueueProcessor.updateNotionPageId()가 세팅
- `notionRelationLinked` — NotionRelationLinker / updateTodo(dateChanged) 관리
- `notionCreatedAt` — Notion에서 내려온 값만 신뢰 (upsertFromNotion에서 직접 세팅)
- `plannerId` — 생성 시 고정, 플래너 이동 기능 구현 시 별도 메서드로 처리

**원칙 3: 로컬(Notion 미연결) 플래너 할일은 SyncQueue에 enqueue하지 않는다**

- `SyncQueueManager.isPlannerNotionConnected(_:)` — `plannerId` nil / store 미존재 / `!isNotionConnected` → false
- `private enqueue()` 진입 시 미연동이면 **enqueue 스킵** (로컬 전용 플래너는 Notion push 불필요)
- Processor 플래너 스킵 시 `retryCount` 상한(3회) 후 queue item 삭제 — 무한 루프 방지
- init 시 `clearUnprocessableQueueItems()` — 미연동 플래너 orphan pending 정리

---

## Notion sync 원칙 (투두 탭)

**날짜 이동 (`selectedDate` 변경):** 로컬 SwiftData만 조회 — **Notion sync 없음**
→ `TodoViewModel.fetchLocalTodos(for:)`

**Notion → 앱 pull 실행 시점 (이 4가지만):**
- 콜드 스타트 (`onAppear` 최초 1회 `isFirstLaunch`)
- 포그라운드 복귀 (`onForeground`)
- pull-to-refresh
- 플래너 전환 (`switchPlanner`)

→ `TodoViewModel.syncFromNotion(for:)` → `TodoService.syncTodosFromNotion(for:)`

**앱 → Notion push:** 기존과 동일 — 쓰기 즉시 SwiftData 저장 후 SyncQueue 백그라운드 전송

**Notion 날짜 변경 반영:**
- `upsertFromNotion` — pageId 매칭 시 `applyNotionDate`로 로컬 date 갱신
- A일 화면 refresh 시 Notion 응답에 없는 연동 항목 → 로컬 즉시 삭제 (5분 유예 제거)
- B일 화면에서 refresh 시 해당 항목 pull·반영

---

## TodoViewModel fetch 구조

| API | 용도 |
|---|---|
| `fetchLocalTodos(for:)` | 로컬 DB만 조회 — **날짜 이동** 시 사용 |
| `syncFromNotion(for:)` | local fetch + Notion pull — **4가지 sync 시점**에만 |

~~`performFetchTodos` / `fetchTodos`~~ — **제거됨** (v1.0.1)

- `localFetchTask` — 날짜 연타 시 cancel 후 재시작
- `notionSyncTask` — sync 중 cancel·stale date guard (`selectedDate` 일치 확인)

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
- 노션에 리포트 저장하기 (주간/월간)
- 멀티 플래너 (2개 이상)
- 반복 투두 (v2 예정)

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
탭 (체크박스 영역)          → 완료/미완료 토글
탭 (텍스트/행 영역)         → 아무것도 안 함
우로 스와이프 (풀스와이프)   → 고정(isPinned 토글)
좌로 스와이프               → [내일하기] [날짜변경] [삭제]
길게 누르기                 → 편집 모드
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

## 알려진 패턴 / 주의사항

**외관 모드 설정 (`appColorScheme`)**

- `@AppStorage("appColorScheme") private var appColorScheme: String = "system"`
- 값: `"system"` / `"light"` / `"dark"`
- 루트 `Group`에 `.preferredColorScheme()` 적용
- `PaywallView`는 이 설정과 무관하게 항상 `.preferredColorScheme(.dark)` 고정

**Notion OAuth (`NotionAuthManager`)**

- `ASWebAuthenticationSession` + `prefersEphemeralWebBrowserSession = true` — 매 연결마다 ephemeral 브라우저 세션 (계정 삭제·연동 초기화 후 Notion 로그인 화면부터 시작).
- `callbackURLScheme: todoreport` — 백엔드 callback HTTP 302 → `todoreport://auth/callback` / `auth/error`.
- completion handler → `handleCallback` → `secondaryOAuthCompletion(token)`. `TodoReportApp.onOpenURL` fallback 유지.
- 사용자 취소: `ASWebAuthenticationSessionError.canceledLogin` → `oAuthCancelledCompletion?()`.
- 마지막 Notion 연동 플래너 삭제/연동 초기화·계정 삭제 시 `revoke` + `signOut()` (다른 연동 플래너 있으면 signOut 생략). ~~`clearWebCookies`~~ — ephemeral 세션으로 불필요.
- ~~재인증 시 이전 토큰 자동 무효화~~
- → **정정 (2026-07-10):** 재인증 자체는 안전함 (Notion 동의 화면에서 기존 페이지 체크를 유지한 경우). 실제 문제는 두 가지였음:
  (1) 앱의 "연동초기화"가 명시적으로 revoke API를 호출하면 워크스페이스 공유 권한 전체가 끊김 (Notion이 사용자+Integration당 권한 상태를 하나만 관리하기 때문)
  (2) Notion OAuth 재동의 화면에서 기존에 체크돼 있던 페이지를 사용자가 직접 해제하면 그 페이지 접근이 즉시 빠짐 (앱 코드가 관여 못 하는 영역, Notion 자체 동작)
  NotionWorkspaceConnection 구조(1단계+2단계, 2026-07-10 커밋 15c9a98)는 (1)을 막는 안전장치로 여전히 유효함 — 마지막 참조 플래너가 아니면 revoke 자체를 스킵함. (2)는 코드로 방지 불가, OAuth 진입 전 안내 문구로만 완화 가능.
  멀티플래너 UI는 아직 숨김 상태 유지 (복원은 다음 세션 예정). 상세: `V2-IDEAS.md` §Notion 토큰 끊김.

**멀티 플래너 — 플래너마다 독립 Notion DB 세트**

- 플래너 1개 = **투두 DB 1 + 리포트 DB 1 + Notion 워크스페이스 연결(`NotionWorkspaceConnection`, 동일 워크스페이스는 플래너 간 공유)** 묶음. `PlannerService`·`SyncQueue`·리포트 저장은 **항상 `todo.plannerId` / `selectedPlanner` 기준**.
- **같은 Notion 워크스페이스**에 DB가 여러 개여도, 플래너 B를 **다른 DB 세트**에 연결하는 것은 지원 시나리오. 다만 사용자가 **플래너 전환·DB 선택을 혼동**하면 다른 플래너에서 저장/동기화 실패(404 등)·설정 화면 DB 이름 미표시처럼 보일 수 있음.
- **원칙:** DB 세트(투두+리포트)당 플래너 1개. 두 플래너에 동일 DB 중복 연결 비권장.
- **운영 Q&A (사용자 가이드):** `SPEC.md` §6 멀티 플래너 — 「멀티 플래너 + 노션 DB (Q&A · 가이드)」 참고.
- **개발 시:** `isNotionConnected`만으로 리포트 저장 가능 여부 판단하지 말 것 — `notionReportDBId`·`resolvedNotionToken` 유효성도 필요 (향후 UX 개선 후보).

**AutoFocusTextField — Dynamic Type + 한글 IME**

투두 인라인 입력 등 한글 조합이 필요한 곳은 SwiftUI `TextField` 대신 `AutoFocusTextField`(UIKit)를 쓴다.
고정 `UIFont.systemFont(ofSize:)`를 쓰면 인접 SwiftUI `Text(.body)`보다 작아 보이므로, 본문 입력은 `textStyle: .body`로 맞춘다.

```swift
// ❌ 고정 pt — 시스템 글자 크기 변경 시 투두 행과 불일치
AutoFocusTextField(text: $title, placeholder: "새 투두", font: .systemFont(ofSize: 17))

// ✅ SwiftUI .body와 동일 스케일 (Dynamic Type 연동)
AutoFocusTextField(text: $title, placeholder: "새 투두", textStyle: .body)
```

편집 시트 제목 등 본문보다 큰 필드는 `textStyle: .title3` 등으로 지정한다 (`TodoEditFormView` 제목).

**SwiftUI View에서 live 데이터 읽기 — stale 스냅샷 주의**

`let planner: Planner`처럼 value type을 상수로 들고 있으면 저장 후 dismiss 없이는 UI가 갱신되지 않는다.
`@Observable` 서비스에서 매 render마다 조회하는 computed property 패턴을 사용한다.

```swift
// ❌ 금지: init 시점 스냅샷 — 노션 연결 완료 후에도 "연결하기" 버튼이 그대로 보임
private let planner: Planner

// ✅ 올바른 방법: PlannerService.shared는 @Observable, store 변경 시 자동 re-render
private var currentPlanner: Planner {
    PlannerService.shared.store.first(where: { $0.id == plannerId }) ?? initialPlanner
}
```

**ModelContainer 초기화 실패 — in-memory 폴백 금지**

`isStoredInMemoryOnly: true` 폴백은 데이터 소멸을 조용히 감추고, 사용자는 데이터가 사라진 줄 모른다.
→ DEBUG: `fatalError`로 즉시 크래시, Release: `PersistenceErrorView` 표시 후 정상 플로우 차단.

```swift
// ❌ 금지: 조용한 in-memory 폴백
} catch {
    container = try! ModelContainer(for: schema, configurations: inMemoryConfig)
}

// ✅ 올바른 방법
} catch {
    #if DEBUG
    fatalError("[Persistence] 초기화 실패: \(error)")
    #else
    initializationError = error  // → TodoReportApp에서 PersistenceErrorView 표시
    #endif
}
```

**구독 만료 감지 — 상태 기반 멱등 체크 (evaluateSubscriptionState)**

기존에는 `wasProBefore` 플래그로 "Pro→Free 전환 시점"을 감지했으나, 이 값이 메모리에만 존재해서 앱이 종료된 상태에서 구독이 만료되면 재실행 후 첫 체크에서 전환 자체가 감지되지 않는 버그가 있었음 (2026-07-11 발견·수정, 커밋 ab6021c).

`SubscriptionManager.updatePurchasedProducts()`는 이제 entitlement 상태 갱신만 책임지고 전환 감지 로직은 제거됨. 대신 `TodoReportApp.evaluateSubscriptionState()`가 앱 최초 실행 + `scenePhase == .active` 전환마다 호출되어 "지금 상태"만 보고 판단한다:

```swift
// TodoReportApp.evaluateSubscriptionState()
if SubscriptionManager.shared.isPro {
    PlannerService.shared.restoreAllPlanners()
    return
}
guard PlannerService.shared.activePlannerCount > 1 else { return }
ReportNotificationManager.shared.cancelAll()
showPlannerDowngrade = true
```

멱등적 구조라 몇 번을 다시 체크해도 같은 결과가 나옴 — 콜드 실행/포그라운드 복귀 어느 쪽이든 정확히 잡히고, 이미 다운그레이드된 상태에서 반복 팝업도 안 생김.

`PaywallViewModel.purchase()` / `restore()`도 성공 확인 직후 `PlannerService.shared.restoreAllPlanners()`를 직접 호출 — 재구독 시 앱 재시작 없이 즉시 복구됨.

**읽기 전용 플래너 — isReadOnly**

구독 만료 시 Pro 전용 플래너(2번째 이상)는 `isReadOnly = true`로 전환. 데이터는 보존, 편집만 차단.
- `PlannerItem.isReadOnly: Bool = false` (SwiftData lightweight 마이그레이션 자동 처리)
- `PlannerService.downgradeToFree(keepPlannerId:)` — 선택 플래너 외 전체 isReadOnly = true
- `PlannerService.restoreAllPlanners()` — 재구독 시 전체 isReadOnly = false
- `TodoViewModel`: `addTodo()`, `deleteTodo()`, `performSaveTodoEdit()` 진입 전 isReadOnly 체크 → `showReadOnlyAlert`
- `PlannerDetailView`: `List { ... }.disabled(currentPlanner.isReadOnly)` + 상단 잠금 배너. 이름/아이콘/노션설정 등 내용 수정만 차단.

**플래너 관리 화면 — PlannerManagementView (2026-07-11 신규, 커밋 56fb69a)**

설정 화면 플래너 섹션이 플래너 개수에 따라 분기됨:
- **1개**: 기존과 동일하게 그 플래너를 인라인 행으로 표시 + "+ 플래너 추가" 버튼
- **2개 이상**: `①` 현재 선택된 플래너 1행(탭하면 `PlannerDetailView`) + `②` 전체 플래너 아이콘을 겹쳐 쌓은 스택(최대 4개, 초과분은 "+N" 배지) + "플래너 관리" 텍스트 — 탭하면 `PlannerManagementView`로 이동. 이 경우 "+ 플래너 추가"는 관리화면 안으로 이동.

`PlannerManagementView` 구조:
- `PlannerItem.sortOrder: Double = 0` 필드로 정렬. `PlannerService.refreshStore()`는 `sortOrder` 오름차순 → 같으면 `createdAt` 오름차순(2차 정렬). 기존 플래너는 전부 sortOrder=0이라 createdAt 기준 기존 순서가 그대로 유지됨 — 백필 마이그레이션 불필요.
- `PlannerService.reorderPlanners(_ newOrder: [Planner])` — 드래그로 바뀐 순서를 0, 1, 2... 순차 재할당.
- `PlannerService.activePlannerCount` — `isReadOnly == false` 플래너 수 (다운그레이드 필요 여부 판단용).
- **비편집 상태**: 각 행은 순수 `NavigationLink`로 `PlannerDetailView` 이동 (표준 chevron). 읽기전용이면 disabled+dim. 선택된 플래너는 이름 옆에 작은 "사용중" 캡슐 태그로만 표시(인터랙션 없음, 순수 표시용) — 대표 플래너 전환은 이 화면에서 하지 않고 **홈 화면(투두 탭 상단 드롭다운)에서만** 가능.
- **편집 상태** (우상단 EditButton): 각 행 왼쪽에 커스텀 마이너스 원형 버튼(`.onDelete` 미사용, 탭 즉시 확인 alert — native reveal 2단계 문제 회피) + 오른쪽에 native `.onMove` 드래그 핸들.
- **스와이프 삭제**: 편집모드와 별개로 `.swipeActions`(휴지통 아이콘만)로 언제든 삭제 가능. 편집모드 마이너스 버튼과 공존(둘 다 같은 확인 alert·마지막 1개 가드 재사용).
- 삭제 확인 문구는 `Planner.deleteConfirmationMessage`(computed property, `PlannerDetailView`와 공용)로 노션연동/로컬 분기.
- `PlannerDetailView` 맨 아래에도 동일한 삭제 버튼 있음 (박스/카드 배경 없이 텍스트만 — `.listRowBackground(Color.clear)`). 두 군데서 삭제 가능하지만 확인 문구·로직은 공용.
- 신규 플래너 기본 이름은 온보딩과 동일한 풀 사용 (`PlannerService.defaultNamePool` — "내 플래너", "나의 할 일" 등 담백한 톤. 예전엔 "행복한 라마"류 형용사+동물 조합이라 온보딩과 톤이 안 맞았음). 아이콘 색 랜덤 배정은 시도했다가 되돌림 — 사용자가 사진으로 아이콘을 직접 선택하는 경우가 많아서 우선순위 낮다고 판단. **V2: 사용자가 색상 팔레트·아이콘을 직접 고르는 기능 검토 중** (현재 SF Symbol 아이콘 세트가 플래너와 무관한 것들이 많아 세트 자체 교체도 필요).

**노션 연결 해제 — resetNotionConnection (2026-07-11, 명칭·동작 변경, 커밋 56fb69a)**

- "연동 초기화" → **"노션 연결 해제"** 로 명칭 변경 (버튼/alert 타이틀/확인 버튼 전부).
- 예전엔 연동 해제 시 로컬 `TodoItem`/`DailyReportItem`을 전부 삭제했는데, 이제 **삭제하지 않고 노션 연결 필드만 초기화**함 — `notionPageId = ""`, `notionRelationLinked = false`, `notionLastEditedTime = nil`, `notionCreatedAt = nil`로 정리해서 "로컬 전용 투두"로 자연스럽게 전환 (`notionPageId == ""`가 코드 전반에서 로컬 전용 판별 기준).
- `SyncQueueItem` 삭제, 플래너 자체 연동 필드 초기화(`isNotionConnected = false`, 토큰/DB ID/매핑 nil)는 기존 그대로.
- alert 메시지도 실제 동작에 맞게 변경: "노션 연결이 끊어지며, 이 플래너는 로컬 플래너로 전환됩니다. 투두·리포트 데이터는 그대로 유지돼요."
- `deletePlanner()`(플래너 자체 삭제)는 이 변경과 무관 — 거기는 여전히 전체 삭제가 의도된 동작.

**⚠️ 발견된 버그 (미수정) — 노션 업로드 마이그레이션**

`PlannerMigrationViewModel.uploadToNotion()`이 `plannerId == nil`인 레거시 투두도 업로드 대상에 포함시키지만(`$0.plannerId == plannerId || $0.plannerId == nil`), `SyncQueueManager.enqueueTodoCreate()` 내부의 `isPlannerNotionConnected(_:)`가 `plannerId == nil`이면 무조건 `false`를 반환해서 큐에 안 들어가고 조용히 스킵됨. 리포트는 `DailyReportService.saveReport()`가 `selectedPlanner?.id`로 자동 보정해서 문제없음. 수정 방향: `uploadToNotion()`에서 `item.toTodo()` 호출 전에 nil `plannerId`를 마이그레이션 대상 플래너 ID로 채워주면 됨 (설계 완료, 다음 세션에 적용 예정).

**카테고리 노션 동기화 — CategoryNotionSync**

- 투두 DB `category`가 select/status로 매핑된 플래너만 동작 (`isSelectSyncEnabled`)
- `syncCategoriesByName`: 이름 일치 병합 + 노션 전용 신규 옵션 → 앱 카테고리 import
- **삭제** = SwiftData 삭제 + `onCategoryDeleted` → `remove-select-option`
- **보관** = `status = archived`만, 노션 옵션 유지, 보관 이름은 재병합·재import 제외
- 동기화 호출: 카테고리 관리 `fetchCategories`, 투두 `syncFromNotion` / 포그라운드·refresh, `TodoReportApp` 포그라운드
- 연결된 카테고리만 투두 Notion payload에 `categoryName` 포함 (`notionSyncName`)
- 1회 설정 시트·앱 사용 토글(`isEnabledInApp`)은 **사용하지 않음** (v1.5 폐기)

---

## 개발 우선순위 (MVP)

```
Phase 1 (핵심 기반)
  - Notion OAuth 연동
  - APIClient + Repository 패턴 구현
  - 온보딩 플로우 (웰컴 → 로컬/노션 선택)

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

- [x] Phase 1: Notion OAuth + APIClient + 온보딩
- [x] Phase 2: 투두 기록 + 빠른 캡처 + 데일리 리포트 + 카테고리 (무료)
- [x] Phase 3: 홈 화면 위젯 (WidgetKit + App Group)
- [ ] Phase 4: StoreKit 2 + 반복 투두 (유료)
- [ ] Phase 5: App Store 심사 제출

---

## 현재 진행 상태 (2026-06-13 기준)

**Phase 1 ✅ 완료**
- 온보딩 플로우 (노션/로컬 선택 → OAuth → DB선택 → 속성매핑) — 웰컴 소개 페이지 🔜
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
- ✅ NotionAuthManager (ASWebAuthenticationSession OAuth, `prefersEphemeralWebBrowserSession`, planner별 토큰)
- ✅ PlannerService (SwiftData CRUD, 레거시 마이그레이션, plannerId backfill)

**Phase 3 ✅ 완료** 홈 화면 위젯
- ✅ WidgetDataProvider (App Group UserDefaults 공유, main app 타겟)
- ✅ TodoWidgetBundle / TodoWidgetProvider (widget extension 타겟: TodoReportWidget/)
- ✅ Small / Medium / Large 위젯 뷰 (SmallWidgetView, MediumWidgetView, LargeWidgetView)
- ✅ TodoViewModel.updateWidget() — 투두 fetch/toggle/add/delete 후 자동 갱신, `hideCompleted` 설정 변경 시 (`didSet`)
- ✅ Small 완료율 무료, Medium·Large 목록 Pro 게이팅 (`widgetIsPro` App Group 동기화)
- ✅ `todoreport://todo` 딥링크, 설정 탭 NavigationStack 재진입 시 루트 초기화
- ✅ `refreshTodayFromStore()` — 앱 실행·포그라운드 시 위젯 갱신
- ⚠️ App Groups capability: 두 타겟 모두 Xcode > Signing & Capabilities에서 수동 활성화 필요
 → App Group ID: group.kr.nock.TodoReport

**Phase 4 🔄 진행 중** (2026-06-06 기준)
- ✅ 주간/월간 리포트 (ReportView/ViewModel/Service + Charts)
- ✅ Pro 게이팅 (월간, 날짜이동, 이전기간 조회)
- ✅ 주간/월간 리포트 그래프 개선 (꺾은선 차트, 막대 탭 시 해당 날 투두 목록)
- ✅ 하루 리뷰 타임라인 (DailyReportView 개선)
- ✅ 리포트 탭 하루 리뷰 더보기/접기 (ReviewTimelineRow: GeometryReader 높이 비교로 잘림 감지)
- ✅ 하루 리뷰 탭 시 투두 목록(DayTodoDetailView) 이동 제거 (더보기와 충돌)
- ✅ 시간 지정 + 투두 알림 (TodoNotificationManager, TodoEditFormView)
- 🔜 투두 탭 목록 시간 표시 (`TodoRow`, `scheduledTime`) — v1.1 (v1: 편집 시트만)
- 🔜 반복 투두 (RecurrenceRule, RecurringTodoManager, TodoEditFormView 반복 섹션) — v2로 연기
- ✅ Notion relation 자동 연결 개선 (NotionRelationLinker: 14일 윈도우, max 10개, 성공 후에만 linked 세팅)
- ✅ SyncQueueProcessor: create 완료 후 자동 relation enqueue
- ✅ TodoService: 날짜 변경 시 notionRelationLinked 리셋
- ✅ TodoViewModel.onForeground(): SyncQueue flush 대기 후 `syncFromNotion` (최대 5초)
- ✅ v1.0.1: 날짜 이동 local-only fetch (`fetchLocalTodos`), Notion pull 4시점 분리
- ✅ v1.0.1: Notion 날짜 변경 `applyNotionDate`, A일 refresh 즉시 삭제, SyncQueue 미연동 enqueue 차단
- ✅ 포그라운드 복귀 시 linkMissing() + processIfConnected() 호출 (TodoReportApp)
- ✅ TodoEditFormView 공통 편집 컴포넌트 (QuickCapture/TodoEdit 공유)
- ✅ 무료 사용자 날짜 범위: 어제·오늘·내일 3일 (±1일)
- 🔜 반복 설정 변경/해제 처리 (RecurringTodoEditHandler, detectChange/applySingleOnly/applyFromNowOn) — v2로 연기
- ✅ 언어 설정 연동 (시스템/한국어/영어, 재시작 후 적용 방식)
- ✅ PawRatingView (발바닥 아이콘 별점 입력), UI 라벨 '별점' 사용
- ✅ NotionDBPickerView 건너뛰기 버튼: .body 폰트, .primary 색상
- ✅ 백엔드 detectRelationProp() 로그 추가 (POST/PATCH 양쪽)
- ✅ SyncQueue selectedPlanner 의존 제거
  (encodedTodoPayload, enqueueTodoUpdate/Create/Delete, SyncQueueProcessor, DailyReportService, NotionRelationLinker 전체)
- ✅ TodoItem.update(from:) sync 필드 보호
  (notionPageId, notionRelationLinked, notionCreatedAt 덮어쓰기 방지)
- ✅ SyncQueue pending 항목 전체 보호 (early return, 삭제 필터 보호)
- ✅ SyncQueueItem requeueCount 추가 (무한루프 방지, 상한선 5회)
- ✅ PersistenceController 마이그레이션 실패 시 PersistenceErrorView 표시
- ✅ PlannerMigrationView UX 전면 개선
  (노션 연결 전 데이터 처리 방식 선택, 취소 방지, 실패 분기 처리)
- ✅ 퀵캡처/투두 추가 시 selectedDate 주입 (날짜 이동 후 추가 시 현재 날짜 적용)
- ✅ 데일리 리포트 페이지 제목 포맷 변경 (백엔드: `M월 d일 (요일) 리포트` — lib/format-title.ts)
- ✅ DateNavigationRow 화살표 축소 (.system size 13, weight light)
- ✅ 기간 리포트 upsert 로직 수정 (백엔드: notionPageId → 날짜 범위 기반 검색으로 중복 생성·400 오류 해결)
- ✅ 기간 리포트 저장 시트 — 노션·로컬 기존 리뷰 로드 (`fetchSavedPeriodReview`, `prepareSave`, `NotionSaveEditorView.initialComment`)
- ✅ 기간 리포트 GET `endDate` 매칭 (백엔드 Vercel 배포) — 다른 주 리뷰 표시·수정 시 중복 페이지 생성 방지
- ✅ `ReportService.findPeriodReport` endDate 유연 매칭, `resolvedNotionPageId` (데일리 pageId 오용 방지)
- ✅ 노션 투두 페이지 아이콘 (✔️ 이모지 고정, 백엔드 POST route.ts)
- ✅ 구독 해지 시 플래너 선택 팝업 + 읽기 전용 처리 (PlannerDowngradeView, isReadOnly)
- ✅ 앱 내 로그 수집 + 오류 신고 메일 (AppLogger, SupportMailView)
- ✅ 노션 카테고리 옵션 동기화 (CategoryNotionSync — 이름 병합, 노션 신규 옵션 import, 삭제/보관 분리)
- ✅ 카테고리 삭제·보관 확인 팝업 (노션 연동 플래너)
- ✅ 백엔드 `remove-select-option` / `add-select-option` (select·status, Vercel 배포)
- 🔜 StoreKit 2 구독 결제 실연동 (현재 UI만 구현됨)

**Phase 5 🔄 진행 예정** 앱스토어 출시
- 🔜 StoreKit 2 실연동 완료 후 심사 제출
- 🔜 디자인 세부 수정

---

## v1.1 백로그

### 투두 탭 할일 시간 표시
v1에서는 `scheduledTime` 설정·알림만 동작, **목록(`TodoRow`)에는 미표시**.
v1.1에서 제목 아래·메모 위에 `.caption` + `.secondary`로 `hour().minute()` 표시. 메모 보기 토글과 독립.

---

## v2 백로그

### 반복 투두 (v2 재구현)
v1 구현 시 발견된 버그: 시작일 경계 오류, 횟수 계산 오류, seriesId 생명주기 관리, Notion SyncQueue 미연결, 날짜 이동 시 동적 생성 미구현.
v2에서 처음부터 설계 재검토 후 구현 권장.
기존 `RecurringTodoManager`, `RecurringTodoEditHandler` 코드는 보존.

### 동적 속성 매핑
노션 속성 타입(text / select / relation 등)에 따라 앱 UI와 저장 방식이 달라지도록 구현.

- 현재: 속성명만 매핑 (고정 타입 가정)
- v2 목표: 속성 타입을 런타임에 읽어 UI를 동적으로 생성
  - `rich_text` → 텍스트 입력
  - `select` → 드롭다운 선택
  - `relation` → 연결된 DB 페이지 목록을 드롭다운으로 표시
  - `number`, `checkbox`, `date` 등도 타입에 맞는 입력 컴포넌트
- 사용자가 자신의 노션 DB 구조에 맞게 완전 커스텀 가능하도록

관련 파일:
- `Features/Onboarding/OnboardingViewModel.swift` — `TodoPropsMapping`, `ReportPropsMapping` 구조체
- `Features/Settings/PlannerNotionSettingsView.swift` — 속성 매핑 UI
- `Features/Settings/PlannerNotionSettingsViewModel.swift` — `autoMapTodoProps`, `autoMapReportProps`

### 노션 카테고리 DB (relation) — v2
v1.5는 투두 DB **select/status 옵션** 단위 동기화. 별도 카테고리 DB + relation 매핑은 v2 검토.

### 할일 보관 (인박스) — v2
v1 **미구현**. Notion/앱에서 완료하지 않고 날짜에서 치우는 "보관" UX는 **V2 인박스**와 함께 구현 예정. (카테고리 보관과 별개) → `V2-IDEAS.md`

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
