#if DEBUG
import Foundation
import SwiftData

/// 임시 진단·로컬 정리. 원인 확인 후 이 파일과 개발자 옵션 버튼만 제거하면 된다.
enum GhostDataDiagnostics {
    @MainActor
    static func dump() {
        let context = PersistenceController.shared.context
        let iso = ISO8601DateFormatter()

        func line(_ message: String) {
            print("[GhostData] \(message)")
            AppLogger.shared.info("GhostData", message)
        }

        func dateText(_ date: Date?) -> String {
            guard let date else { return "nil" }
            return iso.string(from: date)
        }

        line("========== 유령 데이터 점검 시작 ==========")

        let seriesList: [RecurringSeries]
        do {
            seriesList = try context.fetch(FetchDescriptor<RecurringSeries>())
        } catch {
            line("RecurringSeries 조회 실패 \(error.localizedDescription)")
            return
        }

        let planners: [PlannerItem]
        do {
            planners = try context.fetch(FetchDescriptor<PlannerItem>())
        } catch {
            line("PlannerItem 조회 실패 \(error.localizedDescription)")
            return
        }

        let todos: [TodoItem]
        do {
            todos = try context.fetch(FetchDescriptor<TodoItem>())
        } catch {
            line("TodoItem 조회 실패 \(error.localizedDescription)")
            return
        }

        let plannerIds = Set(planners.map(\.id))

        line("--- RecurringSeries (\(seriesList.count)개) ---")
        for series in seriesList {
            let plannerExists: String
            if let pid = series.plannerId {
                plannerExists = plannerIds.contains(pid) ? "exists" : "orphan"
            } else {
                plannerExists = "nil-planner"
            }
            line(
                "series id:\(series.id) title:\(series.title) plannerId:\(series.plannerId ?? "nil") isActive:\(series.isActive) originDate:\(dateText(series.originDate)) endDate:\(dateText(series.endDate)) lastMaterializedThrough:\(dateText(series.lastMaterializedThrough)) planner:\(plannerExists)"
            )
        }

        line("--- PlannerItem (\(planners.count)개) ---")
        for planner in planners {
            line(
                "planner id:\(planner.id) name:\(planner.name) isNotionConnected:\(planner.isNotionConnected)"
            )
        }

        let nilPlannerTodos = todos.filter { $0.plannerId == nil }
        let orphanPlannerTodos = todos.filter { todo in
            guard let pid = todo.plannerId else { return false }
            return !plannerIds.contains(pid)
        }
        let emptyPageTodos = todos.filter { $0.notionPageId.isEmpty }

        line("--- TodoItem plannerId nil (\(nilPlannerTodos.count)개 / 전체 \(todos.count)개) ---")
        for todo in nilPlannerTodos {
            line(todoLine(todo, dateText: dateText))
        }

        line("--- TodoItem 고아 plannerId (\(orphanPlannerTodos.count)개) ---")
        for todo in orphanPlannerTodos {
            line(todoLine(todo, dateText: dateText))
        }

        line("--- TodoItem notionPageId 빈 값 (\(emptyPageTodos.count)개) ---")
        for todo in emptyPageTodos {
            line(todoLine(todo, dateText: dateText))
        }

        let calendar = Calendar.current
        var grouped: [String: [TodoItem]] = [:]
        for todo in todos {
            let dayKey: String
            if let date = todo.date {
                dayKey = iso.string(from: calendar.startOfDay(for: date))
            } else {
                dayKey = "nil"
            }
            grouped["\(todo.title)|\(dayKey)", default: []].append(todo)
        }
        let duplicates = grouped.filter { $0.value.count >= 2 }.sorted { $0.key < $1.key }

        line("--- title+date 중복 (\(duplicates.count)조합) ---")
        for (key, items) in duplicates {
            line("dup key:\(key) count:\(items.count)")
            for todo in items {
                line(todoLine(todo, dateText: dateText))
            }
        }

        line("========== 유령 데이터 점검 끝 ==========")
    }

