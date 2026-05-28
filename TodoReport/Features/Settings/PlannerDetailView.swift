import SwiftUI
import UIKit

struct PlannerDetailView: View {
    private let planner: Planner
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: Color
    @State private var showDeleteAlert = false

    private var totalPlannerCount: Int { PlannerService.shared.store.count }
    private let isNotionConnected: Bool

    init(planner: Planner) {
        self.planner = planner
        _name = State(initialValue: planner.name)
        _selectedColor = State(initialValue: Color(hex: planner.colorHex))
        isNotionConnected = planner.isNotionConnected
    }

    var body: some View {
        List {
            basicSection
            categorySection
            if isNotionConnected {
                notionSection
            }
            if totalPlannerCount > 1 {
                deleteSection
            }
        }
        .navigationTitle("플래너 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    Task {
                        var updated = planner
                        updated.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? planner.name : name.trimmingCharacters(in: .whitespaces)
                        updated.colorHex = colorHex(from: selectedColor) ?? planner.colorHex
                        try? await PlannerService.shared.savePlanner(updated)
                    }
                }
                .tint(Color.nockOrange)
                .fontWeight(.semibold)
            }
        }
        .alert("플래너 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                Task {
                    try? await PlannerService.shared.deletePlanner(planner)
                    dismiss()
                }
            }
        } message: {
            Text("플래너를 삭제하면 해당 플래너의 모든 데이터가 삭제됩니다. 계속할까요?")
        }
    }

    // MARK: - 기본

    private var basicSection: some View {
        Section("기본") {
            LabeledContent("이름") {
                TextField("플래너 이름", text: $name)
                    .multilineTextAlignment(.trailing)
            }
            ColorPicker("대표 색상", selection: $selectedColor, supportsOpacity: false)
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

    // MARK: - 삭제

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("플래너 삭제")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Helpers

    private func colorHex(from color: Color) -> String? {
        let uiColor = UIColor(color)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
