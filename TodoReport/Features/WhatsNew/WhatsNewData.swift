import Foundation

let whatsNewReleases: [WhatsNewRelease] = [
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
