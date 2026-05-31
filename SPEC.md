# 투두리포트 앱 개발 스펙

> 작성일: 2026-05-26  
> 브랜드: 노크(Nock / nock.kr)  
> 앱명: 투두리포트  
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
| 인증 | Notion OAuth (ASWebAuthenticationSession) |

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
│   │   └── NotionAuth.swift       # OAuth (ASWebAuthenticationSession)
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
├── Widget/                        # 홈 화면 위젯 (별도 Extension Target)
│   ├── TodoWidgetBundle.swift     # 위젯 진입점
│   ├── SmallWidget.swift          # 2×2: 완료율 + ＋ 버튼
│   ├── MediumWidget.swift         # 4×2: 투두 목록 + 체크박스
│   ├── LargeWidget.swift          # 4×4: 전체 목록
│   └── WidgetDataProvider.swift   # 앱과 데이터 공유 (App Group)
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
    └── TodoReportApp.swift        # 앱 진입점
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
│   ├── notion/          # Notion OAuth 처리
│   └── callback/        # OAuth 콜백
├── notion/
│   ├── todo/            # 투두 CRUD
│   ├── daily-report/    # 데일리리포트 CRUD
│   ├── weekly-report/   # 주간리포트 생성 + Notion 저장
│   ├── monthly-report/  # 월간리포트 생성 + Notion 저장
│   ├── schema-manager/  # 속성 존재 확인 + 자동 추가 (NotionSchemaManager)
│   └── onboarding/      # 온보딩 전체 플로우
├── ai/
│   └── summary/         # 주간/월간 "한마디" AI 초안 자동 생성 (언어 설정 반영)
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

- 홈 화면 위젯 ＋ 버튼 → 앱 열리며 캡처 시트 자동 오픈
- v2: 잠금화면 위젯 / Dynamic Island (타임블로킹 기능과 함께)

#### 홈 화면 위젯
- Small (2×2): 오늘 완료율 + ＋ 버튼
- Medium (4×2): 오늘 투두 목록 + 체크박스 + ＋ 버튼
- Large (4×4): 오늘 투두 전체 목록 + 완료율 + ＋ 버튼
- 위젯에서 체크박스 탭 → 즉시 완료 처리 (WidgetKit Interactive, iOS 17+)
- Notion 백그라운드 동기화

#### 데일리 리포트
- 오늘의 한마디(하루 리뷰) 작성
- 별점 선택 (⭐~⭐⭐⭐⭐⭐) — 기분, 성취도 등 용도는 사용자가 자유롭게 정의
- 완료율 자동 계산
- Notion 데일리리포트DB 저장
- 사진 첨부 기능 구조 대비 설계 (v2 구현 예정)

#### 리포트 뷰
- 이번 주 / 이번 달 데이터 조회
- 완료율 그래프 (주간: 요일별 막대, 월간: 주차별 막대)
- 별점 그래프 (꺾은선, 흐름 파악)
- 카테고리별 달성률

#### 카테고리 관리
- 앱 전용 (Notion DB 연동 없음)
- 카테고리 추가/편집/삭제
- 색상 선택 (12가지 컬러 팔레트)
- 아이콘 선택 (SF Symbol 25종, 공부/운동/업무/생활/취미 등)
- 투두 목록에서 색상 원형 + 아이콘 배지로 표시
- 카테고리별로 보기 섹션 헤더에 색상 원형 + 아이콘 표시
- 카테고리별 통계 → 주간/월간 리포트에 포함

### 6-2. 유료 기능 (Apple IAP 구독)

#### 이전 기간 데이터 조회
- 이전 주 / 이전 달 데이터 조회
- 무료 사용자는 이번 주 / 이번 달만 조회 가능

#### 노션에 저장하기 (주간/월간 리포트)
- 저장 위치: 기존 데일리리포트DB (별도 DB 없음)
- 주간 날짜: 기간 형식 (2026-05-19 ~ 2026-05-25)
- 월간 날짜: 기간 형식 (2026-05-01 ~ 2026-05-31)
- `완료율_앱` 속성에 값 직접 입력 (PATCH)
- 리포트 본문 구성:
  ```
  📊 요약 (완료 투두 / 완료율 / 연속 달성)
  📁 카테고리별 완료 (표)
  📅 요일별 / 주차별 현황
  💬 AI 한마디 (자동 생성)
  ```

