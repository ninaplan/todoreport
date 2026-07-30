# Archive — 보관한 기능 코드

쓰지 않기로 결정한 기능의 코드를 되살릴 수 있게 보관하는 폴더.
컴파일 대상이 아님(`docs/`는 Xcode 동기화 루트 밖). Swift 소스는 `.swift.txt`로 확장자를 바꿔 둔다.

---

## 카테고리 색 팔레트 세트

- **무엇:** 카테고리 색 팔레트 세트(9세트 × 12색, 플래너별 선택 + 기존 카테고리 일괄 재배색)
- **제거일:** 2026-07-30
- **제거 이유:** 기능 방향을 접었고, UI가 연결되지 않은 채 죽은 코드로 남아 있었음
- **보관 파일:** `CategoryPaletteSet.swift.txt`
- **관련 커밋:** 3764717
- **되살릴 때 필요한 것:**
  - `PlannerItem.categoryPaletteSetId` 저장 필드는 그대로 남아 있음 (SwiftData 경량 마이그레이션 리스크 때문에 유지)
  - 아래는 이 커밋에서 삭제됨 — git 히스토리 참고:
    - `Planner` 구조체 `categoryPaletteSetId` 프로퍼티
    - `PlannerService.updateCategoryPaletteSetId`
    - `CategoryService.recolorCategories`
    - `CategoryViewModel`의 팔레트 관련 프로퍼티·메서드 (`storedPaletteSetId`, `activePaletteSetId`, `activePaletteColors`, `syncStoredPaletteSetId`, `selectPaletteSet`)
