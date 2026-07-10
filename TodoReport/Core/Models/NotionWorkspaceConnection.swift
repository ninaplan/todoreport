import Foundation
import SwiftData

@Model
final class NotionWorkspaceConnection {
    @Attribute(.unique) var id: String
    @Attribute(.unique) var workspaceId: String
    var workspaceName: String
    var accessToken: String
    var refreshToken: String?
    var botId: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        workspaceId: String,
        workspaceName: String,
        accessToken: String,
        refreshToken: String? = nil,
        botId: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.botId = botId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