#### AI 한마디 자동 생성
- 노션 저장 시 해당 기간 데이터를 기반으로 AI가 초안 자동 생성
- 사용자 편집 후 저장 가능
- 언어 설정 반영

#### 멀티 플래너
- 플래너 1개 = 투두DB 1개 + 데일리리포트DB 1개 묶음
- 무료: 플래너 1개 / 유료: 무제한
- 메인 화면 상단 드롭다운으로 플래너 전환

#### 반복 투두
- 반복 설정 → 자동으로 Notion에 생성
- 일간/주간/월간 반복 주기 지원

#### 다른 날 투두 확인
- 날짜 피커로 원하는 날짜 선택 → 해당 날짜 투두 목록 조회
- 무료: 오늘 날짜만 / 유료: 모든 날짜 조회 가능
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
① Sign in with Apple (계정 생성/로그인) ← 항상 필요
          ↓
② 노션 연결 여부 선택
   ┌──────────────────────────────┐
   │  노션 연결하기    나중에 하기 │
   └──────────────────────────────┘
          ↓                    ↓
③-A 노션 OAuth 진행      ③-B 로컬 모드 안내
   플래너 이름 입력          "데이터가 이 기기에만
   투두DB 선택               저장됩니다. 기기 변경 시
   데일리리포트DB 선택        데이터를 불러올 수 없어요."
   필수 속성 자동 추가              ↓
          ↓               LocalRepository 사용
④ 완료
```

**필수 속성 자동 추가 (노션 연결 시):**
- 완료율_앱 (number)
- 별점 (select, ⭐~⭐⭐⭐⭐⭐) — 없을 경우에만

## 8-1. 계정 구조

| 구분 | 계정 | 데이터 저장 | 구독 관리 |
|---|---|---|---|
| 노션 사용자 | Sign in with Apple + Notion OAuth | Notion DB | Apple IAP |
| 로컬 사용자 | Sign in with Apple | SwiftData (기기) | Apple IAP |

> Sign in with Apple은 모든 사용자에게 필수.
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
    case archived  // 보관됨 (소프트 삭제)
    case completed // v2: 목표 달성 완료 (Notion 프로젝트 DB 연동 시 사용)
}

struct Category: Identifiable, Codable {
    let id: String
    var name: String
    var colorHex: String   // 12가지 팔레트 중 선택
    var icon: String       // SF Symbol 이름 (25종 팔레트 중 선택)
    var status: CategoryStatus  // 기본값: .active
}
```

### 카테고리 삭제 동작

카테고리를 "삭제"하면 실제 데이터 삭제 대신 `status = .archived` 처리 (소프트 삭제).
- 목록 화면에는 `status == .active` 카테고리만 표시
- 아카이브된 카테고리에 연결된 투두는 카테고리 없음 상태로 표시
- v2: 아카이브된 카테고리 복원 기능 (설정 > 카테고리 > 보관된 항목)

보관 전 미완료 할일 경고:
- 해당 카테고리의 오늘 미완료 투두 개수를 확인
- 1개 이상이면 알림: "[카테고리명] 카테고리에 미완료 할일 N개가 있어요. 보관하면 전체 탭에서만 표시됩니다." → [취소] [보관]
- 미완료 할일 없으면 바로 보관 처리

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

> 카테고리는 앱 전용 (Notion 연동 없음). 투두 목록 배지, 카테고리별 보기 헤더, 리포트 달성률에서 사용.

---

## 9. 네비게이션 구조

### 탭 구성 (3개)

| 탭 | 아이콘 | 포함 기능 |
|---|---|---|
| 투두 | 체크리스트 | 데일리 리포트 + 투두 목록 + 다른 날 투두 확인 |
| 리포트 | 차트 | 이번 주/이번 달 데이터 (완료율·별점·카테고리 달성률), 이전 기간 조회(유료), 노션 저장(유료) |
| 설정 | 기어 | 플래너 관리, 앱 설정, 카테고리, 구독, 계정 |

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
│  ☑ 수학 문제 풀기               │  ← 탭: 완료/미완료
│  ☑ 영어 단어 30개              │    좌로 스와이프: 액션 버튼
│  ☐ 독서 30분                   │    길게 누르기: 편집
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

