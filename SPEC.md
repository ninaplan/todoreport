# 투두리포트 앱 개발 스펙

> 작성일: 2026-05-26  
> 최종 업데이트: 2026-06-12 (Notion OAuth iOS 26 대응 · Safari 취소 시 isLoading 고착 수정)  
> 브랜드: 노크(Nock / nock.kr)  
> 앱명 (홈 화면): 투두리포트  
> App Store 이름: 노션품은 투두x리포트  
> 포인트 컬러: `#FD6845`

---

## 1. 제품 개요

### 핵심 철학
> "앱에서 기록하고, 노션에 쌓아가세요"

노션 유저는 데이터가 노션에 쌓이길 원한다. 통계/리포트도 노션에 저장한다.

### 타겟 사용자
- 노크 **데일리리포트 스터디 플래너** 노션 무료 템플릿 사용자
- 기타 투두 템플릿 사용자

---

## 2. 플랫폼 및 기술 스택

### 플랫폼 결정
| 플랫폼 | 결정 | 비고 |
|---|---|---|
| iOS | ✅ 네이티브 (우선 출시) | SwiftUI + Xcode |
| Android | 🔜 수요 확인 후 웹앱으로 개발 | 추후 결정 |

### 기술 스택

#### iOS 앱
| 항목 | 결정 |
|---|---|
| 언어 | Swift |
| UI 프레임워크 | SwiftUI (Liquid Glass 디자인 언어 적용) |
| IDE | Xcode |
| 최소 지원 버전 | iOS 26+ |
| 아키텍처 패턴 | MVVM |
| 로컬 저장소 | SwiftData |
| 로컬 캐시 | SwiftData + 이벤트 기반 캐시 (16절 참고) |
| 네트워크 | URLSession (자체 APIClient 래퍼) |
| 결제 | StoreKit 2 (Apple IAP) |
| 인증 | Notion OAuth (SFSafariViewController) |

#### 백엔드
| 항목 | 결정 |
|---|---|
| 프레임워크 | Next.js 14 App Router |
| 런타임 | Edge Runtime |
| 배포 | Vercel (ninaplans-projects scope) |
| Notion 호출 | 서버사이드 전용 (직접 fetch, SDK 미사용) |
| 캐싱 | 캐싱 레이어 경유 필수 |

### 전체 아키텍처

```
┌─────────────────────┐         ┌──────────────────────┐
│   iOS App           │         │   Backend            │
│   (SwiftUI + Xcode) │ ←API→  │   (Next.js + Vercel) │
│                     │         │                      │
│  - 화면/UI          │         │  - Notion API 호출   │
│  - 로컬 캐시        │         │  - OAuth 처리        │
│  - 앱 상태관리      │         │  - 리포트 생성       │
└─────────────────────┘         └──────────┬───────────┘
                                           │
                                           ↓
                                  ┌────────────────┐
                                  │  Notion API    │
                                  └────────────────┘
```

> ⚠️ **원칙: iOS 앱은 Notion API를 직접 호출하지 않는다. 반드시 Next.js 백엔드 경유.**

---

## 3. 개발 원칙

0. **모듈 독립성 제1원칙** — 기능별(UI/백엔드/StoreKit 등) 완전 독립 모듈로 구현.
   하나를 수정해도 다른 기능에 영향이 없어야 한다.
   유지보수 용이성이 모든 설계 결정의 최우선 기준.
1. **Notion API는 서버사이드에서만 호출** — 클라이언트(앱) 직접 호출 금지
2. **외부 API 호출은 반드시 캐싱 레이어 경유**
3. **기능별 완전 독립 모듈화** — 한 기능에 오류가 생겨도 다른 기능에 영향 없음
4. **Offline-First** — 모든 쓰기는 SwiftData 먼저, Notion은 SyncQueue 통해 백그라운드 전송
5. **MVP 검증 → 반응 보고 기능 확장** 순서로 진행

---

## 4. 모듈 구조 (iOS 앱)

```
TodoReport/
│
├── Core/                          # 앱 전체 기반 (신중하게 수정)
│   ├── Network/
│   │   └── APIClient.swift        # 백엔드 호출 단일 창구
│   ├── Auth/
│   │   └── NotionAuth.swift       # OAuth (SFSafariViewController)
│   └── Cache/
│       └── CacheManager.swift     # 로컬 캐싱 (SwiftData + TTL)
│
├── Features/                      # 기능별 완전 독립 모듈
│   ├── Todo/
│   │   ├── TodoView.swift
│   │   ├── TodoViewModel.swift
│   │   └── TodoService.swift
│   ├── QuickCapture/              # 빠른 캡처 (플로팅 버튼 → 시트)
│   │   ├── QuickCaptureView.swift
│   │   └── QuickCaptureViewModel.swift
│   ├── DailyReport/
│   │   ├── DailyReportView.swift
│   │   ├── DailyReportViewModel.swift
│   │   └── DailyReportService.swift
│   ├── WeeklyReport/              # 유료
│   │   ├── WeeklyReportView.swift
│   │   ├── WeeklyReportViewModel.swift
│   │   └── WeeklyReportService.swift
│   ├── MonthlyReport/             # 유료
│   │   ├── MonthlyReportView.swift
│   │   ├── MonthlyReportViewModel.swift
│   │   └── MonthlyReportService.swift
│   ├── Planner/                   # 유료 (멀티 플래너)
│   │   ├── PlannerView.swift
│   │   ├── PlannerViewModel.swift
│   │   └── PlannerService.swift
│   ├── RecurringTodo/             # 유료
│   │   ├── RecurringTodoView.swift
│   │   ├── RecurringTodoViewModel.swift
│   │   └── RecurringTodoService.swift
│   └── Category/                  # 무료 (앱 전용)
│       ├── CategoryView.swift
│       ├── CategoryViewModel.swift
│       └── CategoryService.swift
│
├── Widget/                        # 메인 앱 — 위젯 데이터 쓰기
│   └── WidgetDataProvider.swift   # App Group · refreshTodayFromStore
│
│   (Widget Extension 타겟: TodoReportWidget/)
│   ├── TodoWidgetBundle.swift / *WidgetView.swift
│   ├── TodoWidgetProvider.swift
│   └── TodoReportWidget.entitlements
│
│   (App Groups: TodoReport.entitlements + TodoReportWidget.entitlements)
│
├── Shared/                        # 공통 UI 컴포넌트
│   ├── Components/
│   │   ├── NockButton.swift
│   │   ├── NockCard.swift
│   │   └── NockTextField.swift
│   └── Theme/
│       ├── Colors.swift           # #FD6845 등 브랜드 컬러
│       ├── Constants.swift        # AppConstants (IconSize 등 전역 상수)
│       └── Typography.swift       # Nanum Square Round
│
└── App/
    ├── TodoReportApp.swift        # 앱 진입점 · onOpenURL (todoreport://todo|paywall)
    ├── MainTabView.swift          # 설정 탭 NavigationStack path
    ├── MainTabCoordinator.swift   # 탭 전환 · 위젯 딥링크
    └── TabBarAppearance.swift
```

### MVVM 역할 분리
```
View                ViewModel              Service
─────               ─────────              ───────
화면 그리기   ←→    상태 관리        ←→    API 호출
(SwiftUI)          (데이터 처리)           (네트워크)
                                               ↓
                                         APIClient (Core)
                                               ↓
                                         Next.js 백엔드
```

---

## 5. 모듈 구조 (Next.js 백엔드)

```
api/
├── auth/
│   └── notion/          # Notion OAuth 시작 + callback (302 → todoreport://)
├── ios-auth/            # 레거시 중간 페이지 (OAuth 플로우 미사용, 파일 유지)
├── notion/
│   ├── todo/            # 투두 CRUD
│   ├── daily-report/    # 데일리리포트 CRUD
│   ├── weekly-report/   # 주간 리포트 생성 + Notion 저장
│   ├── monthly-report/  # 월간 리포트 생성 + Notion 저장
│   ├── schema-manager/  # 속성 존재 확인 + 자동 추가 (NotionSchemaManager)
│   └── onboarding/      # 온보딩 전체 플로우
├── ai/
│   └── summary/         # 주간/월간 "한마디" 저장 (사용자 직접 입력)
├── planner/             # 멀티 플래너 관리
└── cache/               # 캐싱 레이어
```

---

## 6. 기능 스펙

### 6-1. 무료 기능

#### 투두 기록
- 투두 작성 → Notion 투두DB 자동 저장
- 완료 체크 → Notion 실시간 업데이트
- 카테고리 태그 (앱 전용)
- 날짜별 투두 조회
- **투두 메모** — 투두별 상세 내용 추가 (Notion 페이지 텍스트 블록으로 저장)

#### 시간 지정
- 투두 추가/편집 화면 날짜 하단에 토글 방식으로 추가
- [시간 추가] 토글 OFF → 날짜만 저장
- [시간 추가] 토글 ON → 시간 피커 표시
  - [알림] 토글 ON → 알림 시간 선택 (정시/5분 전/10분 전/30분 전/1시간 전/1일 전)
- 노션 날짜 속성에 시간 포함 저장 ("2026-06-03T07:00:00+09:00")
- 시간 없는 기존 투두는 날짜만 유지 (하위 호환)
- **v1:** 편집/캡처 시트에서만 시간 설정·표시. 투두 탭 목록에는 시간 미표시
- **v1.1:** `scheduledTime`이 있는 할일 — 투두 탭 `TodoRow`에 시간 표시 (아래 12절 백로그)

#### 투두 알림
- UNUserNotificationCenter 사용
- 시간 지정된 투두에 한해 알림 설정 가능
- 알림 시간: 정시 / 5분 전 / 10분 전 / 30분 전 / 1시간 전 / 1일 전

#### 빠른 캡처
- 모든 화면 우하단 플로팅 ＋ 버튼
- 탭 → 바텀 시트 오픈, 할일 이름 자동 포커스

**캡처 시트 입력 항목:**
```
할일 이름     (필수, 자동 포커스)
메모          (선택)
카테고리      (선택 → 앱 카테고리 목록)
날짜          (기본값: 오늘, 탭 → 달력 피커)
──────────────────────────────
반복 설정     🔒 유료
```

**저장 동작 (Offline-First):**
1. SwiftData에 즉시 저장 → 화면 바로 업데이트 (Notion 응답 기다리지 않음)
2. SyncQueue에 추가 → 백그라운드에서 Notion 전송
3. 앱 닫혀도 큐는 SwiftData에 유지 → 재실행 시 자동 처리
4. 해당 날짜 데일리리포트 relation 자동 연결 (백그라운드)

- v2: 잠금화면 위젯 / Dynamic Island (타임블로킹 기능과 함께)

#### 홈 화면 위젯

| 기능 | 무료 | Pro |
|---|---|---|
| Small — 오늘 완료율 보기 | ✅ | ✅ |
| Small — 탭하여 앱 열기 (투두 탭) | ✅ | ✅ |
| Medium — 투두 목록 보기 (읽기) | ❌ | ✅ |
| Large — 전체 목록 보기 (읽기) | ❌ | ✅ |
| 위젯에서 체크박스 탭 → 완료 처리 | ❌ | 🔜 |
| 위젯 ＋ 버튼 → 퀵캡처 시트 | ❌ | 🔜 |

**Small (2×2, 무료)**
- 오늘 완료율 %, 완료/전체 개수, 진행 바, 플래너명, 날짜 (`M월 d일`)
- 탭 → `todoreport://todo` → 투두 탭·오늘 날짜

**Medium (4×2, Pro) · Large (4×4, Pro)**
- Medium: 왼쪽 통계(완료율 32pt, 날짜 `subheadline`·`M월 d일`) + 오른쪽 투두 목록 (최대 4개, `subheadline`)
- Large: 헤더(완료율·날짜) + 진행 바 + 투두 전체 목록 (최대 8개, 중요 항목 우선)
- 미구독 시 Paywall 안내 표시, 탭 시 `todoreport://paywall`
- Pro 위젯 탭 → `todoreport://todo` → 투두 탭·오늘 날짜

