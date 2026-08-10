import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Live Activity payload (shared by the app and the widget extension)
// What the Lock Screen and Dynamic Island show while a workout is running.
//
// Design note: the elapsed clock and the rest countdown are DATES, not numbers of
// seconds. SwiftUI renders `Text(timerInterval:)` on its own, ticking once a second
// without the app pushing anything — which matters because Live Activity updates
// are rate-limited and a per-second push would be throttled away.
#if canImport(ActivityKit) && os(iOS)
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the workout started — drives the counting-up clock.
        var startDate: Date
        /// Exercise currently being logged, empty before the first set.
        var exercise: String
        /// Sets completed so far in the whole session.
        var setsDone: Int
        /// When the current rest ends. nil when no rest is running.
        var restEndsAt: Date?
    }

    /// Fixed for the life of the activity.
    var planName: String
    var planColor: String      // hex, matches the plan's colour in the app
}
#endif
