import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if os(iOS)
import AppIntents
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
    /// SF Symbol of a cardio session; nil for a strength workout.
    var icon: String?
}
#endif

// MARK: - Rest buttons on the Lock Screen
#if os(iOS)
/// "+30 s" and "Skip" on the Live Activity. The system runs a LiveActivityIntent in
/// the app's process; the extension only needs the type, so the action travels as
/// a notification the app's rest timer listens to.
struct AdjustRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Adjust rest"
    static let isDiscoverable = false
    static let notification = Notification.Name("fittracker.adjustRest")

    /// Seconds to add; 0 ends the rest.
    @Parameter(title: "Seconds") var seconds: Int

    init() { seconds = 0 }
    init(seconds: Int) { self.seconds = seconds }

    func perform() async throws -> some IntentResult {
        await MainActor.run { NotificationCenter.default.post(name: Self.notification, object: nil, userInfo: ["seconds": seconds]) }
        return .result()
    }
}
#endif

// MARK: - Widget snapshot (written by the app, read by the widget extension)
/// The few numbers the Home / Lock Screen widget shows. The widget cannot see the
/// app's data file, so the app drops this small copy into the shared App Group
/// container every time the data changes.
struct WidgetSnapshot: Codable, Equatable {
    var nextName: String        // next workout, empty when there is none
    var nextColor: String       // hex
    var nextIcon: String        // SF Symbol
    var streak: Int
    var kcalToday: Int
    var kcalTarget: Int
    /// The day the numbers above describe (yyyy-MM-dd): past midnight they are
    /// yesterday's until the app writes again. nil in a snapshot from before v14.
    var date: String? = nil
    /// The app's language, which the widget follows instead of the device's.
    var lang: String? = nil

    static let appGroup = "group.com.marco.manzotti.fittracker"
    static let widgetKind = "FitTrackerNextWorkout"

    /// nil when the App Group is not provisioned for this build.
    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: url))
        } catch {
            appLog.error("Widget snapshot unreadable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func save() throws {
        guard let url = WidgetSnapshot.fileURL else { return }
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
