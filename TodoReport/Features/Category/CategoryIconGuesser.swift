import Foundation

/// 카테고리 이름으로 아이콘 추정 (앱 안 낱말 사전, 인터넷 안 씀).
/// 새 카테고리를 만들 때(이름 입력 중)와 노션에서 가져올 때 쓴다. 이미 있는 카테고리는 바꾸지 않는다.
/// 여러 낱말이 맞으면 가장 긴 낱말을 고른다 (「일기」가 「일」보다 우선).
enum CategoryIconGuesser {
    static func icon(for name: String) -> String? {
        let lowered = name.lowercased().replacingOccurrences(of: " ", with: "")
        guard !lowered.isEmpty else { return nil }
        var best: (length: Int, icon: String)?
        for entry in keywordIconMap {
            for keyword in entry.keywords where lowered.contains(keyword) {
                if keyword.count > (best?.length ?? 0) {
                    best = (keyword.count, entry.icon)
                }
            }
        }
        return best?.icon
    }

    /// 키워드는 소문자·띄어쓰기 없이. 아이콘은 라인 기본 이름 (채움·라인은 카테고리마다)
    /// 다른 낱말 속에 잘 들어가는 짧은 영어(art, cat, car, eat, pet)는 넣지 않는다 (party, education, card…)
    private static let keywordIconMap: [(keywords: [String], icon: String)] = [
        // 공부
        (["공부", "학습", "수업", "강의", "숙제", "과제", "시험", "study", "learn", "class", "homework", "exam", "education"], "book"),
        (["독서", "책", "reading", "book"], "books.vertical"),
        (["교재", "문제집", "textbook", "workbook"], "text.book.closed"),
        (["영어", "단어", "외국어", "어학", "일본어", "중국어", "english", "vocab", "language"], "character.book.closed"),
        (["수학", "math"], "function"),
        (["필기", "정리노트", "note-taking"], "pencil.and.ruler"),
        (["학교", "대학", "학원", "school", "college", "university"], "graduationcap"),
        (["기록", "메모", "일기", "note", "memo", "journal", "diary"], "note.text"),
        (["아이디어", "기획", "idea", "plan"], "lightbulb"),
        // 일
        (["업무", "회사", "일", "직장", "work", "office", "job", "business"], "briefcase"),
        (["코딩", "개발", "프로그래밍", "coding", "develop", "programming"], "laptopcomputer"),
        (["문서", "보고서", "서류", "document", "report", "paper"], "doc.text"),
        (["메일", "이메일", "mail", "email"], "envelope"),
        (["전화", "통화", "call", "phone"], "phone"),
        (["회의", "미팅", "meeting"], "bubble.left.and.bubble.right"),
        (["할일", "체크", "todo", "checklist"], "checklist"),
        (["프로젝트", "project"], "folder"),
        (["블로그", "글쓰기", "blog", "writing"], "keyboard"),
        // 운동·건강
        (["운동", "헬스", "근력", "exercise", "workout", "gym", "fitness"], "dumbbell"),
        (["달리기", "러닝", "조깅", "run", "running", "jogging"], "figure.run"),
        (["걷기", "산책", "만보", "walk", "walking"], "figure.walk"),
        (["요가", "필라테스", "스트레칭", "yoga", "pilates", "stretch"], "figure.yoga"),
        (["수영", "swim"], "figure.pool.swim"),
        (["명상", "마음", "meditation", "mindful"], "figure.mind.and.body"),
        (["축구", "풋살", "soccer", "football"], "soccerball"),
        (["테니스", "배드민턴", "tennis", "badminton"], "tennis.racket"),
        (["자전거", "cycling", "bicycle", "bike"], "bicycle"),
        (["건강", "병원", "health", "hospital", "medical"], "heart"),
        (["약", "영양제", "medicine", "pill", "vitamin"], "pills"),
        (["물마시기", "물", "water", "hydrate"], "drop"),
        (["수면", "잠", "sleep"], "moon.zzz"),
        // 식생활
        (["식사", "밥", "음식", "meal", "food", "lunch", "dinner"], "fork.knife"),
        (["요리", "cook", "cooking", "recipe"], "frying.pan"),
        (["식단", "다이어트", "샐러드", "diet", "salad"], "carrot"),
        (["배달", "외식", "delivery", "takeout"], "takeoutbag.and.cup.and.straw"),
        (["카페", "커피", "coffee", "cafe"], "cup.and.saucer"),
        (["베이킹", "디저트", "간식", "baking", "dessert", "snack"], "birthday.cake"),
        (["냉장고", "주방", "refrigerator", "fridge", "kitchen"], "refrigerator"),
        (["장보기", "마트", "쇼핑", "grocery", "mart", "shopping", "buy"], "cart"),
        // 집안일
        (["집", "house", "home"], "house"),
        (["청소", "정리", "clean", "tidy"], "bubbles.and.sparkles"),
        (["세탁", "빨래", "세탁기", "laundry", "wash"], "washer"),
        (["건조", "건조기", "dryer"], "dryer"),
        (["욕실", "샤워", "화장실", "bathroom", "shower", "toilet"], "shower"),
        (["침대", "잠자리", "bed", "bedding"], "bed.double"),
        (["쓰레기", "분리수거", "trash", "recycle", "garbage"], "trash"),
        (["수리", "집수리", "repair", "fix", "diy"], "wrench.and.screwdriver"),
        (["인테리어", "가구", "interior", "furniture"], "sofa"),
        // 육아·가족
        (["육아", "아이", "아기", "어린이", "child", "baby", "kids", "parenting"], "figure.and.child.holdinghands"),
        (["가족", "family"], "figure.2.and.child.holdinghands"),
        (["놀이", "장난감", "toy", "play"], "teddybear"),
        (["친구", "약속", "모임", "friend", "social"], "person.2"),
        (["선물", "생일", "기념일", "gift", "birthday", "anniversary"], "gift"),
        // 돈
        (["돈", "가계부", "지출", "용돈", "money", "budget", "expense"], "wonsign.circle"),
        (["저축", "적금", "saving"], "banknote"),
        (["투자", "주식", "invest", "stock"], "chart.pie"),
        (["은행", "bank"], "building.columns"),
        (["카드", "결제", "card", "payment"], "creditcard"),
        // 반려동물·자연
        (["반려동물", "pets", "animal"], "pawprint"),
        (["강아지", "개", "dog", "puppy"], "dog"),
        (["고양이", "cats", "kitten"], "cat"),
        (["식물", "화분", "물주기", "plant", "garden", "flower"], "leaf"),
        (["캠핑", "등산", "camping", "hiking"], "tree"),
        // 이동
        (["운전", "차", "drive", "driving"], "car"),
        (["출근", "퇴근", "버스", "commute", "bus"], "bus"),
        (["지하철", "subway", "metro"], "tram"),
        (["여행", "travel", "trip", "vacation"], "airplane"),
        (["출장", "짐", "luggage"], "suitcase"),
        // 휴식·취미
        (["음악", "music", "song", "playlist"], "music.note"),
        (["노래", "sing", "karaoke"], "music.mic"),
        (["악기", "피아노", "guitar", "piano", "instrument"], "guitars"),
        (["게임", "gaming", "game"], "gamecontroller"),
        (["사진", "포토", "photo", "camera"], "camera"),
        (["그림", "미술", "draw", "paint", "design"], "paintbrush"),
        (["영화", "movie", "film"], "film"),
        (["드라마", "tv", "티비", "넷플릭스", "drama", "netflix"], "tv"),
        (["공연", "연극", "뮤지컬", "theater", "musical"], "theatermasks"),
        (["퍼즐", "puzzle"], "puzzlepiece"),
        (["취미", "휴식", "hobby", "rest", "relax"], "face.smiling"),
        // 목표·시간
        (["목표", "goal"], "target"),
        (["챌린지", "도전", "challenge"], "trophy"),
        (["습관", "루틴", "habit", "routine"], "arrow.3.trianglepath"),
        (["집중", "타이머", "focus", "timer", "pomodoro"], "timer"),
        (["마감", "deadline"], "hourglass"),
        (["일정", "약속시간", "schedule", "calendar"], "calendar"),
        (["알림", "notification", "reminder"], "bell"),
    ]
}