**v1 탭 동작 (읽기 전용)**
- StaticConfiguration 위젯은 **영역 어디를 탭해도 앱이 열림** (할일 행 단독 체크 불가 — iOS 제약)
- `widgetURL` 미지정 시 iOS가 **마지막 화면 그대로 복원** → v1에서 Small/Medium/Large 모두 `todoreport://todo` 지정
- `MainTabCoordinator.openTodoTabFromWidget()`: 투두 탭 전환 + `pendingTodoDate` 오늘 + 설정 `NavigationStack` 초기화

**데이터 동기화 (`WidgetDataProvider`)**
- App Group ID: `group.kr.nock.TodoReport` — **TodoReport·TodoReportWidget 양쪽** entitlements + Xcode **+ Capability → App Groups** 필수
- entitlements 파일: `TodoReport/TodoReport.entitlements`, `TodoReportWidget/TodoReportWidget.entitlements`
- 갱신 시점: 투두 fetch/추가/체크/삭제, 앱 실행·포그라운드 복귀 (`refreshTodayFromStore()`), 구독·DEBUG Pro 토글 (`syncProStatus` / `refreshTodayFromStore`)
- 완료율: 오늘 **전체 투두** 기준 (앱 `hideCompleted`와 무관). 목록 표시는 `hideCompleted` 반영
- Pro 상태: `SubscriptionManager.isPro` → App Group `widgetIsPro`. DEBUG 빌드 `debugIsPro` 토글 지원
- 실패 시 `AppLogger` `[WidgetDataProvider]` 로그 (App Group 접근 실패·인코딩 실패)

**Pro 전용 인터랙션 (v1 후속, 🔜)**
- 위젯 체크박스 탭 → 즉시 완료 처리 (WidgetKit Interactive / AppIntent) + Notion 백그라운드 동기화
- 위젯 ＋ 버튼 → 앱 열리며 퀵캡처 시트 자동 오픈

**관련 파일:** `Widget/WidgetDataProvider.swift`, `TodoReportWidget/*WidgetView.swift`, `App/MainTabCoordinator.swift`, `TodoReportApp.onOpenURL`

#### 데일리 리포트
- 오늘의 한마디(하루 리뷰) 작성
- 별점 선택 (⭐~⭐⭐⭐⭐⭐) — 기분, 성취도 등 용도는 사용자가 자유롭게 정의
- 완료율 자동 계산
- Notion 데일리리포트DB 저장
- Notion 페이지 제목: `M월 d일 (요일) 리포트` (예: "6월 6일 (토) 리포트")
- 사진 첨부 기능 구조 대비 설계 (v2 구현 예정)

#### 주간 리포트 (이번 주 한정 무료)
- 오늘이 포함된 이번 주 데이터 조회 (무료)
- 완료율 그래프 (요일별 막대)
- 별점 그래프 (꺾은선, 흐름 파악)
- 카테고리별 달성률
- 이전 주 조회 및 노션 저장은 유료

#### 카테고리 관리
- SwiftData 저장 (플래너별 `plannerId`)
- 카테고리 추가/편집/삭제/보관/복원/순서 변경
- **기본값:** 색상 `#FD6845`(노크 오렌지), 아이콘 `tag.fill`
- 색상 선택 (12가지 컬러 팔레트), 아이콘 선택 (SF Symbol 팔레트)
- 투두 목록·카테고리별 보기·리포트 달성률에서 배지 표시

**노션 연동 플래너 (투두 DB `category` 속성 매핑 시):**
- 투두 DB의 **select / status** 옵션과 앱 카테고리 동기화 (`CategoryNotionSync`)
- **이름이 같으면** 자동 병합 (`notionOptionId` / `notionOptionName` 연결)
- **노션에만 있는 새 옵션** → 앱 카테고리로 자동 추가
- **이름이 다르면** 앱·노션 각각 유지 (강제 병합·설정 시트 없음)
- 동기화 시점: 카테고리 관리 진입, 투두 fetch, 앱 포그라운드 복귀, 온보딩/마이그레이션 후

**삭제 vs 보관 (노션 연동 시 확인 팝업):**

| 동작 | 앱 | 노션 |
|---|---|---|
| **삭제** | `CategoryItem` 영구 삭제, 연결 투두 `categoryId` 해제 | 연결된 카테고리면 select/status **옵션도 삭제** (`remove-select-option`) |
| **보관** | `status = archived`, 활성 목록에서 숨김, 연결 투두 `categoryId` 해제 | **옵션 유지** (앱에서만 숨김) |

- 보관 상태는 SwiftData에 영구 저장 — 앱 재실행 후에도 **자동 활성화되지 않음** (동기화 시 보관 이름·옵션 ID 예약)
- 보관 복원은 사용자가 보관 목록에서 수동 탭 시에만
- **보관 확인 alert**는 `CategoryView` 본문에 바인딩 (목록 스와이프·편집 시트 공통). 편집 시트에만 두면 스와이프 시 팝업이 뜨지 않고 `showArchiveAlert`가 true로 남아 재진입 시 오동작할 수 있음

#### 오류 신고
- 설정 탭 고객지원 섹션 → "오류 신고" 버튼
- `MFMailComposeViewController`로 메일 앱 오픈 (수신: nockcreator@gmail.com)
- 메일 본문 자동 포함 항목:
  - 앱 버전, 빌드, 기기 모델, iOS 버전, 로케일, 시간대, 타임스탬프
  - `AppLogger` 수집 로그 전문 (`Documents/app_logs.txt`)
- 로그 파일: 앱 실행마다 세션 구분선 추가, 500KB 초과 시 오래된 절반 자동 삭제

### 6-2. 유료 기능 (Apple IAP 구독)

#### 이전 기간 데이터 조회
- 이전 주 / 이전 달 데이터 조회
- 무료 사용자는 이번 주(주간 리포트)만 조회 가능, 월간 리포트는 전체 유료

#### 노션에 저장하기 (주간/월간 리포트)
- **「노션에 리포트 저장하기」** 버튼 (아이콘: `square.and.arrow.up`, 수동, 유료 전용)
- 탭 → `ReportViewModel.prepareSave()` — 노션·로컬에서 기존 리뷰 비동기 로드 (`isPreparingSave`) 후 저장 시트 표시
- 저장 시트 (`NotionSaveEditorView`, `.large`)
  - 기간 통계 (평균 완료율, 별점 평균)
  - **주간 리뷰** / **월간 리뷰** 입력 (기간 타입에 따라 라벨 분기, 구 「한마디」) — `initialComment`로 노션에 저장된 기존 리뷰 표시
  - **저장 알림 설정** 섹션 (v1, 아래 6-2-1 참고)
- 툴바: **취소**(회색) / **저장**(오렌지, 노션 저장 실행)

> **v1 UX 한계 (v1.1 개선 예정):** 저장 시트에 알림 설정과 노션 저장이 한 화면에 있어, 알림만 바꾸려 해도 「저장」= 노션 저장으로 느껴질 수 있음. v1에서는 알림 변경이 `@AppStorage`로 **즉시 반영**되며 취소해도 알림 설정은 유지됨. v1.1에서 역할 분리 검토 (아래 12절).

- 저장 전 변경사항 해시 비교
  - 변경 없으면 노션 API 호출 없이 "변경사항이 없습니다" 안내
  - 변경 있으면 기존 블록 전체 삭제 후 새 블록으로 업데이트
  - 노션 페이지 없으면 새로 생성
- **기간 리포트 페이지 식별 기준: 날짜 범위 (시작일 + 종료일)**
  - **조회:** `GET /api/notion/daily-report?date=시작일&endDate=종료일(포함)` → 기간 리포트만 반환 (`date.end != null`). `endDate` 없으면 데일리 리포트 조회
  - **저장:** `POST` body `date`(시작일) + `endDate`(종료일, 주간·월간 마지막 날 inclusive)
  - upsert 우선순위: ① `notionPageId` PATCH → ② 시작일+종료일로 Notion DB 검색 후 PATCH → ③ 신규 생성
  - iOS `findPeriodReport`: SwiftData `endDate`는 `DateInterval.end`(exclusive) 저장, inclusive 종료일 레거시도 매칭
  - 데일리 `notionPageId`가 기간 리포트에 잘못 연결된 경우 PATCH에 사용하지 않음 (`resolvedNotionPageId`)
  - 앱 재설치·노션 연동 해제·재연결·이전 주 조회 후에도 중복 페이지 생성 방지
- 리포트 본문 구성 (백엔드 `buildReportBlocks`, Notion 페이지 children):
  - Notion API에 차트/프로그레스 바 블록이 없어 **텍스트 바**(`█`/`░`, 10칸)로 표현
  - iOS → `POST /api/notion/daily-report` payload: `chartRates`, `chartRatings`, `chartCategories`, `chartReviews`
  ```
  ── 📊 완료율
  월  ████████░░  80%        ← 주간: 요일별 세로 / 월간: N주차별 세로
  화  ██████░░░░  60%
  ...

  ── ⭐ 별점
  월  ⭐⭐⭐⭐                  ← 요일·주차 라벨 + 별 아이콘 세로 (없으면 —)
  화  —

  ── 📁 카테고리별 달성률
  업무  ████████░░  80% (4/5)  ← 카테고리명 + 바 + % + (완료/전체)

  ── 📝 하루 리뷰
  [callout] 6월 3일 (화)       ← 기간 내 데일리 리뷰, 날짜(요일) + 별점 + 본문
             ⭐⭐⭐
             리뷰 텍스트...
  ```
  - **주간 리뷰 / 월간 리뷰**(사용자가 저장 시트에 입력)는 DB 속성(`reviewProp`)에 저장 — 본문 callout과 별개
  - 기간 리뷰 callout 날짜 라벨: `formatReviewDateLabel` (`M월 d일 (요일)`)
- 현재 보고 있는 주/월 기준으로 저장
- 이전 기간 저장도 가능 (유료 사용자는 과거 기간 조회/저장 모두 가능)

#### 6-2-1. 주간/월간 리포트 저장 알림

> iOS는 트리거 없이 백그라운드 자동 Notion 저장이 불가능하다. v1은 **리마인더 알림**, v1.2는 **알림 액션으로 원탭 저장**을 제공한다.

##### v1 (출시 범위)

저장 시트(`NotionSaveEditorView`) 하단 **저장 알림** 섹션:

| UI | 동작 |
|---|---|
| 알림 켜기 토글 | OFF 기본. ON 시 로컬 알림 스케줄 등록 |
| footer | 기기 **설정 > 투두리포트 > 알림**이 허용되어 있어야 알림이 울립니다 |
| 알림 시간 (토글 ON 시만 표시) | DatePicker (시·분) |
| 주간 추가 UI | 요일 Picker (시작 요일 설정 반영) |
| 월간 추가 UI | **1일 / 말일** Picker + 시간 |

**스케줄 규칙 (v1):**
- Pro + 노션 연결 + 알림 ON일 때만 등록
- **주간:** 지난 주 종료 후, 사용자가 설정한 요일·시간 (시작 요일 설정 반영)
- **월간:** 지난 달 종료 후 — **1일** 또는 **말일** + 사용자 시간
- 알림 탭 → 앱 실행 → 사용자가 저장 시트에서 직접 저장 (기존 수동 플로우)
- **포그라운드:** `AppNotificationDelegate`가 `report-save-reminder-*` 알림도 배너 표시

**설정 저장:** `@AppStorage` (`ReportNotificationSettings`). 토글·시간 변경 시 **즉시 저장** (노션 저장 버튼과 무관).