### 날짜 이동 규칙

| 동작 | 기능 | 유료 여부 |
|---|---|---|
| 날짜 좌측 공간 탭 | 이전 날 | 유료 |
| 날짜 우측 공간 탭 | 다음 날 | 유료 |
| 날짜 텍스트 탭 | 달력 피커 모달 | 유료 |
| 화면 스와이프 | ❌ 사용 안 함 | — |
| 힌트 | 양옆 흐릿한 화살표 ‹ › | — |

> 무료 사용자는 오늘 날짜만 접근 가능. 다른 날 탭 시 유료 안내 표시.

### 투두 아이템 제스처

| 동작 | 기능 |
|---|---|
| 탭 | 완료 / 미완료 토글 |
| 좌로 스와이프 | 액션 버튼 노출 (내일하기 / 날짜변경 / 삭제) |
| 길게 누르기 | 편집 모드 (제목 수정, 카테고리 변경) |

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
│  [ 노션에 저장하기 🔒 ] ← 유료  │
│  ① AI 한마디 초안 자동 생성     │
│  ② 사용자 편집 가능             │
│  [ 지금 저장 ] [알림 예약]      │
└─────────────────────────────────┘
```

| 기능 | 무료 | 유료 |
|---|---|---|
| 이번 주 / 이번 달 데이터 조회 | ✅ | — |
| 완료율·별점·카테고리 그래프 | ✅ | — |
| 이전 주 / 이전 달 조회 | ❌ | ✅ |
| 노션에 저장하기 | ❌ | ✅ |
| AI 한마디 자동 생성 | ❌ | ✅ |

### 주간 기준 정의

| 설정 | 주간 범위 | Notion 저장 기간 |
|---|---|---|
| 월요일 시작 (기본값) | 월 ~ 일 | 2026-05-25 ~ 2026-05-31 |
| 일요일 시작 | 일 ~ 토 | 2026-05-24 ~ 2026-05-30 |

> 시작 요일 설정은 주간 리포트 날짜 범위, 달력 표시, 알림 타이밍 모두에 영향.

### 설정 탭 — 화면 구조

```
┌─────────────────────────────────┐
│  [ 내 플래너 ]                  │
│  플래너 이름    수능 공부  ›    │
│  투두DB         할일 목록  ›    │
│  데일리리포트DB 데일리리포트 ›  │
│  + 플래너 추가 (유료)           │
├─────────────────────────────────┤
│  [ 앱 설정 ]                    │
│  언어           한국어     ›    │
│  시작 요일      월요일     ›    │
│  주간 리포트 알림  일 밤 10시 › │
├─────────────────────────────────┤
│  [ 카테고리 관리 ]          ›   │
├─────────────────────────────────┤
│  [ 구독 ]                       │
│  현재 플랜      무료 / Pro      │
│  구독 관리               ›     │
│  구매 복원               ›     │
├─────────────────────────────────┤
│  [ 계정 ]                       │
│  Apple ID  user@icloud.com  ›   │
│  노션 연결  연결됨 / 미연결  ›  │
│  ⚠️ 로컬모드: 기기에만 저장됨  │
│  로그아웃                       │
├─────────────────────────────────┤
│  [ 정보 ]                       │
│  버전           1.0.0           │
│  개인정보처리방침          ›    │
│  이용약관                  ›    │
└─────────────────────────────────┘
```

### 완료율 계산 원칙

> 완료율 계산 주체 및 저장 원칙 → 17절 참고.

### i18n (다국어) 처리 원칙

- 지원 언어: 한국어(기본) / English
- 영향 범위: UI 전체 텍스트, 자동 생성 리포트 문구, 알림 문구
- 추가 언어는 v2에서 확장
- Notion 속성명은 언어 설정과 무관하게 한국어 고정
  (속성명을 바꾸면 기존 사용자 데이터 연결이 끊어지기 때문)

---

## 10. 결제 구조 (Apple IAP)

| 항목 | 내용 |
|---|---|
| 결제 방식 | Apple IAP (StoreKit 2) |
| 수수료 | 수익의 30% Apple 지급 (연간 구독 갱신 시 15%) |
| 구독 형태 | 월간 구독 + 연간 구독 (동시 출시) |
| 연간 할인 | 월간 대비 약 20~30% 할인 표시 권장 |
| 무료 기능 제한 | 플래너 1개, 오늘 날짜만 |
| 유료 기능 | 주간/월간 리포트, 멀티 플래너, 반복 투두, 다른 날 투두 확인 |
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
  - Apple IAP StoreKit 2 연동
  - 주간/월간 리포트 자동 생성
  - 멀티 플래너
  - 반복 투두

Phase 4 (출시)
  - App Store Connect 설정
  - Privacy Policy / Terms of Service
  - 심사 제출
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
```

