import Foundation
import ActivityKit

struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data
        var endTime: Date
        var modeName: String
        var isPaused: Bool
        var remainingSeconds: Int
    }

    // Static data
    var totalSeconds: Int
}
