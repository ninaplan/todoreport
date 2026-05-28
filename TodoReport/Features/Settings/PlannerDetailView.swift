import SwiftUI

struct PlannerDetailView: View {
    @State private var name: String
    @State private var color: Color
    private let isNotionConnected: Bool

    init(planner: Planner) {
        _name = State(initialValue: planner.name)
        _color = State(initialValue: Color(hex: planner.colorHex))
        isNotionConnected = planner.isNotionConnected
    }

    var body: some View {
        List {
            basicSection
            categorySection
            if isNotionConnected {
                notionSection
            }
        }
        .navigationTitle("플래너 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 기본

    private var basicSection: some View {
        Section("기본") {
            LabeledContent("이름") {
                TextField("플래너 이름", text: $name)
                    .multilineTextAlignment(.trailing)
            }
            ColorPicker("대표 색상", selection: $color, supportsOpacity: false)
        }
    }

    // MARK: - 카테고리

    private var categorySection: some View {
        Section("카테고리") {
            NavigationLink {
                CategoryView()
            } label: {
                Text("카테고리 관리")
            }
        }
    }

    // MARK: - 노션 설정

    private var notionSection: some View {
        Section("노션 설정") {
            NavigationLink(destination: Text("투두 DB 설정").navigationTitle("투두 DB")) {
                Text("투두 DB")
            }
            NavigationLink(destination: Text("리포트 DB 설정").navigationTitle("리포트 DB")) {
                Text("리포트 DB")
            }
            NavigationLink(destination: Text("속성명 매핑").navigationTitle("속성명 매핑")) {
                Text("속성명 매핑")
            }
        }
    }
}
