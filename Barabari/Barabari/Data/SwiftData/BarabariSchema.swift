import SwiftData

enum BarabariSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
            StoredLedgerCommand.self,
            StoredGroup.self,
            StoredGroupMember.self,
            StoredExpense.self,
            StoredExpenseSplit.self,
            StoredSettlement.self,
            StoredActivityEvent.self
    ]
}

enum BarabariMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [BarabariSchemaV1.self]
    static let stages: [MigrationStage] = []
}

enum BarabariSchema {
    static let schema = Schema(versionedSchema: BarabariSchemaV1.self)
}
