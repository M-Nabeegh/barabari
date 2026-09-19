import Foundation
import SwiftData

@Model
final class GroupRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var detail: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, detail: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.detail = detail
        self.createdAt = createdAt
    }
}

@Model
final class ActivityRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String
    var amountInPaisa: Int64
    var happenedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        amountInPaisa: Int64,
        happenedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.amountInPaisa = amountInPaisa
        self.happenedAt = happenedAt
    }
}

