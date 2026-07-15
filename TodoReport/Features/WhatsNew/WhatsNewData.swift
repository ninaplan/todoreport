import Foundation

let whatsNewReleases: [WhatsNewRelease] = [
    WhatsNewRelease(
        id: "1.0.7",
        symbolName: "checkmark.circle",
        items: [
            "할일을 다른 날짜로 옮길 때 중복 표시되던 문제 수정",
            "노션 동기화 안정성 개선",
            "날짜 이동 시 더 빠르게 목록 표시"
        ],
        showsPopup: true
    ),
    WhatsNewRelease(
        id: "1.0.6",
        symbolName: "rectangle.stack",
        items: [
            "플래너 관리 화면 추가 (순서 변경·삭제)",
            "구독 만료·재구독 시 플래너 잠금 처리 개선",
            "노션 연결 해제 시 로컬 데이터 유지",
            "같은 워크스페이스 멀티 플래너 연동 끊김 수정"
        ],
        showsPopup: true
    ),
    WhatsNewRelease(
        id: "1.0.5",
        symbolName: "arrow.triangle.2.circlepath",
        items: [
            "노션 동기화 안정성 개선",
            "오프라인 편집 내용이 노션에 반영되지 않던 문제 수정"
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.4",
        symbolName: "bookmark",
        items: [
            "날짜 이동 제한 해제",
            "화면 모드 설정 추가",
            "위젯 무제한 사용"
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.3",
        symbolName: "bookmark",
        items: [
            "화면 가장자리 스와이프로 날짜·기간 이동 가능",
            "별점 다시 탭하면 선택 취소 가능",
            "고객 피드백을 앱 안에서 바로 작성 가능"
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.2",
        symbolName: "bookmark",
        items: [
            "할일 시간 동기화 오류 수정",
            "투두 목록 스크롤 시 버튼 가림 현상 수정"
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0.1",
        symbolName: "bookmark",
        items: [
            "날짜 이동 속도 개선",
            "날짜·카테고리 동기화 오류 다수 수정"
        ],
        showsPopup: false
    ),
    WhatsNewRelease(
        id: "1.0",
        symbolName: "flag",
        items: [
            "투두x리포트 출시"
        ],
        showsPopup: false
    ),
]