**알림 문구 (v1):**
- 제목: `주간/월간 리포트 저장 시간`
- 본문: `지난 주/달을 정리하고 노션에 저장해보세요.` (월간 말일: `이번 달을…`)

##### v1.2 (후속 업데이트)

알림 본문에 **액션 버튼 2개** 추가. 앱 미실행 상태에서도 동작 목표.

| 액션 | 동작 |
|---|---|
| **앱으로 가기** | 앱 포그라운드 → 리포트 탭 → 저장 시트 |
| **바로 저장하기** | 백그라운드에서 `ReportService.savePeriodReport()` 호출, **리뷰는 빈 문자열** (A안) |

**v1.2 구현 요건:**
- `ReportNotificationManager` (신규) — 기간 종료 알림 등록/갱신
- `UNUserNotificationCenterDelegate` — 액션 핸들러
- `UNNotificationCategory` + `UNNotificationAction` 2개
- 알림 `userInfo`: `periodType`, `startDate`, `plannerId` 등
- 저장 시점 SwiftData에서 completionRate·chartData 재계산
- 이미 저장된 기간 스킵, Pro/노션 미연결 시 미등록

**v1.2 예상 공수:** ~1.5~2일 (v1 알림 스케줄링 완료 후)

##### v1 vs v1.2 요약

| | v1 | v1.2 |
|---|---|---|
| 알림 리마인der | ✅ | ✅ |
| 알림에서 바로 저장 | ❌ | ✅ (리뷰 없이) |
| 알림에서 앱 열기 | ✅ (탭 기본 동작) | ✅ (전용 액션) |

#### 6-2-2. StoreKit 2 실연동 (v1)

| 항목 | 값 |
|---|---|
| 월간 Product ID | `kr.nock.todoreport.pro.monthly` |
| 연간 Product ID | `kr.nock.todoreport.pro.yearly` |
| 가격 (한국, ASC) | 월 ₩4,900 / 연 ₩33,000 |
| 구현 | `SubscriptionManager` (StoreKit 2), `PaywallView` / `PaywallViewModel` |
| 로컬 테스트 | `TodoReport.storekit` + Scheme StoreKit Configuration |
| Sandbox 테스트 | ASC 동기화 `.storekit` 또는 Scheme **None** + Sandbox 계정 |
| Archive/TestFlight | Scheme StoreKit 설정 **무시** — ASC Sandbox/Production |

**필수 ASC 조건:** 유료 앱 계약 Active, 구독 **제출 준비 완료**, In-App Purchase capability, Paid Applications Agreement·세금·은행.

**설정 탭:** 구독 복원 결과 알림, Pro 시 **구독 관리** (`AppStore.showManageSubscriptions`).

**관련 파일:** `Core/Subscription/SubscriptionManager.swift`, `TodoReport.storekit`, `Features/Subscription/PaywallView.swift`

#### 멀티 플래너
- 플래너 1개 = 투두DB 1개 + 데일리리포트DB 1개 묶음
- 무료: 플래너 1개 / 유료: 무제한
- 메인 화면 상단 드롭다운으로 플래너 전환

#### 구독 해지 시 플래너 처리
- 구독 만료 감지 시 플래너가 2개 이상이면 `PlannerDowngradeView` 시트 표시
- 사용자가 유지할 플래너 1개 선택 → 나머지는 `isReadOnly = true` (데이터 보존, 편집 차단)
- `.interactiveDismissDisabled()` — 선택 전 시트 닫기 불가
- 재구독 시 `restoreAllPlanners()` → 전체 플래너 `isReadOnly = false` 자동 복원
- isReadOnly 플래너: 설정 탭에서 잠금 아이콘 + "Pro 구독 시 다시 활성화됩니다" 표시

#### 반복 투두
- 반복 주기: 매일 / 평일만(월~금) / 주말만(토~일) / 매주 요일 선택 / 격주 / 매월 / 매년
- 시간 지정과 연계 (시간 지정된 투두에 알림 반복 적용)
- 노션에 반복 일정대로 자동 생성

#### 다른 날 투두 확인
- 날짜 피커로 원하는 날짜 선택 → 해당 날짜 투두 목록 조회
- 무료: 어제·오늘·내일 3일 접근 가능 / 유료: 모든 날짜 조회 가능
- 과거 날짜 투두 완료 처리도 가능 (Notion 실시간 업데이트)

---

## 7. Notion DB 구조

### 데일리리포트 DB 속성
| 속성명 | 타입 | 추가 방식 | 비고 |
|---|---|---|---|
| 날짜 | date | 기존 | 일간: 단일 / 주간·월간: 기간 |
| 완료율 | formula | 기존 | 일간 전용 (기존 수식 유지) |
| 완료율_앱 | number | 온보딩 자동 추가 | 주간/월간 전용 |
| 하루 리뷰 | text | 기존 | |
| 별점 | select | 앱 자동 추가 | ⭐/⭐⭐/⭐⭐⭐/⭐⭐⭐⭐/⭐⭐⭐⭐⭐, 없으면 NotionSchemaManager가 추가 |
| 사진URL | text | v2 구현 시 추가 | 외부 스토리지 URL 저장 (구조 대비) |
| To-do List | relation → 투두DB | 기존 | |
| 완료/할일 | formula | 기존 | "N개 할일 중 N개 완료 🔥" |

### 투두 DB 속성
| 속성명 | 타입 | 비고 |
|---|---|---|
| 완료 | checkbox | |
| 중요 | checkbox | isPinned 연동. 없으면 NotionSchemaManager 자동 추가 |
| 날짜 | date | |
| 메모 | text | 투두 상세 내용. 앱에서 입력 시 Notion 페이지 텍스트 블록으로 저장 |
| 데일리 리포트 | relation → 데일리리포트DB | |
| 시간표 | relation | v2 타임블로킹 연동 |
| 알림 | formula | v2 타임블로킹 연동 시 활성화 |

### Notion 뷰 필터
- 데일리리포트DB에서 일간만 표시: "날짜 종료일이 비어있음"

---

## 8. 온보딩 흐름

```
① 웰컴 소개 (5페이지 TabView)
   · 1~4페이지: AppLogoSticker 또는 SF Symbol 라인 아이콘 (.primary, 다크모드 대응)
   · 5페이지(마지막): AppLogoSticker + link + NotionLogo 정적 연결 아이콘 (애니메이션 없음)
          ↓
② 노션 연결 여부 선택 (마지막 웰컴 페이지)
   · 주 버튼: 노션 연결하기 (검정 캡슐) / 보조: 나중에 연결하기 (텍스트)
   · 모든 페이지 동일한 주 버튼 Y 위치 (보조 행 placeholder 44pt)
          ↓                    ↓
③-A 노션 OAuth 진행      ③-B 로컬 모드 (SwiftData)
   플래너 이름 입력          "데이터가 이 기기에만
   투두DB 선택               저장됩니다. 기기 변경 시
   데일리리포트DB 선택        데이터를 불러올 수 없어요."
   필수 속성 자동 추가              ↓
          ↓               LocalRepository 사용
④ 초기 데이터 fetch (노션 연결 시, 최근 7일) — `NotionConnectionGraphic` 오버레이
⑤ 완료
```

> 별도 앱 계정 로그인(Sign in with Apple 등) 없음. Notion OAuth는 노션 연결 시에만 진행.

**Notion OAuth 플로우 (`NotionAuthManager`, ✅ 2026-06-12):**

```
앱 startOAuth()
  → SFSafariViewController: GET /api/auth/notion?state=...
  → Notion 로그인·승인
  → Notion → GET /api/auth/notion/callback?code=...
  → 백엔드 HTTP 302 직접 리다이렉트:
       성공: todoreport://auth/callback?access_token=...&workspace_id=...
       실패: todoreport://auth/error?reason=...
  → delegate initialLoadDidRedirectTo (todoreport:// 감지)
       → Safari dismiss → handleCallback → secondaryOAuthCompletion(token)
```

- **iOS 26 대응:** SFSafariViewController에서 JavaScript로 커스텀 URL 스킴을 열 수 없어, 백엔드가 `/ios-auth` 중간 페이지를 거치지 않고 `todoreport://`로 **직접 302**한다 (`app/api/auth/notion/callback/route.ts`).
- **`/ios-auth` 페이지:** OAuth 경로에서는 더 이상 사용하지 않음. 파일(`app/ios-auth/page.tsx`)은 삭제하지 않고 유지.
- **Safari 사용자 취소:** `safariViewControllerDidFinish`에서 `NotionAuthManager.isLoading = false`, `oAuthCancelledCompletion?()` 호출.
- **온보딩:** `OnboardingViewModel.startNotionOAuth()`가 `secondaryOAuthCompletion`과 함께 `oAuthCancelledCompletion`을 등록해 Safari 중간 종료 시 `isLoading` 고착 방지.

**관련 파일:** `Core/Auth/NotionAuth.swift`, `Features/Onboarding/OnboardingViewModel.swift`, `todoreport-backend/app/api/auth/notion/callback/route.ts`

**노션 DB 목록 조회 (`NotionDatabasesFetcher`):**
- 공통 모듈 — 온보딩·플래너 추가·마이그레이션·노션 설정
- HTTP 상태 확인, 빈 목록 시 자동 재시도(2·3·5초), 새로고침 시 ID 병합
- OAuth 직후 선행 fetch 없음 — DB 선택 화면에서만 fetch
- `isLoadingDatabases` / 속성 로딩 상태 분리 (우상단 새로고침·`PlannerAddViewModel` 재조회 보장)

**노션 연동 로딩 UI (`NotionConnectionGraphic`):**
- 투두리포트(`AppLogoSticker`) ↔ 노션(`NotionLogo`) + 점 펄스 애니메이션 (좌→우·우→좌 교대, 활성 점 `Color.primary`)
- 사용처: 온보딩 초기 fetch, 플래너 마이그레이션 진행 중 (`NotionSyncingOverlay` 컴포넌트 갱신, 투두 탭 미연결)

**필수 속성 자동 추가 (노션 연결 시):**
- 완료율_앱 (number)
- 별점 (select, ⭐~⭐⭐⭐⭐⭐) — 없을 경우에만

## 8-1. 계정 구조

| 구분 | 인증 | 데이터 저장 | 구독 관리 |
|---|---|---|---|
| 노션 사용자 | Notion OAuth | Notion DB | Apple IAP |
| 로컬 사용자 | 없음 (앱만 사용) | SwiftData (기기) | Apple IAP |

> 별도 앱 계정 로그인 없음. Notion OAuth는 노션 연결 선택 시에만 필요.
> Apple IAP 구독이 Apple ID에 묶이므로 기기 변경 후에도 구독 복원 가능.
> 로컬 사용자는 설정에서 언제든 노션 연결 가능 (연결 시 데이터 마이그레이션 안내).

## 8-4. Offline-First & SyncQueue

모든 쓰기 작업은 SwiftData에 먼저 저장하고 Notion은 백그라운드 동기화.

```
저장 요청
    ↓
SwiftData 즉시 저장 → 화면 즉시 업데이트
    ↓
SyncQueue에 작업 추가
    ↓
백그라운드 Notion 전송
(인터넷 없으면 대기 → 연결 시 자동 처리)
(앱 닫혀도 큐는 SwiftData에 유지)
(재실행 시 미처리 큐 자동 처리)
```

**SyncQueue 작업 타입:**
| 타입 | 설명 |
|---|---|
| createTodo | 투두 생성 + 데일리리포트 relation 연결 |
| updateTodo | 완료 체크, 제목 수정 등 |
| createDailyReport | 해당 날짜 데일리리포트 없을 시 생성 |
| updateDailyReport | 별점, 리뷰 저장 |
| createWeeklyReport | 주간 리포트 Notion 저장 |

