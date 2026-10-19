import Foundation
import os

/// One logger for the phone app, the watch app and the widget extension. Errors go
/// here instead of `print`, so they reach Console.app and are never just dropped.
let appLog = Logger(subsystem: "com.marco.manzotti.fittracker", category: "app")

// MARK: - Phone <-> Watch wire format
// The only code shared between the iPhone app (FitTracker) and its watchOS
// companion (FitTrackerWatch). Kept deliberately tiny and dependency-free
// (Foundation only — no SwiftUI, no UIKit, no HealthKit) so the exact same file
// compiles on both platforms. Everything travels over WatchConnectivity as a
// single JSON-encoded `Data` blob wrapped in a dictionary, which keeps us
// independent of the per-key plist-type restrictions of WCSession dictionaries.

public enum WatchKind: String, Codable {
    case strength, cardio
}

/// One startable item the watch can launch a workout for. Built on the phone
/// from the user's saved strength plans and cardio activities, then pushed to
/// the watch so the wrist UI offers exactly the same workouts as the phone.
public struct WatchActivity: Codable, Identifiable, Equatable {
    public var id: String        // strength: plan id · cardio: "cardio-<cardioTypeId>"
    public var kind: String      // WatchKind raw value
    public var name: String
    public var color: String     // hex (same palette as the phone)
    public var sub: String       // subtitle: plan.sub, or the sport label for cardio
    public var sport: String?    // Sport raw value for cardio (drives the HK activity type)
    // Strength only: the plan's exercises, each carrying the plan's default reps
    // and the per-set reps/weight from the last logged session (shown as gray
    // placeholders on the wrist). Optional + backward-compatible.
    public var exercises: [WatchExercise]?

    public init(id: String, kind: String, name: String, color: String, sub: String,
                sport: String?, exercises: [WatchExercise]? = nil) {
        self.id = id; self.kind = kind; self.name = name; self.color = color
        self.sub = sub; self.sport = sport; self.exercises = exercises
    }

    public var kindValue: WatchKind { WatchKind(rawValue: kind) ?? .cardio }
}

/// One exercise pushed to the watch for a strength plan. `reps` is the plan
/// default; `lastReps`/`lastWeight` are the previous session's per-set values
/// (empty when the exercise has never been logged) used as gray placeholders.
///
/// Timed (isometric) exercises — plank, wall sit, hollow hold — are tracked
/// natively on the wrist with a per-set countdown timer (see `kind`/`targetSec`).
/// `lastSeconds` carries the previous session's hold per set, used as the default
/// countdown start. Interval (HIIT) exercises are still logged on the phone for now.
public struct WatchExercise: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var sets: Int
    public var reps: String
    public var lastReps: [String]
    public var lastWeight: [String]
    /// ExKind raw value ("reps" | "timed" | "interval"); nil/absent => reps.
    public var kind: String?
    /// Default hold duration (seconds) for a timed exercise: the plan target.
    public var targetSec: Int?
    /// Previous session's per-set hold seconds (timed exercises) as strings.
    public var lastSeconds: [String]?
    /// Rest after a set of this exercise, seconds (plan value or the default).
    public var restSec: Int?

    public init(id: String, name: String, sets: Int, reps: String,
                lastReps: [String], lastWeight: [String],
                kind: String? = nil, targetSec: Int? = nil, lastSeconds: [String]? = nil, restSec: Int? = nil) {
        self.id = id; self.name = name; self.sets = sets; self.reps = reps
        self.lastReps = lastReps; self.lastWeight = lastWeight
        self.kind = kind; self.targetSec = targetSec; self.lastSeconds = lastSeconds; self.restSec = restSec
    }

    /// True when this exercise should be tracked as a timed isometric hold.
    public var isTimed: Bool { kind == "timed" }
}

/// Phone -> watch sync payload: the catalog of startable activities plus a bit
/// of context (current language) so the watch matches the phone's look and copy.
public struct WatchContext: Codable, Equatable {
    public var activities: [WatchActivity]
    public var lang: String      // "it" | "en"
    /// What the watch face shows: the next workout and today's readiness.
    public var glance: WatchGlance?

    public init(activities: [WatchActivity], lang: String, glance: WatchGlance? = nil) {
        self.activities = activities; self.lang = lang; self.glance = glance
    }
}

/// The next workout and today's readiness, for the complication and the Smart
/// Stack. The watch app keeps the last one in the shared App Group container.
public struct WatchGlance: Codable, Equatable {
    public var nextName: String       // empty when nothing is planned
    public var nextColor: String      // hex
    public var nextIcon: String       // SF Symbol
    public var readiness: Int?        // 0-100
    public var lang: String

    public init(nextName: String, nextColor: String, nextIcon: String, readiness: Int?, lang: String) {
        self.nextName = nextName; self.nextColor = nextColor; self.nextIcon = nextIcon
        self.readiness = readiness; self.lang = lang
    }

    private static let suite = "group.com.marco.manzotti.fittracker"
    private static let key = "watchGlance"

