import SwiftData

enum BarabariSchema {
    static let version = Schema.Version(1, 0, 0)
    static let schema = Schema(
        [
            StoredGroup.self,
            StoredGroupMember.self,
            StoredExpense.self,
            StoredExpenseSplit.self,
            StoredSettlement.self,
            StoredActivityEvent.self
        ],
        version: version
    )
}
