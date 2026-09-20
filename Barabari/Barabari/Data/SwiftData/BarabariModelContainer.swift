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

    static func seedDemoData(
        in container: ModelContainer,
        includeSecondMember: Bool = false,
        includeDemoDebt: Bool = false
    ) throws {
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
        let secondMember = GroupMember(
            id: UUID(uuidString: "8D6F4E2C-7B1A-4C39-8DAB-5A6E7F8091B2")!,
            groupID: group.id,
            userID: UUID(uuidString: "A1D2E3F4-5A6B-4C7D-8E9F-001122334455")!,
            role: .member,
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
        if includeSecondMember || includeDemoDebt {
            context.insert(StoredGroupMember(member: secondMember))
        }
        context.insert(StoredActivityEvent(event: event))
        if includeDemoDebt {
            let expense = Expense(
                id: UUID(uuidString: "0D443B4D-ED4E-4FEE-87AF-A17681A1E3E6")!,
                groupID: group.id,
                title: "Demo dinner",
                note: "A seeded local debt for settlement testing",
                total: Money(minorUnits: 200_000, currencyCode: "PKR"),
                paidByUserID: secondMember.userID,
                splits: [
                    ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 100_000, currencyCode: "PKR")),
                    ExpenseSplit(userID: secondMember.userID, amount: Money(minorUnits: 100_000, currencyCode: "PKR"))
                ],
                splitMethod: .equal,
                occurredAt: demoDate.addingTimeInterval(60),
                createdByUserID: secondMember.userID,
                createdAt: demoDate.addingTimeInterval(60),
                updatedAt: demoDate.addingTimeInterval(60)
            )
            context.insert(try StoredExpense(expense: expense))
            for split in expense.splits {
                context.insert(StoredExpenseSplit(expenseID: expense.id, split: split))
            }
            context.insert(StoredActivityEvent(event: ActivityEvent(
                groupID: group.id,
                actorUserID: secondMember.userID,
                kind: .expenseCreated,
                subjectID: expense.id,
                occurredAt: expense.occurredAt,
                createdAt: expense.createdAt
            )))
        }
        try context.save()
    }
}
