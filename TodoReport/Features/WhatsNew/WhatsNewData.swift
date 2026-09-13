import Foundation

let whatsNewReleases: [WhatsNewRelease] = [
    WhatsNewRelease(
        id: "1.14",
        symbolName: "tray",
        items: [
            String(localized: "수집함이 생겼어요"),
            String(localized: "할 일 검색")
        ],
        showsPopup: true,
        popupTitle: String(localized: "이번 업데이트 소식"),
        popupSubtitle: String(localized: "수집함과 검색, 새로 생겼어요"),
        popupItems: [
            WhatsNewRelease.PopupItem(
                symbolName: "tray",
                title: String(localized: "수집함이 생겼어요"),
                description: String(localized: "떠오르는 생각은 바로 수집함에 모아두세요. 목록의 할 일을 수집함으로 보내거나 수집함의 항목을 오늘로 가져올 수도 있습니다."),
                previewImageName: "WhatsNewInboxPreview"
            ),
            WhatsNewRelease.PopupItem(
                symbolName: "magnifyingglass",
                title: String(localized: "할 일 검색"),
                description: String(localized: "언제 무엇을 했는지 기억나지 않아도 이제 검색으로 찾을 수 있어요. 여러 플래너를 쓰고 있다면, 모든 플래너의 검색 결과를 한 번에 볼 수 있어요."),
                previewImageName: "WhatsNewSearchPreview"
            )
        ],
        popupButtonTitle: String(localized: "시작하기")
    ),
    WhatsNewRelease(
        id: "1.10",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "위젯 실시간 반영하도록 개선")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.09",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "할 일 이름을 탭해서 바로 수정, 길게 누르면 편집·고정·날짜·삭제 메뉴"),
            String(localized: "카테고리 색상을 원하는 색으로 직접 선택"),
            String(localized: "데일리 리포트 카드 접기·펼치기"),
            String(localized: "할 일 목록에 핀·설정 시간·알림 표시 (⋯ 메뉴에서 켜고 끄기)"),
            String(localized: "날짜를 옮길 때 설정 시간과 알림도 함께 이동하도록 수정")
        ],
        showsPopup: true,
        showsTodoRowPreview: true,
        notice: String(localized: "위젯이 이전 날짜에 멈춰 있다면 위젯을 삭제 후 다시 추가해 주세요")
    ),
    WhatsNewRelease(
        id: "1.08",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "투두 날짜 선택 화면을 새로운 달력 디자인으로 변경 (카테고리 색상 점·필터 지원)"),
            String(localized: "노션 플래너에서 원하는 달의 데이터만 다시 불러오기 가능"),
            String(localized: "카테고리 색상 팔레트 9종 추가"),
            String(localized: "노션에서 수정한 내용이 더 빠르게 반영되도록 동기화 개선")
        ],
        showsPopup: true
    ),
    WhatsNewRelease(
        id: "1.07",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "위젯을 개선해 모든 크기를 사용할 수 있도록 변경 (중간·큰 크기 위젯이 비어 보이면 삭제 후 다시 추가)"),
            String(localized: "할일을 다른 날짜로 옮길 때 중복 표시되던 문제 수정"),
            String(localized: "노션 동기화 안정성 개선"),
            String(localized: "날짜 이동 시 더 빠르게 목록 표시")
        ],
        showsPopup: true
    ),
    WhatsNewRelease(
        id: "1.06",
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
        id: "1.05",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "노션 동기화 안정성 개선"),
            String(localized: "오프라인 편집 내용이 노션에 반영되지 않던 문제 수정")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.04",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "날짜 이동 제한 해제"),
            String(localized: "화면 모드 설정 추가"),
            String(localized: "위젯 무제한 사용")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.03",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "화면 가장자리 스와이프로 날짜·기간 이동 가능"),
            String(localized: "별점 다시 탭하면 선택 취소 가능"),
            String(localized: "고객 피드백을 앱 안에서 바로 작성 가능")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.02",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "할일 시간 동기화 오류 수정"),
            String(localized: "투두 목록 스크롤 시 버튼 가림 현상 수정")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.01",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "날짜 이동 속도 개선"),
            String(localized: "날짜·카테고리 동기화 오류 다수 수정")
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0",
        symbolName: "rectangle.stack",
        items: [
            String(localized: "투두x리포트 출시")
        ],
        showsPopup: false
    ),
]
