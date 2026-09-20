import Foundation
import SwiftData

enum BarabariModelContainer {
    private static let demoDate = Date(timeIntervalSince1970: 1_735_689_600)

    static func make(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Barabari",
            schema: BarabariSchema.schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: BarabariSchema.schema,
            migrationPlan: BarabariMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeDemo() throws -> ModelContainer {
        let container = try make(inMemory: true)
        try seedDemoData(in: container)
        return container
    }

    static func seedDemoData(in container: ModelContainer) throws {
        let context = ModelContext(container)
        guard try context.fetch(FetchDescriptor<StoredGroup>()).isEmpty else { return }

        let ownerID = UUID(uuidString: "56D75B9A-0238-45B6-9EF7-A3526D58B2A5")!
        let group = Group(
            id: UUID(uuidString: "969C9F06-CB8D-44A7-BBE9-ACAC5B1B7EA5")!,
            name: "Barabari Demo",
            description: "A local-first demo group",
            ownerID: ownerID,
            createdAt: demoDate,
            updatedAt: demoDate
        )
        let member = GroupMember(
            id: UUID(uuidString: "3CC76B12-AC8D-4358-A92E-82EE34489D8D")!,
            groupID: group.id,
            userID: ownerID,
            role: .owner,
            joinedAt: demoDate,
            updatedAt: demoDate
        )
        let event = ActivityEvent(
            id: UUID(uuidString: "D24135D1-9502-4AFC-8F79-0C0F4F655B63")!,
            groupID: group.id,
            actorUserID: ownerID,
            kind: .groupCreated,
            subjectID: group.id,
            occurredAt: demoDate,
            createdAt: demoDate
        )
        context.insert(StoredGroup(group: group))
        context.insert(StoredGroupMember(member: member))
        context.insert(StoredActivityEvent(event: event))
        try context.save()
    }
}
