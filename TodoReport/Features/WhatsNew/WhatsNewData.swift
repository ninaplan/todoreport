import Foundation

let whatsNewReleases: [WhatsNewRelease] = [
    WhatsNewRelease(
        id: "1.0.9",
        symbolName: "hand.tap",
        items: [
            String(localized: "할 일 이름을 탭해서 바로 수정"),
            String(localized: "할 일을 길게 눌러 편집·고정·날짜 변경·삭제 메뉴 열기"),
            String(localized: "데일리 리포트 카드 접기·펼치기 추가"),
            String(localized: "고정한 할 일은 핀으로, 설정 시간과 알림은 오른쪽에 표시"),
            String(localized: "⋯ 메뉴에서 완료된 할 일·메모·설정 시간 표시를 켜고 끄기"),
            String(localized: "날짜를 옮길 때 설정 시간과 알림도 함께 이동하도록 수정")
        ],
        showsPopup: true,
        showsTodoRowPreview: true,
        notice: String(localized: "위젯이 이전 날짜에 멈춰 있다면 위젯을 삭제 후 다시 추가해 주세요")
    ),
    WhatsNewRelease(
        id: "1.0.8",
        symbolName: "calendar",
        items: [
            String(localized: "투두 날짜 선택 화면을 새로운 달력 디자인으로 변경 (카테고리 색상 점·필터 지원)"),
            String(localized: "노션 플래너에서 원하는 달의 데이터만 다시 불러오기 가능"),
            String(localized: "카테고리 색상 팔레트 9종 추가"),
            String(localized: "노션에서 수정한 내용이 더 빠르게 반영되도록 동기화 개선")
        ],
        showsPopup: true
    ),
    WhatsNewRelease(
        id: "1.0.7",
        symbolName: "checkmark.circle",
        items: [
            String(localized: "위젯을 개선해 모든 크기를 사용할 수 있도록 변경 (중간·큰 크기 위젯이 비어 보이면 삭제 후 다시 추가)"),
            String(localized: "할일을 다른 날짜로 옮길 때 중복 표시되던 문제 수정"),
            String(localized: "노션 동기화 안정성 개선"),
            String(localized: "날짜 이동 시 더 빠르게 목록 표시")
        ],
        showsPopup: true
    ),
    WhatsNewRelease(
        id: "1.0.6",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "플래너 관리 화면 추가 (순서 변경·삭제)"),
            String(localized: "구독 만료·재구독 시 플래너 잠금 처리 개선"),
            String(localized: "노션 연결 해제 시 로컬 데이터 유지"),
            String(localized: "같은 워크스페이스 멀티 플래너 연동 끊김 수정")
        ],
        showsPopup: true
    ),
    WhatsNewRelease(
        id: "1.0.5",
        symbolName: "arrow.triangle.2.circlepath",
        items: [
            String(localized: "노션 동기화 안정성 개선"),
            String(localized: "오프라인 편집 내용이 노션에 반영되지 않던 문제 수정")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.4",
        symbolName: "bookmark",
        items: [
            String(localized: "날짜 이동 제한 해제"),
            String(localized: "화면 모드 설정 추가"),
            String(localized: "위젯 무제한 사용")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.3",
        symbolName: "bookmark",
        items: [
            String(localized: "화면 가장자리 스와이프로 날짜·기간 이동 가능"),
            String(localized: "별점 다시 탭하면 선택 취소 가능"),
            String(localized: "고객 피드백을 앱 안에서 바로 작성 가능")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.2",
        symbolName: "bookmark",
        items: [
            String(localized: "할일 시간 동기화 오류 수정"),
            String(localized: "투두 목록 스크롤 시 버튼 가림 현상 수정")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.1",
        symbolName: "bookmark",
        items: [
            String(localized: "날짜 이동 속도 개선"),
            String(localized: "날짜·카테고리 동기화 오류 다수 수정")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0",
        symbolName: "flag",
        items: [
            String(localized: "투두x리포트 출시")
        ],
        showsPopup: false
    ),
]