    public static func load() -> WatchGlance? {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchGlance.self, from: data)
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.suite)?.set(data, forKey: Self.key)
    }
}

/// Watch -> phone payload: a finished, live-tracked workout. The phone turns
/// this into a normal `WorkoutSession` (filling strength exercises from the plan
/// template so only the weights remain to be typed). `id` makes ingestion
/// idempotent if the same result arrives over more than one transport.
public struct WatchResult: Codable, Equatable {
    public var id: String        // UUID string, for de-duplication on the phone
    public var date: String      // yyyy-MM-dd
    public var kind: String      // WatchKind raw value
    public var activityId: String// matches WatchActivity.id (plan id or "cardio-…")
    public var name: String
    public var color: String
    public var sport: String?    // Sport raw value (cardio)
    public var durationSec: Int
    public var avgHR: Int?
    public var maxHR: Int?
    public var activeKcal: Int?  // active energy from HealthKit (authoritative)
    public var distanceKm: Double?
    // Strength only: the per-exercise sets logged on the wrist (reps × weight).
    public var exercises: [WatchResultExercise]?
    /// The HKWorkout the watch saved, so the phone can read everything else it
    /// measured (power, cadence, route…) from Health. Nil when the save failed.
    public var healthUUID: String?

    public init(id: String, date: String, kind: String, activityId: String, name: String,
                color: String, sport: String?, durationSec: Int, avgHR: Int?, maxHR: Int?,
                activeKcal: Int?, distanceKm: Double?, exercises: [WatchResultExercise]? = nil,
                healthUUID: String? = nil) {
        self.id = id; self.date = date; self.kind = kind; self.activityId = activityId
        self.name = name; self.color = color; self.sport = sport; self.durationSec = durationSec
        self.avgHR = avgHR; self.maxHR = maxHR; self.activeKcal = activeKcal; self.distanceKm = distanceKm
        self.exercises = exercises; self.healthUUID = healthUUID
    }
}

/// One exercise's logged sets coming back from the watch (parallel reps/weight
/// arrays, strings to match the phone's free-text set fields). For timed
/// (isometric) exercises `seconds` carries the per-set hold duration and
/// `kind` is "timed" so the phone fills the right fields; reps/weight stay empty.
public struct WatchResultExercise: Codable, Equatable {
    public var name: String
    public var reps: [String]
    public var weight: [String]
    /// Per-set hold seconds for a timed exercise (parallel to reps/weight).
    public var seconds: [String]?
    /// ExKind raw value; nil/absent => reps.
    public var kind: String?
    public init(name: String, reps: [String], weight: [String],
                seconds: [String]? = nil, kind: String? = nil) {
        self.name = name; self.reps = reps; self.weight = weight
        self.seconds = seconds; self.kind = kind
    }
}

/// Watch -> phone LIVE telemetry, streamed every few seconds while a workout is
/// running on the wrist (best-effort `sendMessage`, only when the phone is
/// reachable). It lets the phone mirror the session in real time — show live HR /
/// calories / distance and auto-fill those fields — so when the workout stops the
/// user never has to re-enter what the watch already tracked. `ended` marks the
/// final sample sent at stop.
public struct WatchLiveSample: Codable, Equatable {
    public var activityId: String
    public var kind: String              // WatchKind raw value
    public var hr: Int                   // current bpm
    public var avgHR: Int
    public var maxHR: Int
    public var kcal: Int                 // active energy so far
    public var distanceKm: Double?
    public var elapsedSec: Int
    public var exercises: [WatchResultExercise]?   // per-set values logged so far
    public var ended: Bool

    public init(activityId: String, kind: String, hr: Int, avgHR: Int, maxHR: Int,
                kcal: Int, distanceKm: Double?, elapsedSec: Int,
                exercises: [WatchResultExercise]?, ended: Bool) {
        self.activityId = activityId; self.kind = kind; self.hr = hr; self.avgHR = avgHR
        self.maxHR = maxHR; self.kcal = kcal; self.distanceKm = distanceKm
        self.elapsedSec = elapsedSec; self.exercises = exercises; self.ended = ended
    }
}

// MARK: - Transport helpers
// Both ends wrap a Codable payload in a `[String: Any]` dictionary under a known
// key so the same dictionary works for sendMessage / transferUserInfo /
// updateApplicationContext.
public enum WatchWire {
    public static let contextKey = "fittracker.ctx"    // phone -> watch (catalog)
    public static let resultKey  = "fittracker.result" // watch -> phone (finished)
    public static let liveKey    = "fittracker.live"   // watch -> phone (live telemetry)
    public static let startKey   = "fittracker.start"  // phone -> watch (start activity id)
    public static let restKey    = "fittracker.rest"   // phone -> watch (rest ends at, seconds since 1970)

    public static func encode<T: Encodable>(_ value: T, key: String) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value) else { return [:] }
        return [key: data]
    }

    public static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any], key: String) -> T? {
        guard let data = dict[key] as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
