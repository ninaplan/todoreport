import SwiftUI

func propTypeIcon(for type: String?, label: String? = nil) -> String {
    if let label {
        switch label {
        case "완료":         return "checkmark.square"
        case "날짜":         return "calendar"
        case "메모", "하루 리뷰": return "text.alignleft"
        case "상단고정":     return "pin"
        case "카테고리":     return "tag"
        case "리포트 연결":  return "link"
        case "별점":         return "star"
        default:             break
        }
    }
    switch type {
    case "checkbox":  return "checkmark.square"
    case "date":      return "calendar"
    case "rich_text": return "text.alignleft"
    case "select":    return "list.bullet"
    case "status":    return "circle.lefthalf.filled"
    case "number":    return "number"
    case "relation":  return "link"
    case "formula":   return "function"
    case "rollup":    return "sum"
    case "url":       return "globe"
    case "email":     return "envelope"
    case "phone":     return "phone"
    case "files":     return "paperclip"
    case "people":    return "person"
    default:          return "circle"
    }
}

struct FlowSmallTag: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct RequiredPropRow: View {
    let label: String
    let props: [NotionProperty]
    @Binding var selection: String?

    var body: some View {
        HStack {
            Image(systemName: propTypeIcon(for: props.first?.type, label: label))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
            FlowSmallTag("필수")
            Spacer()
            Menu {
                ForEach(props) { prop in
                    Button {
                        selection = prop.name
                    } label: {
                        HStack {
                            Text(prop.name)
                            if selection == prop.name { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Text(selection ?? "선택")
                    .foregroundStyle(.secondary)
            }
            .tint(Color(.label))
        }
    }
}

struct OptionalPropMenu: View {
    let label: String
    @Binding var mode: PropMappingMode
    let props: [NotionProperty]
    @Binding var selection: String?
    var onCreateTap: (() -> Void)? = nil
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: propTypeIcon(for: props.first?.type, label: label))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                Spacer()
                Menu {
                    Button {
                        mode = .appOnly
                        selection = nil
                    } label: {
                        HStack {
                            Text("앱에만 저장")
                            if mode == .appOnly && selection == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                    ForEach(props) { prop in
                        Button {
                            mode = .existing
                            selection = prop.name
                        } label: {
                            HStack {
                                Text(prop.name)
                                if selection == prop.name { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    if let onCreateTap {
                        Divider()
                        Button("Notion에 생성하기", action: onCreateTap)
                    }
                } label: {
                    Text(selection ?? (mode == .appOnly ? "앱에만 저장" : "선택"))
                        .foregroundStyle(.secondary)
                }
                .tint(Color(.label))
            }
            if let hint, props.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }
        }
    }
}