**실패 처리:**
- 재시도 최대 3회
- 3회 실패 시 사용자에게 알림 "동기화 실패한 항목이 있어요"
- 수동 재시도 버튼 제공

> 로컬 사용자는 SyncQueue 없이 SwiftData만 사용.

> DataRepository 프로토콜 상세 → 15절 참고.

## 8-3. NotionSchemaManager 패턴

속성이 있을 수도 없을 수도 있는 경우를 일관되게 처리하는 백엔드 유틸리티.

```
앱 실행 or 데일리리포트 첫 진입
          ↓
백엔드: Notion DB 속성 목록 확인
          ↓
       ┌──┴──┐
    없음      있음
     ↓          ↓
사용자 안내   바로 사용
"다음 속성을 추가할게요:
 별점"
     ↓
  확인 클릭
     ↓
속성 + 옵션 자동 생성
(PATCH /databases/{id})
```

- 사용자가 거부하면 해당 기능 비활성화 (UI에서 회색 처리)
- 새 템플릿 사용자는 속성이 이미 있으므로 이 단계 스킵
- 기존 사용자만 자동 추가 플로우 진행

### 자동 추가 대상 속성

**데일리리포트DB**

| 속성명 | 타입 | 추가 조건 |
|---|---|---|
| 완료율_앱 | number | 없을 경우 자동 추가 |
| 별점 | select (⭐~⭐⭐⭐⭐⭐) | 없을 경우 자동 추가 |

**투두DB**

| 속성명 | 타입 | 추가 조건 |
|---|---|---|
| 메모 | text | 없을 경우 자동 추가 |
| 중요 | checkbox | 없을 경우 자동 추가 |

## 8-2. DailyReport 데이터 모델

```swift
struct DailyReport {
    let id: String
    let date: Date
    let review: String           // 하루 리뷰 (텍스트)
    let completionRate: Double   // 완료율
    let dayRating: DayRating?    // 별점, 속성 없으면 nil
    let photoURLs: [String]      // 기본값 [] — v2 사진 기능 대비 자리 확보
}

enum DayRating: String, CaseIterable {
    case one   = "⭐"
    case two   = "⭐⭐"
    case three = "⭐⭐⭐"
    case four  = "⭐⭐⭐⭐"
    case five  = "⭐⭐⭐⭐⭐"
}
```

백엔드 속성 매핑 (notion-mapper.ts):

```typescript
const DAILY_REPORT_PROPERTIES = {
    review:     "하루 리뷰",
    dayRating:  "별점",   // select 속성 (⭐~⭐⭐⭐⭐⭐)
    photoURLs:  "사진URL",     // text 속성 — v2 구현 전까지 미사용, 자리만 확보
}
```

> ✅ Notion 속성명이 바뀌면 이 파일만 수정. iOS 앱 코드 변경 불필요.

## 8-5. Category 데이터 모델

```swift
enum CategoryStatus: String, Codable {
    case active    // 활성 (기본값)
    case archived  // 보관됨
    case completed // v2: 목표 달성 완료 (Notion 프로젝트 DB 연동 시 사용)
}

struct Category: Identifiable, Codable {
    let id: String
    var name: String
    var colorHex: String        // 기본값 #FD6845
    var icon: String            // 기본값 tag.fill
    var status: CategoryStatus  // 기본값 .active
    var plannerId: String?
    var notionOptionId: String?   // 노션 select/status 옵션 ID
    var notionOptionName: String? // 노션 옵션 표시명
}
```

### 카테고리 삭제·보관 동작

**삭제 (영구):**
- `CategoryItem` SwiftData에서 삭제
- 연결된 투두의 `categoryId` 해제
- 노션 연동 + `isLinkedToNotion`이면 백엔드 `remove-select-option`으로 노션 옵션 삭제
- 확인 팝업 (노션 연동·연결된 경우): 노션 플래너 옵션도 함께 삭제된다는 안내

**보관 (앱에서만 숨김):**
- `status = .archived` — 재실행 후에도 유지, 동기화로 자동 활성화되지 않음
- 활성 목록에는 `status == .active`만 표시, 보관 섹션에 별도 표시
- 연결 투두 `categoryId` 해제, **노션 옵션은 유지**
- 노션 연동 플래너: 보관 시 확인 팝업 — 「앱에서만 숨김, 노션에는 유지」
- 미완료 할일이 있으면 개수 안내 문구 추가
- 확인 alert는 `CategoryView` 루트에 바인딩 (`CategoryEditSheet` 전용 금지 — 스와이프 보관 미동작·alert 상태 잔류 버그)

**복원:** 보관 목록 탭 → `status = .active` (수동만, 확인 팝업 없음)

### Notion 프로젝트/목표 DB 연동 (v2)

추후 Notion 연동 시 `CategoryStatus` → Notion 속성 매핑:

| CategoryStatus | Notion 속성값 |
|---|---|
| active | 진행중 |
| archived | 보관됨 |
| completed | 완료 |

아이콘 팔레트 (25종):

| 그룹 | SF Symbol |
|---|---|
| 공부/학습 | book.fill, pencil, graduationcap.fill, brain.head.profile, note.text |
| 운동/건강 | figure.run, dumbbell.fill, heart.fill, bicycle, leaf.fill |
| 업무/생산성 | briefcase.fill, doc.text.fill, chart.line.uptrend.xyaxis, clock.fill, flag.fill |
| 생활 | house.fill, cart.fill, fork.knife, car.fill, creditcard.fill |
| 취미/기타 | music.note, paintbrush.fill, camera.fill, star.fill, gamecontroller.fill |

> 로컬 전용 플래너: 카테고리는 SwiftData만 사용. 노션 연동 플래너: 투두 DB `category` select/status와 옵션 단위 동기화 (8-5-1).

### 8-5-1. 노션 카테고리 옵션 동기화 (v1.5)

**전제:** 플래너 `todoPropsMapping.category`에 select 또는 status 속성이 매핑됨.

**동기화 규칙 (`CategoryNotionSync.syncCategoriesByName`):**
1. 노션 옵션 목록 fetch (`GET .../databases/{id}/properties`)
2. 앱 활성·미연결 카테고리 ↔ 노션 옵션 **이름 일치** 시 `notionOptionId` 연결
3. 노션에만 있는 옵션 → 앱에 새 `CategoryItem` insert (연결 정보 포함)
4. 보관(`archived`)된 이름·이미 연결된 `notionOptionId`는 재병합·재import 제외

**투두 ↔ 노션:**
- 쓰기: 연결된 카테고리만 `categoryName`을 SyncQueue payload에 포함
- 읽기: `applyCategoryFromNotion` — 활성 카테고리 이름/노션옵션명으로 `categoryId` 매칭

**백엔드 API (todoreport-backend):**
| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/api/notion/databases/{id}/properties` | select/status 옵션 목록 (`selectOptions`) |
| POST | `/api/notion/databases/{id}/add-select-option` | 옵션 추가 (select·status) |
| POST | `/api/notion/databases/{id}/remove-select-option` | 옵션 삭제 (select·status) |

**iOS 관련 파일:** `Core/Notion/CategoryNotionSync.swift`, `Features/Category/CategoryService.swift`

**제거된 v1.5 시도 (미사용):** 1회 연결 설정 시트, 앱 사용 토글(`isEnabledInApp`), 이름 자동 일괄 import 설정 UI

---

## 9. 네비게이션 구조

### 탭 구성 (3개)

| 탭 | 아이콘 | 포함 기능 |
|---|---|---|
| 투두 | 체크리스트 | 데일리 리포트 + 투두 목록 + 다른 날 투두 확인 |
| 리포트 | 차트 | 이번 주/이번 달 데이터 (완료율·별점·카테고리 달성률), 이전 기간 조회(유료), 노션 저장(유료) |
| 설정 | 기어 | 플래너 관리, 앱 설정, 카테고리, 구독, 계정 |

### 탭·딥링크 동작 (v1)

| 상황 | 동작 |
|---|---|
| 위젯 탭 (`todoreport://todo`) | 투두 탭 + 오늘 날짜. 설정 하위 화면(플래너 상세 등) 스택 초기화 |
| 위젯 Paywall (`todoreport://paywall`) | Paywall 시트 |
| 다른 탭 → **설정 탭** 재진입 | `NavigationStack` **루트(설정 목록)** 로 초기화 — 플래너 상세 등 이전 화면 유지 안 함 |
| 리포트 날짜 행 탭 | `MainTabCoordinator.openTodo(on:)` → 투두 탭 해당 날짜 (설정 스택 초기화 없음) |

> 설정 탭만 `MainTabView`에서 `NavigationStack(path:)` 관리. `settingsStackResetToken`으로 위젯 진입 시에도 스택 리셋.

### 투두 탭 — 네비게이션 바

```
┌─────────────────────────────────┐
│ 수능 공부 ▼               ☰   │
└─────────────────────────────────┘

좌측: 플래너 이름 탭 → 플래너 전환 목록 (유료: 2개 이상)
우측: ☰ 탭 → 보기 옵션 슬라이드 다운
```

### 보기 옵션 — 슬라이드 다운 드롭다운

☰ 탭하면 네비게이션 바 아래로 패널 슬라이드 내려옴.
바깥 탭하면 닫힘. 항목 탭해도 패널 유지 (복수 선택 가능).

```
┌─────────────────────────────────┐
│ 수능 공부 ▼               ☰   │
├─────────────────────────────────┤
│  ✓ 완료 숨기기                  │  ← 탭으로 토글
│    할일 메모 보기               │  ← 탭으로 토글 (기본값: 꺼짐)
│    정렬 옵션              ›     │  ← 탭하면 하위 뷰로 전환
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
  투두 목록 (흐릿하게)...
```

> 카테고리 필터는 투두 목록 상단 칩으로 이동. 보기 옵션에서 제거.

> **[확정] 카테고리 필터 칩 스타일 (탭바 방식)**
> - 전체 바 하단에 1pt `Color(.separator)` 구분선 가로 전체 표시
> - 선택된 칩 아래만 2.5pt `Color(.label)` 두꺼운 선 오버레이
> - 미선택 칩: 회색 텍스트, 개별 라인 없음
> - 배경/테두리 없음 — 텍스트 + 하단 라인만

**할일 메모 보기 동작:**
- 기본값: 꺼짐 (메모 숨김)
- 켜면: 메모가 있는 투두에 한 줄 미리보기 표시

```
꺼짐 (기본):                        켜짐:
┌─────────────────────────────┐     ┌─────────────────────────────┐
│  ○  수학 문제 풀기           │     │  ○  수학 문제 풀기           │
│  ○  영어 단어 30개          │     │       p.132~145, 틀린 것 복습│  ← 메모 한 줄
│  ○  독서 30분               │     │  ○  영어 단어 30개          │
└─────────────────────────────┘     │  ○  독서 30분               │
                                    └─────────────────────────────┘
```

> 메모가 없는 투두는 켜짐 상태에서도 추가 줄이 표시되지 않음.

> **v1.1 예정 — 할일 시간 표시 (목록)**
> - `scheduledTime != nil`일 때만 표시. **할일 메모 보기 토글과 무관** (시간은 항상 표시)
> - 위치: 제목 아래 · 메모 위 (`.caption` + `.secondary`, `hour().minute()` 포맷)
> - 예: `○ 아침 달리기` → 다음 줄 `07:00` / 메모 켜짐 시 `07:00` → `속성 매핑`
> - v1에서는 목록에 시간 없음 (편집 시트에서만 확인)

정렬 옵션 › 탭 시:

