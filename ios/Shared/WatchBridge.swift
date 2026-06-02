import Foundation

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
public struct WatchExercise: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var sets: Int
    public var reps: String
    public var lastReps: [String]
    public var lastWeight: [String]

    public init(id: String, name: String, sets: Int, reps: String,
                lastReps: [String], lastWeight: [String]) {
        self.id = id; self.name = name; self.sets = sets; self.reps = reps
        self.lastReps = lastReps; self.lastWeight = lastWeight
    }
}

/// Phone -> watch sync payload: the catalog of startable activities plus a bit
/// of context (current language) so the watch matches the phone's look and copy.
public struct WatchContext: Codable, Equatable {
    public var activities: [WatchActivity]
    public var lang: String      // "it" | "en"

    public init(activities: [WatchActivity], lang: String) {
        self.activities = activities; self.lang = lang
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

    public init(id: String, date: String, kind: String, activityId: String, name: String,
                color: String, sport: String?, durationSec: Int, avgHR: Int?, maxHR: Int?,
                activeKcal: Int?, distanceKm: Double?, exercises: [WatchResultExercise]? = nil) {
        self.id = id; self.date = date; self.kind = kind; self.activityId = activityId
        self.name = name; self.color = color; self.sport = sport; self.durationSec = durationSec
        self.avgHR = avgHR; self.maxHR = maxHR; self.activeKcal = activeKcal; self.distanceKm = distanceKm
        self.exercises = exercises
    }
}

/// One exercise's logged sets coming back from the watch (parallel reps/weight
/// arrays, strings to match the phone's free-text set fields).
public struct WatchResultExercise: Codable, Equatable {
    public var name: String
    public var reps: [String]
    public var weight: [String]
    public init(name: String, reps: [String], weight: [String]) {
        self.name = name; self.reps = reps; self.weight = weight
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

    public static func encode<T: Encodable>(_ value: T, key: String) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value) else { return [:] }
        return [key: data]
    }

    public static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any], key: String) -> T? {
        guard let data = dict[key] as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