#### Notion 투두DB 속성 매핑

| Swift 필드 | Notion 속성 | 타입 | 비고 |
|---|---|---|---|
| title | 제목 | title | Notion 페이지 제목 |
| isCompleted | 완료 | checkbox | |
| date | 날짜 | date | |
| memo | 메모 | text | **없는 사용자 있음 → NotionSchemaManager 자동 추가** |
| — | 데일리 리포트 | relation | SyncQueue가 자동 연결 (15절 참고) |
| — | 시간표 | relation | v2, 앱에서 건드리지 않음 |
| — | 알림 | formula | v2, 앱에서 건드리지 않음 |
| createdAt | — | — | 로컬 전용, Notion에 저장 안 함 |
| categoryId | — | — | 앱 전용, Notion에 저장 안 함 |
| isPinned | 중요 | checkbox | 없는 사용자는 NotionSchemaManager 자동 추가 |

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
  │     카테고리: v1은 SwiftData, v2에서 Notion 프로젝트DB 연동 예정
  └── LocalRepository     ← 로컬 모드 사용자
        투두/리포트/카테고리: SwiftData 직접 읽기/쓰기
        SyncQueue 없음
  (└── iCloudRepository)  ← v2
```

### 카테고리 v2 확장 경로

카테고리는 v1에서 앱 전용(SwiftData)이지만, v2에서 Notion 프로젝트DB / 목표DB 연동 예정.
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

## 19. 온보딩 재진입 플로우

로컬 모드 사용자가 설정 탭 > 계정 > 노션 연결을 탭했을 때.
온보딩 3-A와 동일한 플로우를 재사용한다.

```
설정 > 노션 연결 탭
  ↓
Notion OAuth 진행
  ↓
플래너 이름 입력
  ↓
투두DB 선택
  ↓
데일리리포트DB 선택
  ↓
필수 속성 자동 추가 (완료율_앱, 별점, 메모)
  ↓
완료 → NotionRepository로 전환
```

- 기존 로컬(SwiftData) 데이터는 건드리지 않음
- 로컬 → 노션 데이터 마이그레이션은 v2 유료 기능으로 별도 구현

---

*이 문서는 개발 진행에 따라 업데이트됩니다.*

---

## 리팩토링 TODO

### TodoService → DataRepository 패턴 통합 (v1 후반 또는 v2)
- 현재: TodoService가 SwiftData + SyncQueue를 직접 사용
- 목표: ViewModel → RepositoryFactory.make() → NotionRepository/LocalRepository 단일 경로로 통합
- 이유: 현재 DataRepository 프로토콜과 TodoService 두 패턴이 병렬 존재 → 장기적으로 혼란
- 작업 범위: TodoViewModel, DailyReportViewModel 등 Service 직접 참조 → Repository 참조로 교체

### UserDefaults 키 정리
- 현재: "notionConnected", "isNotionConnected" 혼재
- 목표: 단일 키로 통일, AppConstants에 상수로 관리
- 관련 파일: OnboardingViewModel.swift, SyncQueueManager.swift

### 별점/기분 속성 옵션 매핑
- 현재: iOS DayRating(⭐~⭐⭐⭐⭐⭐)을 Notion select 옵션값으로 그대로 전송
- 문제: 사용자마다 Notion select 옵션명이 다름 (별이 아닌 숫자, 텍스트 등)
- 해결 방향: 온보딩 속성 매핑 시 별점 1~5에 해당하는 Notion 옵션값을 사용자가 직접 매핑
- 관련 파일: OnboardingViewModel.swift, DailyReportService.swift, ReportPropsMapping
