# V2 아이디어 & 백로그

## 기능 추가
- 할일 보관 기능 — v1 미구현. 인박스(수집함)와 함께 구현. 카테고리 보관과 별개
- 인박스/수집함 — 날짜 선택이 선택사항인 투두
- 할일 순서 수동 편집 (드래그)
- 반복 투두 변경/취소 처리 (alert 플로우)
- 언어 선택 (한국어/영어) — 전체 String Catalog 작업 필요
- AI 주간 요약 (Claude API, Vercel 타임아웃 이슈로 이관)
- iCloud 백업/기기 이전
- 카테고리-Notion 프로젝트 DB 연동
- 동적 속성 매핑 (relation 타입 지원)
- 플래너 데이터 이전 툴
- 투두 탭 TodoRow에 시간 표시 (scheduledTime 있는 항목)
- 위젯 인터랙티브 체크·+ 버튼

## 기술 개선
- TodoService → DataRepository 패턴 통합
- UserDefaults 키 정리 ("notionConnected" / "isNotionConnected" 혼재)
- 영어 로컬라이제이션 (String Catalog)
- 별점/기분 속성 옵션 매핑 (사용자별 Notion select 옵션 직접 매핑)

## V3
- 플래너 간 Notion 템플릿 데이터 마이그레이션
