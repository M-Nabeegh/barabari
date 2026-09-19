import Foundation

enum SplitMethod: Equatable, Codable, Sendable {
    case equal
    case exact([UUID: Int64])
    case percentage([UUID: Int64])
    case shares([UUID: Int64])
}