```
┌─────────────────────────────────┐
│  ‹ 정렬 옵션                    │
│  ● 추가한 순서                  │
│  ○ 카테고리순                   │
│  ○ 완료 먼저                    │
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

### 투두 탭 — 화면 구조

```
┌─────────────────────────────────┐
│ 수능 공부 ▼               ☰   │  ← 네비게이션 바
├─────────────────────────────────┤
│                                 │
│  ‹  📅 2026년 5월 26일  ›      │  ← 좌우 공간 탭: 하루 이동
│     (흐릿한 화살표 힌트)        │    날짜 탭: 달력 피커
│                                 │
│  완료율 ████████░░ 80%         │  ← 선택된 카테고리 기준으로 계산
│  (v2) ⏱ 집중타임 합계: 2h 30m  │
│                                 │
│  별점  ⭐⭐⭐⭐☆               │
│  리뷰  "오늘도 잘 했다"         │
├─────────────────────────────────┤
│ [전체] [수학] [영어] [독서] … → │  ← 카테고리 필터 칩 (가로 스크롤)
│                                 │    전체: 모든 투두 + 배지 표시
│                                 │    카테고리: 해당 투두만 + 배지 숨김
├─────────────────────────────────┤
│  ☑ 수학 문제 풀기               │  ← 체크박스 탭: 완료/미완료
│  ☑ 영어 단어 30개              │    우로 스와이프(풀스와이프): 고정
│  ☐ 독서 30분                   │    좌로 스와이프: 내일하기/날짜변경/삭제
│                                 │    롱프레스: 편집
│  + 투두 추가                    │
└─────────────────────────────────┘
```

> 완료율은 현재 선택된 카테고리 필터 기준으로 계산된다. 전체 선택 시 전체 투두 기준.

> **[확정] 완료율·별점·리뷰 카드 스타일**
> - 날짜 행 바로 아래 단일 흰색 카드로 통합 (완료율 → 별점 → 리뷰 순)
> - 배경 `Color(.secondarySystemGroupedBackground)`, `RoundedRectangle(cornerRadius: 16, style: .continuous)`
> - 테두리 0.5pt `Color(.separator)`, 그림자 없음
> - 좌우 margin 16pt (리스트 행 insets), 리스트 배경 `Color(.systemGroupedBackground)`

> 카테고리 필터 선택 상태에서 인라인 "+ 투두 추가" 또는 플로팅 + 버튼으로 투두 추가 시, 선택된 카테고리가 자동 지정된다.

> **[확정] 인라인 투두 입력 폰트**
> - 입력 중: `AutoFocusTextField(textStyle: .body)` — 투두 행 `Text(.body)`와 동일, Dynamic Type 연동
> - 한글 IME 자모음 분리 방지를 위해 UIKit `UITextField` 사용 (SwiftUI `TextField` 대체 불가)
> - 행 높이: `frame(minHeight: 36)` — 접근성 글자 크기 확대 시 잘림 방지

### 날짜 이동 규칙

| 동작 | 기능 | 유료 여부 |
|---|---|---|
| 날짜 좌측 공간 탭 | 이전 날 | 유료 |
| 날짜 우측 공간 탭 | 다음 날 | 유료 |
| 날짜 텍스트 탭 | 달력 피커 모달 | 유료 |
| 화면 스와이프 | ❌ 사용 안 함 | — |
| 힌트 | 양옆 흐릿한 화살표 ‹ › | — |

> 무료 사용자는 어제·오늘·내일 3일 접근 가능. 그 외 날짜 탭 시 유료 안내 표시.

### 투두 아이템 제스처

| 동작 | 기능 |
|---|---|
| 탭 (체크박스 영역) | 완료/미완료 토글 |
| 탭 (텍스트/행 영역) | 아무것도 안 함 |
| 오른쪽 스와이프 (풀스와이프) | 고정(isPinned 토글) |
| 왼쪽 스와이프 | 내일하기 / 날짜변경 / 삭제 |
| 길게 누르기 | 편집 모드 (제목 수정, 카테고리 변경) |

**중요 투두 표시 (v1):** `isPinned == true`일 때 제목 옆 **「중요」** 태그 (`ImportantTodoTag`) — 핀 아이콘 대신 텍스트 배지, 포인트 컬러 배경.

### 리포트 탭 — 화면 구조

```
┌─────────────────────────────────┐
│  주간 ●  월간 ○                 │  ← 기간 토글 (무료)
├─────────────────────────────────┤
│  ‹🔒  5월 25일 — 5월 31일       │  ← 이번 주/월: 무료
│       (이번 주 · 이번 달 고정)  │    ‹ 이전 기간 이동: 유료
├─────────────────────────────────┤
│  완료율 72%     별점 평균 ⭐⭐⭐⭐│  ← 무료
│  🔥 연속 달성 5일               │
│  (v2) ⏱ 집중시간 14h 20m        │
├─────────────────────────────────┤
│  [ 완료율 그래프 ] ← 무료        │
│  주간: 요일별 막대              │
│  월간: 주차별 막대              │
├─────────────────────────────────┤
│  [ 별점 그래프 ] ← 무료          │
│  주간/월간: 꺾은선 (흐름 파악)  │
├─────────────────────────────────┤
│  [ 카테고리별 달성률 ] ← 무료    │
│  수학  ████████░░  80%  ›       │  ← 탭: 드릴다운
│  영어  █████░░░░░  50%  ›       │
│  독서  ███░░░░░░░  30%  ›       │
├─────────────────────────────────┤
│  [ 하루 리뷰 타임라인 ] ← 무료  │
│  6월 5일 (금)  ⭐⭐⭐            │  ← 날짜 행 탭 → 투두 탭 해당 날짜
│  오늘도 열심히...               │  ← 리뷰 본문: 최대 3줄, 시스템 … (탭 불가)
│  6월 6일 (토)  ⭐⭐⭐⭐           │
├─────────────────────────────────┤
│  [ square.and.arrow.up 노션에 리포트 저장하기 🔒 ] ← 유료  │
│  (탭 → 저장 시트: 통계 + 주간/월간 리뷰 + 저장 알림 설정)   │
└─────────────────────────────────┘
```

| 기능 | 무료 | 유료 |
|---|---|---|
| 이번 주 주간 리포트 조회 | ✅ | — |
| 완료율·별점·카테고리 그래프 (주간) | ✅ | — |
| 이전 주 조회 | ❌ | ✅ |
| 월간 리포트 전체 | ❌ | ✅ |
| 노션에 저장하기 | ❌ | ✅ |
| Small 위젯 (완료율) | ✅ | — |
| Medium·Large 위젯 (목록) | ❌ | ✅ |

#### 하루 리뷰 타임라인 동작 (v1)

| 요소 | 동작 |
|---|---|
| 리뷰 텍스트 | 최대 3줄 + 시스템 말줄임(`…`). 탭·더보기 없음 |
| 날짜 행 탭 | `MainTabCoordinator.openTodo(on:)` → 투두 탭 해당 날짜로 이동 |
| 무료 사용자 + 범위 밖 날짜 탭 | `ReportView`에서 알림: **Pro 알아보기** / **확인** (카드 내부 아님) |

> `DayTodoDetailView`는 제거됨. 리뷰에서 투두 목록으로의 별도 드릴다운 없음.

#### 연속 달성 (Streak)

| 항목 | 내용 |
|---|---|
| 계산 기준 | **어제까지** 연속 일수 (오늘 미포함) |
| 설정 위치 | 설정 > 환경 설정 > **연속 달성 기준** Picker |
| 옵션 | 중요 할 일 모두 완료 / 전체 할 일 완료(기본) / 할 일 1개 이상 완료 |
| 저장 | `@AppStorage("streakCriteria")` — `StreakCriteria` |

### 주간 기준 정의

| 설정 | 주간 범위 | Notion 저장 기간 |
|---|---|---|
| 월요일 시작 (기본값) | 월 ~ 일 | 2026-05-25 ~ 2026-05-31 |
| 일요일 시작 | 일 ~ 토 | 2026-05-24 ~ 2026-05-30 |

> 시작 요일 설정은 주간 리포트 날짜 범위, 달력 표시, 알림 타이밍 모두에 영향.

### 설정 탭 — 화면 구조

```
┌─────────────────────────────────┐
│  [ 구독 ]                       │
│  현재 플랜      무료 / Pro      │
│  구독 관리 (Pro)         ›     │
│  구매 복원               ›     │
├─────────────────────────────────┤
│  [ 플래너 ]                     │
│  플래너 목록 · 추가 (유료)  ›   │
├─────────────────────────────────┤
│  [ 환경 설정 ]                  │
│  시작 요일      월요일     ›    │
│  연속 달성 기준  전체 완료  ›   │
│  알림           허용됨  ↗     │  ← 시스템 설정 앱으로 이동
├─────────────────────────────────┤
│  [ 고객지원 ]                   │
│  개인정보처리방침 / 이용약관 ›  │
│  오류신고 / 피드백       ›     │
├─────────────────────────────────┤
│  [ 앱 정보 ]                    │
│  버전 / 빌드                    │
└─────────────────────────────────┘
```

> **v1 변경:** 앱 내 **언어 선택** 항목 제거 (시스템/앱 언어는 별도 설정). 주간 리포트 알림은 저장 시트(`NotionSaveEditorView`)에서 설정 — 설정 탭에는 시스템 알림 권한 링크만 표시.

### 완료율 계산 원칙

> 완료율 계산 주체 및 저장 원칙 → 17절 참고.

### i18n (다국어) 처리 원칙

- 지원 언어: 한국어(기본) / English — **앱 UI 영어는 v2** (String Catalog, 20절·리팩토링 TODO 참고)
- **App Store 메타:** 한국어 확정 (20절). English (U.S.) 로컬은 스토어 등록용 문구만 v1 출시 시 등록 가능 (앱 UI와 별개)
- v2 영어 UI 영향 범위: UI 전체 텍스트, 자동 생성 리포트 문구, 알림 문구
- Notion 속성명은 언어 설정과 무관하게 한국어 고정
  (속성명을 바꾸면 기존 사용자 데이터 연결이 끊어지기 때문)

---

## 10. 결제 구조 (Apple IAP)

| 항목 | 내용 |
|---|---|
| 결제 방식 | Apple IAP (StoreKit 2) |
| 수수료 | 수익의 30% Apple 지급 (연간 구독 갱신 시 15%) |
| 구독 형태 | 월간 구독 + 연간 구독 (동시 출시) |
| Product ID | `kr.nock.todoreport.pro.monthly`, `kr.nock.todoreport.pro.yearly` (상세: 6-2-2절) |
| 연간 할인 | 월간 대비 약 20~30% 할인 표시 권장 |
| 무료 기능 제한 | 플래너 1개, 어제·오늘·내일 3일, 이번 주 주간 리포트만, Small 위젯(완료율) |
| 유료 기능 | 이전 기간 주간·월간 리포트, 멀티 플래너, 반복 투두, 3일 외 날짜 조회, Medium·Large 위젯, 위젯 인터랙션(체크·＋) |
| 구매 복원 | Restore Purchases 필수 구현 |

> ⚠️ **앱스토어 필수 요건:** Privacy Policy + Terms of Service 페이지 필요

---

## 11. 디자인 시스템

| 항목 | 값 |
|---|---|
| 디자인 언어 | Liquid Glass (iOS 26 네이티브) |
| 포인트 컬러 | `#FD6845` |
| 폰트 | Nanum Square Round |
| 최소 지원 | iOS 26+ |

### 아이콘 크기 상수 (AppConstants.IconSize)

모든 SF Symbol 크기는 `AppConstants.IconSize`의 상수를 사용한다. 직접 수치 입력 금지.

| 상수 | 값 | 사용처 |
|---|---|---|
| `menu` | 14pt | 팝오버·메뉴 아이콘 |
| `listRow` | 20pt | 목록 행 아이콘 |
| `badge` | 16pt | 배지 내부 아이콘 |

### 탭 바·알림 버튼 색 (v1)