    /// endDate가 originDate보다 앞선 시리즈만. 변경 없음.
    @MainActor
    static func previewCleanup() {
        let context = PersistenceController.shared.context
        guard let targets = loadEndedBeforeOriginTargets(in: context) else { return }

        log("========== 정리 대상 미리보기 시작 ==========")
        log("대상 시리즈 \(targets.count)개")
        var totalTodos = 0
        for target in targets {
            let series = target.series
            log(
                "series id:\(series.id) title:\(series.title) originDate:\(dateText(series.originDate)) endDate:\(dateText(series.endDate))"
            )
            for todo in target.todos {
                log("  delete todo id:\(todo.id) title:\(todo.title) date:\(dateText(todo.date))")
            }
            log("  삭제 예정 \(target.todos.count)건")
            totalTodos += target.todos.count
        }
        log("삭제 예정 할일 총 \(totalTodos)건")
        log("========== 정리 대상 미리보기 끝 ==========")
    }

    /// endDate가 originDate보다 앞선 시리즈만. 로컬 SwiftData 삭제, 노션 큐 없음.
    @MainActor
    static func cleanup() {
        let context = PersistenceController.shared.context
        guard let targets = loadEndedBeforeOriginTargets(in: context) else { return }

        let seriesCount = targets.count
        let todoCount = targets.reduce(0) { $0 + $1.todos.count }
        log("========== 유령 데이터 정리 시작 ==========")
        log("삭제 전 대상 시리즈 \(seriesCount)개, 할일 \(todoCount)건")

        for target in targets {
            for todo in target.todos {
                TodoNotificationManager.shared.cancel(for: todo.id)
                context.delete(todo)
            }
            target.series.isActive = false
        }

        do {
            try context.save()
        } catch {
            AppLogger.shared.error("GhostData", "유령 데이터 정리 저장 실패 \(error.localizedDescription)")
            context.rollback()
            return
        }

        log("정리 완료 삭제 할일 \(todoCount)건, 끈 시리즈 \(seriesCount)개")
        log("========== 유령 데이터 정리 끝 ==========")
    }

    @MainActor
    private static func loadEndedBeforeOriginTargets(
        in context: ModelContext
    ) -> [(series: RecurringSeries, todos: [TodoItem])]? {
        let seriesList: [RecurringSeries]
        do {
            seriesList = try context.fetch(FetchDescriptor<RecurringSeries>())
        } catch {
            AppLogger.shared.error("GhostData", "RecurringSeries 조회 실패 \(error.localizedDescription)")
            return nil
        }

        let todos: [TodoItem]
        do {
            todos = try context.fetch(FetchDescriptor<TodoItem>())
        } catch {
            AppLogger.shared.error("GhostData", "TodoItem 조회 실패 \(error.localizedDescription)")
            return nil
        }

        let calendar = Calendar.current
        var targets: [(series: RecurringSeries, todos: [TodoItem])] = []
        for series in seriesList {
            guard let end = series.endDate else { continue }
            let originDay = calendar.startOfDay(for: series.originDate)
            let endDay = calendar.startOfDay(for: end)
            guard endDay < originDay else { continue }

            let toDelete = todos.filter { todo in
                guard todo.recurrenceId == series.id, let date = todo.date else { return false }
                return calendar.startOfDay(for: date) > endDay
            }
            targets.append((series, toDelete))
        }
        return targets
    }

    private static func log(_ message: String) {
        print("[GhostData] \(message)")
        AppLogger.shared.info("GhostData", message)
    }

    private static func dateText(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return ISO8601DateFormatter().string(from: date)
    }

    private static func todoLine(_ todo: TodoItem, dateText: (Date?) -> String) -> String {
        "todo id:\(todo.id) title:\(todo.title) date:\(dateText(todo.date)) plannerId:\(todo.plannerId ?? "nil") notionPageId:\(todo.notionPageId.isEmpty ? "(empty)" : todo.notionPageId) recurrenceId:\(todo.recurrenceId ?? "nil")"
    }
}
#endif
