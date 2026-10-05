import Foundation

enum ExpenseCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case food
    case groceries
    case transport
    case rent
    case utilities
    case shopping
    case fun
    case travel
    case health
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .food: "Food"
        case .groceries: "Groceries"
        case .transport: "Transport"
        case .rent: "Rent"
        case .utilities: "Bills"
        case .shopping: "Shopping"
        case .fun: "Fun"
        case .travel: "Travel"
        case .health: "Health"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .groceries: "basket.fill"
        case .transport: "car.fill"
        case .rent: "house.fill"
        case .utilities: "bolt.fill"
        case .shopping: "bag.fill"
        case .fun: "popcorn.fill"
        case .travel: "airplane"
        case .health: "cross.case.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    /// Hex colour, kept UI-framework free so the domain layer stays portable.
    var hex: UInt32 {
        switch self {
        case .food: 0xF97316
        case .groceries: 0x22C55E
        case .transport: 0x3B82F6
        case .rent: 0x8B5CF6
        case .utilities: 0xEAB308
        case .shopping: 0xEC4899
        case .fun: 0xF43F5E
        case .travel: 0x06B6D4
        case .health: 0x14B8A6
        case .other: 0x64748B
        }
    }

    private var keywords: [String] {
        switch self {
        case .food:
            ["dinner", "lunch", "breakfast", "biryani", "karahi", "pizza", "burger", "chai", "tea", "coffee",
             "restaurant", "food", "bbq", "nihari", "haleem", "dhaba", "cafe", "shawarma", "paratha", "sweets", "iftar", "sehri"]
        case .groceries:
            ["grocery", "groceries", "sabzi", "vegetables", "fruit", "milk", "doodh", "atta", "ration", "mart", "imtiaz", "carrefour"]
        case .transport:
            ["petrol", "fuel", "uber", "careem", "indrive", "bykea", "taxi", "rickshaw", "parking", "toll", "metro", "bus", "diesel"]
        case .rent:
            ["rent", "kiraya", "flat", "apartment", "hostel", "deposit"]
        case .utilities:
            ["electricity", "bijli", "gas", "sui", "water", "internet", "wifi", "ptcl", "bill", "k-electric", "lesco", "mobile load"]
        case .shopping:
            ["shopping", "clothes", "shoes", "amazon", "daraz", "gift", "kurta", "mall"]
        case .fun:
            ["movie", "cinema", "cricket", "game", "concert", "netflix", "bowling", "party", "tickets"]
        case .travel:
            ["trip", "hotel", "flight", "murree", "naran", "hunza", "skardu", "swat", "travel", "booking", "airbnb"]
        case .health:
            ["doctor", "medicine", "pharmacy", "hospital", "clinic", "lab", "dawai", "gym"]
        case .other:
            []
        }
    }

    /// Best-guess category from a free-text expense title.
    static func detect(from title: String) -> ExpenseCategory? {
        let lowered = title.lowercased()
        guard !lowered.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let words = Set(lowered.split(whereSeparator: { !$0.isLetter && $0 != "-" }).map(String.init))
        for category in allCases where category != .other {
            for keyword in category.keywords {
                if keyword.contains(" ") || keyword.contains("-") {
                    if lowered.contains(keyword) { return category }
                } else if words.contains(keyword) {
                    return category
                }
            }
        }
        return nil
    }
}