| 규칙 | 내용 |
|---|---|
| Tab bar 선택 색 | `TabBarAppearance.applyNockAccent()` — UIKit `UITabBarAppearance` |
| 금지 | `MainTabView` 루트 `.tint(accent)` — alert **취소** 버튼까지 오렌지로 오염됨 |
| 시트 툴바 | 취소 `.foregroundStyle(.secondary)`, 저장 `.foregroundStyle(AppTheme.shared.accent)` |
| Alert | 시스템 기본 색 유지 (`.tint` 오염 방지) |

**관련 파일:** `App/TabBarAppearance.swift`, `App/MainTabView.swift`, `TodoReportApp.onAppear`

---

## 12. 보류 / 향후 검토 기능

| 기능 | 상태 | 이유 |
|---|---|---|
| 집중타이머 / 포모도로 | v2 | 투두 탭 완료율 옆 "집중타임 합계" 자리 미리 확보. 기능 추가 시 해당 위치에 붙임 |
| 타임블로킹 + 투두 알림 | v2 | 시간표 relation 이미 Notion DB에 있음. 타임블로킹 기능 추가 시 시간 기반 푸시 알림 함께 구현 |
| 잠금화면 위젯 / Dynamic Island | v2 | 빠른 캡처 레벨 3. 타임블로킹과 함께 검토 |
| 노션 프로젝트DB 연동 | v2 | 유료 기능으로 검토 |
| Android 앱 | 수요 확인 후 | 웹앱으로 개발 예정 |
| 사진 첨부 (데일리리포트) | v2 | 구조 대비 설계 완료. 스토리지 방식 결정 후 구현 |
| iCloud 백업 / 기기 이동 | v2 유료 | 로컬 사용자 데이터 보호. Repository 패턴으로 구조 대비 완료 |
| 로컬 ↔ 노션 데이터 마이그레이션 | v2 유료 | 로컬 → 노션 전환 시 기존 데이터 이전 |
| Apple Reminders 연동 | v2 | 사용자 피드백 후 결정 |
| 리포트 알림 원탭 저장 (알림 액션) | v1.2 | v1은 리마인더만. v1.2에서 「앱으로 가기」「바로 저장하기」액션 추가 |
| 노션 저장 시트 UX (알림·저장 분리) | v1.1 | v1: 툴바 저장=노션 저장, 알림은 `@AppStorage` 즉시 반영. v1.1: 취소=알림 되돌리기, 확인=알림만 저장, 「노션에 저장하기」를 리뷰 카드 하단으로 이동 검토 |
| 투두 탭 할일 시간 표시 | v1.1 | v1: 목록 미표시. v1.1: `TodoRow` 제목 아래 `scheduledTime` (`caption`/`secondary`, 메모 토글 독립). 선택: `alarmOffset` 있을 때 `bell` 아이콘 |
| 리포트 자동 저장 (BGTask) | v2 | iOS 백그라운드 제약. v1.2 알림 액션 저장으로 1차 해결 후 검토 |
| 연간 리포트 진입 위치 | 미결정 | A: 리포트 탭 하단 버튼 / B: 설정 탭 / C: 네비게이션 바 메뉴 |

---

## 13. 개발 우선순위 (MVP)

```
Phase 1 (핵심 기반)
  - Notion OAuth 연동
  - APIClient 구현 (Core/Network)
  - 온보딩 플로우

Phase 2 (무료 기능)
  - 투두 기록 → Notion 저장
  - 데일리 리포트
  - 카테고리 관리

Phase 3 (유료 기능)
  - Apple IAP StoreKit 2 연동 ✅ (Sandbox 검증, 6-2-2절)
  - 주간/월간 리포트 ✅
  - 멀티 플래너 ✅
  - 반복 투두 (v2 연기)
  - 다른 날 투두 확인 ✅
  - 홈 화면 위젯 ✅ (Small 무료 · Medium/Large Pro, App Group, 딥링크, Medium UI)

Phase 4 (출시, 진행 중)
  - App Store 메타데이터 확정 ✅ (20절)
  - 앱 아이콘 제작 🔜
  - App Store 스크린샷 촬영 🔜
  - App Store Connect 등록 · 심사 제출 🔜
  - Privacy Policy / Terms of Service ✅ (nock.kr)
```

---

## 14. 데이터 모델 상세

### TodoItem

```swift
struct TodoItem: Identifiable, Codable {
    // 📱 로컬 전용 (SwiftData)
    let id: String              // 앱 내부 UUID (Notion ID 아님)
    var title: String           // 할일 이름 (Notion 페이지 제목)
    var isCompleted: Bool       // 완료 여부
    var date: Date              // 날짜
    var scheduledTime: Date?    // 시간 지정 (없으면 nil)
    var alarmOffset: Int?       // 알림 시간 (분 단위, 0=정시 -5=5분전 -60=1시간전. 없으면 nil)
    var recurrence: RecurrenceRule?  // 반복 규칙 (없으면 nil)
    var memo: String?           // 메모 (없으면 nil)
    var categoryId: String?     // 카테고리 ID (없으면 nil, 앱 전용)
    let createdAt: Date         // 생성 시각 — 정렬용, 로컬 전용 (Notion에 저장 안 함)

    // 🔄 노션 동기화용
    var notionPageId: String?   // Notion 페이지 ID (로컬 사용자는 nil)
    var syncStatus: SyncStatus  // 동기화 상태
}

enum SyncStatus: String, Codable {
    case pending  // SwiftData 저장 완료, Notion 전송 대기 중
    case synced   // Notion 동기화 완료
    case failed   // 재시도 3회 실패
}

enum RecurrenceRule: Codable {
    case daily
    case weekdays              // 평일 월~금
    case weekends              // 주말 토~일
    case weekly([Weekday])     // 매주 요일 선택
    case biweekly([Weekday])   // 격주
    case monthly
    case yearly
}
```

#### Notion 투두DB 속성 매핑

| Swift 필드 | Notion 속성 | 타입 | 비고 |
|---|---|---|---|
| title | 제목 | title | Notion 페이지 제목 |
| isCompleted | 완료 | checkbox | |
| date + scheduledTime | 날짜 | date | scheduledTime 있으면 시간 포함 ISO 8601로 저장 |
| alarmOffset | — | — | 로컬 전용, UNUserNotificationCenter 알림 시간 |
| recurrence | — | — | 로컬 전용, 반복 규칙 |
| memo | 메모 | text | **없는 사용자 있음 → NotionSchemaManager 자동 추가** |
| — | 데일리 리포트 | relation | SyncQueue가 자동 연결 (15절 참고) |
| — | 시간표 | relation | v2, 앱에서 건드리지 않음 |
| — | 알림 | formula | v2, 앱에서 건드리지 않음 |
| createdAt | — | — | 로컬 전용, Notion에 저장 안 함 |
| categoryId | 카테고리 (매핑 시) | select / status | 앱 SwiftData ID. 노션에는 **연결된 카테고리의 옵션명**으로 저장 (`categoryName` payload) |
| isPinned | 중요 | checkbox | 없는 사용자는 NotionSchemaManager 자동 추가 |

#### TodoPropsMapping 저장 형식

플래너별 `todoPropsMapping` JSON에 **속성명 + Notion property ID**를 함께 저장한다.

| 앱 필드 | 저장 키 (이름) | 저장 키 (ID) |
|---|---|---|
| 완료 | `completed` | `completedPropId` |
| 날짜 | `date` | `datePropId` |
| 메모 | `memo` | `memoPropId` |
| 상단고정 | `isPinned` | `isPinnedPropId` |
| 리포트 연결 | `reportRelation` | `reportRelationPropId` |
| 카테고리 | `category` | `categoryPropId` (+ `categoryPropType`) |

- Notion API 호출 시에는 **속성명**을 payload에 사용 (백엔드·Notion SDK 관례)
- 앱 내부 복원·구분에는 **property ID를 우선** — 동일 DB에 checkbox 등 같은 유형 속성이 여러 개일 때 이름·유형만으로는 구분 불가

#### 속성 자동 매핑 규칙 (v1, `TodoPropsMappingAutoFill`)

온보딩·DB 변경·설정 재진입 시 속성 목록을 가져온 뒤 매핑을 채운다. **모드에 따라 동작이 다름.**

| 모드 | 사용처 | 동작 |
|---|---|---|
| `initialSetup` | 온보딩, DB 변경, 플래너 추가/마이그레이션 | 빈 필드만 자동 채움 |
| `preserveUser` | 플래너 노션 설정 재진입 (`PlannerNotionSettingsView`) | **사용자가 저장한 값 유지** — fetch만으로 덮어쓰지 않음 |

**공통 resolve 우선순위 (`resolveStandard`):**
1. 저장된 **property ID**로 속성 조회 → 이름 동기화
2. 저장된 **속성명**으로 조회 → ID 보강
3. `preserveUser` + 기존 값 있음 → **휴리스틱·폴백 스킵**, 기존값 유지
4. `initialSetup`만: 기본명 일치(`완료`, `날짜` 등) 또는 단일 후보 `first` 폴백

**checkbox 전용 규칙 (`resolveCheckbox` — 완료·상단고정):**

| 규칙 | 내용 |
|---|---|
| 식별 기준 | **property ID 우선** — `completedPropId`, `isPinnedPropId` |
| 동일 유형 다수 | checkbox가 여러 개여도 **`first` 폴백 금지** — `완료`/`isCompleted`와 `중요`/`isPinned`가 같은 첫 checkbox로 붙는 버그 방지 |
| 자동 매핑 허용 | 기본명 **정확 일치**만 (`완료`, `중요`) — 유형만 같다고 첫 번째를 고르지 않음 |
| `preserveUser` | **저장된 property ID가 있으면 절대 덮어쓰지 않음** — Notion에서 속성명이 바뀌었을 때만 이름 동기화 |

**`reportRelation`(데일리 리포트 relation) 특별 규칙:**
- 속성명 **`데일리 리포트`** 와 **정확히 일치**할 때만 자동 매핑
- relation 속성이 1개뿐이어도 **`first` 폴백 금지** — 다른 relation(시간표 등)과 혼동 방지
- 앱 전용 데일리 리포트·리포트 DB 미연결 사용자 보호

**설정 화면 수동 선택 (`PlannerNotionSettingsView`):**

| UI | ViewModel | 동작 |
|---|---|---|
| 완료 Picker | `selectCompletedProperty(id:name:)` | 선택 즉시 `completed` + `completedPropId` 동시 갱신 |
| 상단고정 Menu | `selectIsPinnedProperty(id:name:)` | 선택·「앱에만 저장」 즉시 `isPinned` + `isPinnedPropId` + `isPinnedMode` 갱신 |

- Picker는 표시용으로 **속성명**을 tag로 사용하지만, setter/`onPropertySelect`에서 **ID를 즉시 기록** — `backfillIds`만 믿지 않음 (저장·refresh 전 타이밍 공백 방지)
- `fetchTodoProperties` 후에도 `backfillIds`로 ID↔이름 일관성 보강
- `save()` 직전 `backfillIds` 1회 더 호출 (레거시 이름-only 매핑 마이그레이션)

**관련 파일:** `Core/Notion/TodoPropsMappingAutoFill.swift`, `Features/Settings/PlannerNotionSettingsViewModel.swift`, `Features/Settings/PlannerNotionSettingsView.swift`, `OnboardingViewModel.swift`

---

## 15. 아키텍처 상세

### DataRepository 프로토콜

ViewModel은 저장 위치(Notion / SwiftData)를 몰라도 된다.
DataRepository 프로토콜만 바라본다.

```swift
protocol DataRepository {

    // MARK: - 투두
    func fetchTodos(date: Date) async throws -> [TodoItem]
    func createTodo(_ todo: TodoItem) async throws
    func updateTodo(_ todo: TodoItem) async throws  // 완료체크 / 제목 / 메모 / 카테고리 / 날짜 변경 포함
    func deleteTodo(id: String) async throws

    // MARK: - 데일리리포트
    func fetchDailyReport(date: Date) async throws -> DailyReport?
    func saveDailyReport(_ report: DailyReport) async throws

    // MARK: - 카테고리
    func fetchCategories() async throws -> [Category]
    func createCategory(_ category: Category) async throws
    func updateCategory(_ category: Category) async throws
    func archiveCategory(id: String) async throws  // 소프트 삭제 (status = .archived)
}
```

### Repository 구현체

```
DataRepository (protocol)
  ├── NotionRepository    ← 노션 연결 사용자
  │     투두/리포트: SyncQueue 통해 Notion 동기화
  │     카테고리: SwiftData + 투두 DB select/status 옵션 동기화 (CategoryNotionSync)
  │     v2: 별도 카테고리 DB(relation) 연동 검토
  └── LocalRepository     ← 로컬 모드 사용자
        투두/리포트/카테고리: SwiftData 직접 읽기/쓰기
        SyncQueue 없음
  (└── iCloudRepository)  ← v2
```

### 카테고리 v2 확장 경로

v1.5에서 투두 DB select/status 옵션 동기화를 지원한다. v2에서는 Notion **별도 카테고리 DB**(relation) 연동을 검토.
DataRepository 프로토콜로 추상화되어 있으므로 **ViewModel / View 코드 변경 없이**
NotionRepository 내부 구현만 교체하면 된다.

```
v1: ViewModel → DataRepository.fetchCategories()
                        ↓
                NotionRepository 내부: SwiftData에서 읽어옴

v2: ViewModel → DataRepository.fetchCategories()  ← 변경 없음
                        ↓
                NotionRepository 내부: Notion 프로젝트DB에서 읽어옴
```

v2 전환 시 작업 범위:
- NotionRepository의 카테고리 메서드 구현만 교체
- CategoryStatus → Notion 속성 매핑은 8-5절 참고
- ViewModel, View, DataRepository 프로토콜 변경 없음

### MVVM + Repository 전체 흐름

```
View
  ↓ (사용자 액션)
ViewModel
  ↓ (DataRepository 프로토콜 호출)
  ├── NotionRepository
  │     ↓
  │   SwiftData 즉시 저장 → 화면 업데이트
  │     ↓
  │   SyncQueue → 백그라운드 Notion 전송
  │
  └── LocalRepository
        ↓
      SwiftData 즉시 저장 → 화면 업데이트
```

---

## 16. 데이터 동기화 전략

### 기본 원칙: 이벤트 기반 (타이머 기반 아님)

타이머로 주기적으로 자동 갱신하지 않는다.
아래 이벤트가 발생할 때만 Notion에서 새로 가져온다.

| 이벤트 | Notion fetch 여부 |
|---|---|
| 앱 처음 열 때 | ✅ 오늘 날짜 fetch |
| 백그라운드 갔다가 복귀 | ✅ 오늘 날짜 fetch |
| 처음 보는 날짜로 이동 | ✅ 해당 날짜 fetch |
| 이미 캐시 있는 날짜로 이동 | ❌ 캐시 그대로 사용 |
| 사용자가 Pull to Refresh | ✅ 현재 날짜 fetch |
| 앱 켜놓고 있는 동안 자동 | ❌ 하지 않음 |

### 캐시 정책

- 한 번 fetch한 날짜 데이터는 그 세션 동안 캐시 유지
- 앱을 껐다 켜면 (새 세션) 오늘 날짜는 다시 fetch
- 과거 날짜는 앱 껐다 켜도 캐시 유지 (과거 데이터는 잘 바뀌지 않음)
- Pull to Refresh로 언제든 수동 갱신 가능

### 충돌 해결 원칙: Notion = Source of Truth

앱 SwiftData는 캐시다. Notion에서 가져온 데이터로 언제든 덮어써질 수 있다.

**상황 A: 앱에 pending 항목 있는데 Notion에서도 수정됨**
```
pending 항목 먼저 Notion에 push → 그 다음 fetch
결과: 앱에서 마지막 수정한 값이 최종값
```

**상황 B: 앱 캐시 있는데 Notion에서 직접 수정됨 (앱은 모름)**
```
다음 fetch 이벤트 발생 시 → Notion 최신값으로 SwiftData 덮어씀
결과: Notion 수정값이 앱에 반영됨
```

- syncStatus: `.pending` 항목은 push 완료 전까지 덮어쓰지 않는다
- v2에서 고려: 진짜 충돌 감지 (양쪽 동시 수정) — MVP 미구현

### 데일리리포트 relation 연결 (SyncQueue 처리)

투두 생성 시 해당 날짜 데일리리포트와 relation 연결은 앱이 SyncQueue를 통해 관리한다.

```
투두 생성
  ↓
SwiftData 즉시 저장 → 화면 즉시 업데이트
  ↓
SyncQueue에 createTodo 추가
  ↓
백그라운드 실행:
  해당 날짜 데일리리포트 Notion에서 조회
  ├── 있으면 → 투두와 relation 연결
  └── 없으면 → 데일리리포트 먼저 생성 → relation 연결
```

**로컬 사용자의 DailyReport:**
- 로컬 사용자도 SwiftData에 DailyReport 객체 저장 (리포트 탭 표시 필요)
- relation 연결 로직은 생략, SyncQueue 없음

---

## 17. 완료율 계산 원칙

| 완료율 종류 | 계산 주체 | 저장 위치 | 용도 |
|---|---|---|---|
| 화면 표시 완료율 | 앱 로컬 계산 | 저장 안 함 | 실시간 화면 업데이트 |
| Notion formula (완료율) | Notion 자동 계산 | Notion DB | 앱에서 읽지도 쓰지도 않음 |
| 완료율_앱 (number) | 앱 계산 후 PATCH | Notion DB | 주간/월간 리포트 저장 시에만 (유료) |

- 화면 완료율: 선택된 카테고리 필터 기준으로 계산
- **Notion 저장 시 완료율은 항상 전체 투두 기준** — 카테고리 필터 상태 무관
- Notion의 `완료율` formula: 관계형 연결 시 자동 계산, 앱이 건드리지 않음

---

## 18. 플래너 전환 시 상태 규칙

| 상태 항목 | 전환 시 동작 | 저장 위치 | 이유 |
|---|---|---|---|
| 선택된 날짜 | **유지** | 메모리 | 같은 날 두 플래너 비교가 자연스러움 |
| 카테고리 필터 | **"전체"로 초기화** | 메모리 | 플래너마다 카테고리가 다를 수 있음 |
| 완료 숨기기 | **유지 (전역)** | UserDefaults | 취향 설정, 플래너별 다를 필요 없음 |
| 할일 메모 보기 | **유지 (전역)** | UserDefaults | 취향 설정, 플래너별 다를 필요 없음 |
| 정렬 옵션 | **유지 (전역)** | UserDefaults | 취향 설정, 플래너별 다를 필요 없음 |

---

## 19. 로컬 플래너 노션 연결 플로우

로컬 플래너의 "노션 플래너와 연결하기" 버튼 탭 시 진입.
(설정 > 플래너 상세 > Notion 연동 섹션)

### 19-1. UX 플로우

```
"노션 플래너와 연결하기" 탭
  ↓
[Alert] 로컬 데이터를 어떻게 할까요?
  ┌─────────────────────────────────────────┐
  │  노션에 함께 저장하기   버리고 시작하기  │
  └─────────────────────────────────────────┘
  ↓                              ↓
  uploadToNotion 모드             importFromNotion 모드
         ↓                              ↓
         └─────────┬────────────────────┘
                   ↓
         Notion OAuth 진행 (Safari)
                   ↓
         투두 DB 선택
                   ↓
         투두 속성 매핑 (완료 여부·날짜 필수, 메모·상단고정·리포트 연결 선택)
                   ↓
         리포트 DB 선택 (건너뛰기 가능)
                   ↓
         리포트 속성 매핑 (날짜 필수, 하루 리뷰·별점 선택)
                   ↓
         자동 실행 (`NotionConnectionGraphic` + 프로그레스 오버레이)
```

### 19-2. 데이터 처리 옵션

| 옵션 | 동작 | 주의 |
|---|---|---|
| **노션에 함께 저장하기** | 로컬 투두·리포트를 Notion에 업로드. 로컬 데이터 보존. 투두는 SyncQueue enqueue, 리포트는 직접 API 호출. | 이전에 연동한 적 있는 플래너는 중복 데이터가 생길 수 있음 |
| **버리고 시작하기** | 노션 연결 검증 후 로컬 데이터 삭제, 노션에서 최근 7일 데이터 가져오기 | 로컬 삭제 전 반드시 연결 검증 — 실패 시 로컬 데이터 보존 |

### 19-3. 동기화 범위

- **importFromNotion**: 오늘 기준 최근 **7일** (온보딩·플래너 추가와 동일)
- 이전 구현(30일)에서 변경

### 19-4. 실패 처리

| 실패 시점 | 동작 |
|---|---|
| OAuth 전 | 연결 미진행, 로컬 데이터 무변경 |
| 연결 검증 실패 (importFromNotion) | `.failed` 표시, 로컬 데이터 보존 |
| 루프 중 네트워크 끊김 (importFromNotion) | `.failed` 표시, "다시 시도" 허용 |
| uploadToNotion 리포트 전체 실패 | `.failed` 표시, "확인"만 (투두는 SyncQueue 자동 재시도) |
| 실행 중 | 취소 불가 (`.interactiveDismissDisabled`) |

---

## 20. App Store 출시 메타데이터 (확정, 2026-06-09)

### 20-1. 이름 체계

| 구분 | 문구 | 비고 |
|---|---|---|
| **App Store 이름** | 노션품은 투두x리포트 | 30자 이내, `x`는 한글 가독성용 (투두 / 리포트 구분) |
| **App Store 부제** | 앱에서 기록하고, 노션에 쌓아가세요 | 제품 슬로건과 동일. 검색어 나열 금지 |
| **홈 화면 표시 이름** | 투두리포트 | `CFBundleDisplayName` (Xcode) |
| **번들 ID** | `kr.nock.TodoReport` | 변경 없음 |
| **마케팅 버전** | 1.0 | |

> **이름 설계 원칙:** App Store 이름 앞에 「노션 연동」을 두지 않음 — 로컬 모드 단독 사용 가능한 앱이므로 연동 필수처럼 보이면 안 됨. 노션 관련 검색(`연동`, `자동저장`)은 **키워드 필드**에서 처리.

### 20-1-1. 아이콘 에셋 (3종, 디자이너 원본 그대로)

| 에셋 | 경로 | 원본 | 사용처 |
|---|---|---|---|
| **App Icon** | `AppIcon.appiconset/AppIcon.png` | 흰 배경 1024×1024 | 홈 화면, App Store, 설정, Spotlight, 알림 |
| **App Logo Sticker** | `AppLogoSticker.imageset/AppLogoSticker.png` | 스티커 테두리 1024×1024 (투명) | 온보딩 웰컴 1페이지 |
| **App Logo Plain** | `AppLogoPlain.imageset/AppLogoPlain.png` | 테두리 없음 1024×1024 (투명) | 앱 내 UI (필요 시) |
| **Notion Logo** | `NotionLogo.imageset/NotionLogo.png` | 노션 공식 마크 | 연동 로딩 UI, 온보딩 마지막 페이지 |

> **1024×1024 원본을 리사이즈·가공 없이** 각 imageset에 배치. 스티커 테두리는 코드 후처리하지 않음.

### 20-2. 키워드 (100자, App Store Connect)

이름·부제에 없는 검색어 위주. **`데일리리포트` 필수 포함.**

```
데일리리포트,할일,플래너,데일리,주간,월간,위젯,완료율,자동저장,연동,동기화,notion,todo,daily,report,planner,widget,sync
```

*(99자 — 쉼표 구분, 공백 없음)*

| 키워드 | 검색 의도 |
|---|---|
| 데일리리포트, 데일리 | `노션 데일리리포트` 등 |
| 할일, 플래너 | 투두 대체 검색 |
| 주간, 월간 | 기간 리포트 |
| 자동저장, 연동, 동기화 | 노션 연동 의도 (이름·부제엔 없음) |
| notion, todo, daily, report… | 영문 검색 |

### 20-3. App Store 설명 (한국어)

```
노션품은 투두x리포트는 할 일을 기록하고, 데일리·주간·월간 리포트로 하루와 한 주·한 달을 돌아볼 수 있는 투두 & 리포트 앱입니다.

앱만으로도 모든 기능을 사용할 수 있어요. 원하시면 노션을 연결해 투두와 리포트를 노션에 자동 저장할 수도 있습니다.

■ 이렇게 사용해요
· 투두 · 할일 — 오늘 할 일을 빠르게 기록
· 데일리 리포트 — 완료율, 별점, 하루 리뷰
· 주간 · 월간 리포트 — 기간별 돌아보기 (Pro)
· 노션 저장 — 연결하면 투두·리포트가 노션 DB에 자동 동기화
· 카테고리 · 플래너 — 용도별로 구분 (Pro)
· 홈 화면 위젯 — 완료율·투두 목록 (Pro)
· 빠른 캡처 — 떠오른 할 일 즉시 기록

■ 이런 분께 추천해요
· 할일 앱과 데일리리포트를 하나로 쓰고 싶은 분
· 앱은 가볍게 쓰고, 기록은 노션에 쌓고 싶은 분
· 노션 투두·데일리 리포트를 자동으로 정리하고 싶은 분

■ 안내
· 노션 연동은 Notion OAuth를 통해 이루어집니다.
· Notion 공식 앱이 아닌, 노크(Nock)의 서드파티 연동 앱입니다.
· 일부 기능(주간·월간 리포트, 멀티 플래너, Medium·Large 위젯 등)은 Pro 구독이 필요합니다.
```

**홍보용 문구 (Promotional Text, 검색 무관·수시 수정 가능):**

```
v1 출시 — 노션에 자동 저장되는 투두 & 데일리 리포트. 지금 다운로드하고 오늘 할 일부터 노션에 쌓아 보세요.
```

### 20-4. English (U.S.) 로컬라이제이션 (App Store)

> 앱 UI 영어는 **v2** (String Catalog). App Store 메타는 출시 시점에 미리 등록 가능.  
> 영어 이름에는 `x` 미사용 (`&`, `for Notion` 패턴).

| 필드 | 문구 |
|---|---|
| **이름** | Todo & Report for Notion |
| **부제** | Record in the app, save to Notion |
| **키워드** | `dailyreport,daily,notion,todo,report,planner,widget,sync,journal,review,weekly,monthly,task,habit,checklist` |

### 20-5. 스크린샷 캡션 (App Store Connect용)

| # | 캡션 |
|---|---|
| 1 | 할일 기록부터 데일리리포트까지 |
| 2 | 완료율 · 별점 · 하루 리뷰 |
| 3 | 주간 · 월간 리포트로 돌아보기 |
| 4 | 원하면 노션에 자동 저장 |
| 5 | 홈 화면 위젯으로 확인 |

### 20-6. 출시 전 체크리스트 (미완)

| 항목 | 상태 |
|---|---|
| App Store 메타데이터 (이름·부제·키워드·설명) | ✅ 확정 |
| 앱 아이콘 1024×1024 (+ Dark / Tinted) | ✅ `AppIcon.appiconset` — 흰 배경 원본 |
| 온보딩 로고 (스티커) | ✅ `AppLogoSticker.imageset` |
| 앱 로고 (테두리 없음) | ✅ `AppLogoPlain.imageset` |
| `CFBundleDisplayName` = 투두리포트 (Xcode) | ✅ |
| App Store 스크린샷 (6.7" 필수) | 🔜 |
| App Store Connect 앱 레코드 생성 | 🔜 |
| Privacy Policy / Terms URL | ✅ nock.kr |
| StoreKit 실연동 · Sandbox 검증 | ✅ (6-2-2절) |

---

*이 문서는 개발 진행에 따라 업데이트됩니다.*

---

## 리팩토링 TODO

### Notion OAuth iOS 26 · Safari 취소 (✅ 2026-06-12)
- **문제 1:** iOS 26 `SFSafariViewController`에서 JavaScript `window.location = todoreport://...`가 동작하지 않아 OAuth 완료 후 앱 복귀 실패
- **해결 1:** 백엔드 callback이 `/ios-auth` 중간 페이지 대신 `todoreport://auth/callback` / `todoreport://auth/error`로 **HTTP 302 직접 리다이렉트**
- **문제 2:** 사용자가 OAuth 중 Safari 시트를 닫으면 `NotionAuthManager.isLoading`·온보딩 `isLoading`이 `true`로 고착
- **해결 2:** `safariViewControllerDidFinish` + `oAuthCancelledCompletion` — 온보딩 `startNotionOAuth()`에서 취소 콜백 등록
- 관련: `NotionAuth.swift`, `OnboardingViewModel.swift`, `todoreport-backend/app/api/auth/notion/callback/route.ts`

### TodoService → DataRepository 패턴 통합 (v1 후반 또는 v2)
- 현재: TodoService가 SwiftData + SyncQueue를 직접 사용
- 목표: ViewModel → RepositoryFactory.make() → NotionRepository/LocalRepository 단일 경로로 통합
- 이유: 현재 DataRepository 프로토콜과 TodoService 두 패턴이 병렬 존재 → 장기적으로 혼란
- 작업 범위: TodoViewModel, DailyReportViewModel 등 Service 직접 참조 → Repository 참조로 교체

### UserDefaults 키 정리
- 현재: "notionConnected", "isNotionConnected" 혼재
- 목표: 단일 키로 통일, AppConstants에 상수로 관리
- 관련 파일: OnboardingViewModel.swift, SyncQueueManager.swift

### 카테고리 보관 alert 바인딩 (v1 ✅)
- 문제: 보관 확인 alert가 `CategoryEditSheet`에만 있어 목록 스와이프 보관이 동작하지 않고 `showArchiveAlert`가 true로 남음 → 재진입·편집 시트 오픈 시 팝업 즉시 표시
- 해결: alert를 `CategoryView` 본문으로 이동, `cancelArchive()` / `confirmArchive()`에서 `showArchiveAlert = false` 명시
- 관련 파일: `CategoryView.swift`, `CategoryViewModel.swift`

### 기간 리포트 노션 본문 포맷 (v1 ✅)
- 백엔드 `buildReportBlocks`: 완료율·카테고리 = 텍스트 바 세로 목록, 별점 = 라벨+⭐ 세로, 하루 리뷰 = callout (`formatReviewDateLabel`)
- iOS `PeriodReportChartData.reviews` → `chartReviews` payload
- 관련 파일: `todoreport-backend/app/api/notion/daily-report/route.ts`, `ReportService.swift`, `ReportViewModel.swift`

### 리포트 저장 알림 (v1 ✅)
- v1: 저장 시트 내 알림 토글 + 시간·요일·월간(1일/말일) 설정, `ReportNotificationManager` 로컬 리마인더
- 포그라운드 배너: `AppNotificationDelegate`
- v1.2: `UNNotificationAction` — 「앱으로 가기」「바로 저장하기」(리뷰 빈 문자열)
- 관련 파일: `Core/Notifications/ReportNotificationManager.swift`, `ReportNotificationSettings.swift`, `AppNotificationDelegate.swift`

### 기간 리포트 노션 저장 시트 · 조회/upsert (✅ 2026-06-08)
- 문제: 저장 시트가 빈 리뷰로 시작, 다른 주 노션 리뷰 미표시, 수정 저장 시 노션에 중복 페이지 생성
- 원인: 백엔드 GET이 `endDate` 무시·데일리만 반환, 로컬 `endDate` 불일치로 기존 기간 항목 미매칭
- 해결:
  - iOS `fetchSavedPeriodReview` / `syncPeriodReportFromNotion` — 노션 연결 시 GET 동기화 후 시트에 표시
  - 백엔드 GET·`findPeriodReportInNotion` — `endDate`로 기간 리포트 매칭
  - iOS `findPeriodReport` 유연 매칭, `resolvedNotionPageId`, 데일리 리뷰 오염 방지
- 관련: `ReportService.swift`, `ReportViewModel.swift`, `NotionSaveEditorView`, `todoreport-backend/.../daily-report/route.ts`

### 홈 화면 위젯 v1 (✅ 2026-06-08)
- 무료/Pro: Small 무료, Medium·Large Pro (`isPro` → App Group `widgetIsPro`)
- App Group entitlements + `refreshTodayFromStore()` (앱 실행·포그라운드 시 투두 탭 미진입 갱신)
- 완료율 전체 투두 기준, `todoreport://todo` 딥링크, 설정 탭 NavigationStack 재진입 시 루트 초기화
- Medium UI: 폰트·날짜(`M월 d일`) 가독성 개선
- 🔜 인터랙티브 체크·＋ 버튼
- 관련: `WidgetDataProvider.swift`, `TodoReportWidget/`, `MainTabCoordinator.swift`, `MainTabView.swift`

### 속성 자동 매핑 버그 수정 (v1 ✅)
- **문제 1:** 설정 재진입 시 `autoMapTodoProps()`가 `reportRelation` 등 저장값을 덮어씀
- **해결 1:** `TodoPropsMappingAutoFill` + `preserveUser` 모드 (14절 참고)
- **문제 2:** 투두 DB에 checkbox 속성이 여러 개(완료·중요·기타)일 때 `allowFirstFallback`으로 **첫 번째 checkbox**에 `completed`와 `isPinned`가 동시 매핑됨
- **해결 2:** `resolveCheckbox` 도입 — checkbox는 property ID 우선, 동일 유형 `first` 폴백 금지, `preserveUser`에서 저장된 ID 절대 덮어쓰기 금지
- **문제 3:** 설정 Picker가 속성명만 갱신하고 ID는 `save()`/`backfillIds` 시점까지 비어 있어 refresh 타이밍에 잘못 복원될 수 있음
- **해결 3:** `PlannerNotionSettingsView` 완료 Picker·상단고정 Menu → `selectCompletedProperty(id:name:)` / `selectIsPinnedProperty(id:name:)` 즉시 호출
- 관련: `TodoPropsMappingAutoFill.swift`, `PlannerNotionSettingsViewModel.swift`, `PlannerNotionSettingsView.swift`

### 영어 로컬라이제이션 (v2)
- 현재: 앱 전체 한국어 하드코딩, `Localizable.strings` 없음
- 목표: Xcode String Catalog(`.xcstrings`) 도입, 한국어/영어 지원
- 작업 범위: 전체 View의 `Text("한국어")` → `String(localized:)` 교체 + 영어 번역
- v1: 설정 탭 언어 선택 **미노출** (시스템 언어 따름). v2에서 설정 항목 추가 검토
- 타겟 사용자 반응 확인 후 v2에서 진행

### 별점/기분 속성 옵션 매핑
- 현재: iOS DayRating(⭐~⭐⭐⭐⭐⭐)을 Notion select 옵션값으로 그대로 전송
- 문제: 사용자마다 Notion select 옵션명이 다름 (별이 아닌 숫자, 텍스트 등)
- 해결 방향: 온보딩 속성 매핑 시 별점 1~5에 해당하는 Notion 옵션값을 사용자가 직접 매핑
- 관련 파일: OnboardingViewModel.swift, DailyReportService.swift, ReportPropsMapping
