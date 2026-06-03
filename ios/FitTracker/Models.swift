import Foundation

// MARK: - Parsing helper (mirrors the web app's pf(): accepts "," or ".")
func pf(_ s: String) -> Double {
    Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
}

// IMPORTANT for backward compatibility: every field added after the original
// schema is Optional. Swift's synthesized Codable throws on a missing key for a
// non-optional property (it ignores the default value), so older saved JSON would
// fail to decode otherwise. Optionals decode to nil when absent.

// MARK: - Daily check-in (weight + sleep + optional nutrition / recovery)
struct DailyEntry: Codable, Identifiable, Equatable {
    var date: String          // yyyy-MM-dd
    var weight: Double?
    var sleep: Int?
    // Nutrition (optional)
    var kcal: Int?            // energy eaten
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var salt: Double?
    var steps: Int?
    var stepsManual: Bool?    // true once the user types a step count — Health stops overwriting it for the day
    // Recovery (optional, manual entry)
    var rmssd: Double?        // HRV RMSSD typed from an external HRV app
    var restHR: Int?          // morning resting / waking heart rate
    var hrvSDNN: Double?      // HRV SDNN imported from Apple Health (ms)
    var sleepHR: Int?         // average heart rate during sleep (Health / manual)
    var sleepHours: Double?   // sleep duration in hours (Health asleep total)
    // Daily activity, imported from Apple Health (gap-fill, any paired watch)
    var activeKcal: Int?      // active energy burned during the day
    var exerciseMin: Int?     // exercise minutes (Apple "Move" equivalent)
    var vo2max: Double?       // cardiorespiratory fitness (mL/kg/min), Apple Health
    // Per-meal nutrition breakdown (optional, backward compatible). When present,
    // its kcal sum is authoritative for the day; the quick one-tap total above
    // (`kcal`) is used when no meals are logged. `meals` keys are MealSlot raw
    // values ("breakfast"/"lunch"/"dinner"/"snacks").
    var meals: [String: MealEntry]?
    /// Day-level individual foods (food + amount), for users who log food-by-food
    /// without assigning a meal. Sums into the day total alongside meals.
    var foods: [FoodLog]?
    var id: String { date }

    /// True when this day carries any nutrition data (quick total, per-meal, or
    /// individual foods).
    var hasNutrition: Bool {
        (kcal ?? 0) > 0
        || (meals?.values.contains { !$0.isEmpty } ?? false)
        || !(foods?.isEmpty ?? true)
    }
    /// Effective day total kcal: per-meal effective sums + day-level foods; the
    /// quick one-tap total is the fallback when nothing structured is logged.
    var totalKcal: Int {
        var s = 0
        if let meals { s += meals.values.reduce(0) { $0 + $1.effKcal } }
        if let foods { s += foods.reduce(0) { $0 + $1.kcal } }
        return s > 0 ? s : (kcal ?? 0)
    }
    var totalProtein: Double { macroTotal(\.effProtein, \.protein, quick: protein) }
    var totalCarbs: Double { macroTotal(\.effCarbs, \.carbs, quick: carbs) }
    var totalFat: Double { macroTotal(\.effFat, \.fat, quick: fat) }

    /// Sum a macro across meals (effective) + day foods, falling back to the quick
    /// total when nothing structured is present.
    private func macroTotal(_ mealKP: KeyPath<MealEntry, Double>,
                            _ foodKP: KeyPath<FoodLog, Double>, quick: Double?) -> Double {
        var s = 0.0
        if let meals { s += meals.values.reduce(0.0) { $0 + $1[keyPath: mealKP] } }
        if let foods { s += foods.reduce(0.0) { $0 + $1[keyPath: foodKP] } }
        return s > 0 ? s : (quick ?? 0)
    }
}

// MARK: - Per-meal nutrition entry
// A meal can be logged two ways: typed totals (kcal/macros) OR a list of foods
// (food + amount). When foods are present they are authoritative and the typed
// totals are ignored; the `eff*` accessors expose whichever applies.
struct MealEntry: Codable, Equatable {
    var kcal: Int = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var foods: [FoodLog]? = nil

    var hasFoods: Bool { !(foods?.isEmpty ?? true) }
    var effKcal: Int { hasFoods ? foods!.reduce(0) { $0 + $1.kcal } : kcal }
    var effProtein: Double { hasFoods ? foods!.reduce(0) { $0 + $1.protein } : protein }
    var effCarbs: Double { hasFoods ? foods!.reduce(0) { $0 + $1.carbs } : carbs }
    var effFat: Double { hasFoods ? foods!.reduce(0) { $0 + $1.fat } : fat }
    var isEmpty: Bool { kcal == 0 && protein == 0 && carbs == 0 && fat == 0 && !hasFoods }
}

// MARK: - Saved food (nutrition per 100 g/ml) + a logged amount of it
// A FoodItem is a reusable entry in the user's local food list: its macros are
// stored per 100 g (or 100 ml for liquids). A FoodLog is one logged use of a
// food — the amount eaten plus a snapshot of the per-100 macros, so later edits
// to the saved food never rewrite past days, and one-off foods work without
// saving. Both are Codable and fully backward compatible (new optional fields).
struct FoodItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var barcode: String?
    var k100: Double = 0       // kcal per 100 g/ml
    var p100: Double = 0       // protein
    var c100: Double = 0       // carbs
    var f100: Double = 0       // fat
    var liquid: Bool = false   // measured in ml rather than g (display only)
    var lastUsed: String?      // yyyy-MM-dd, for "recent" sorting
    var unit: String { liquid ? "ml" : "g" }

    /// Build a logged use of this food for `grams` (or ml) eaten.
    func log(_ grams: Double) -> FoodLog {
        FoodLog(foodId: id, name: name, grams: grams, k100: k100, p100: p100, c100: c100, f100: f100)
    }
}

struct FoodLog: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var foodId: String?        // reference to a saved FoodItem (nil if one-off)
    var name: String
    var grams: Double          // amount eaten (g or ml)
    var k100: Double           // per-100 snapshot at log time
    var p100: Double
    var c100: Double
    var f100: Double

    private func scale(_ per100: Double) -> Double { (per100 * grams / 100 * 10).rounded() / 10 }
    var kcal: Int { Int((k100 * grams / 100).rounded()) }
    var protein: Double { scale(p100) }
    var carbs: Double { scale(c100) }
    var fat: Double { scale(f100) }
}

// MARK: - The four meal slots (breakfast / lunch / dinner / snacks)
enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks
    var id: String { rawValue }
    var labelKey: String { "meal." + rawValue }
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        // carrot.fill stays reserved for the Nutrition tab; snacks uses a distinct
        // filled glyph so the two never read as the same thing.
        case .snacks:    return "popcorn.fill"
        }
    }
    var color: String {
        switch self {
        case .breakfast: return "ffb000"
        case .lunch:     return "ffe000"
        case .dinner:    return "b08fff"
        case .snacks:    return "7fc950"
        }
    }
}

// MARK: - A single logged set
struct SetEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var reps: String = ""
    var weight: String = ""
    /// Effort value for this set. Meaning depends on the parent exercise's effortMode:
    /// "rir" = reps in reserve (0-10), "rpe" = perceived exertion (1-10), "fail" = 1 if hit failure.
    var effortVal: Int? = nil

    var filled: Bool { pf(reps) > 0 || pf(weight) > 0 }
}

// MARK: - Training method for an exercise (supersets etc.)
enum TrainMethod: String, Codable, CaseIterable {
    case normal, superset, dropset, restpause, giant
    var short: String {
        switch self {
        case .normal:    return ""
        case .superset:  return "SS"
        case .dropset:   return "DROP"
        case .restpause: return "RP"
        case .giant:     return "GIANT"
        }
    }
}

// MARK: - Effort tracking scale for per-set feedback
/// "rir" = reps in reserve (buffer), "rpe" = rating of perceived exertion, "fail" = hit failure
enum EffortMode: String, Codable, CaseIterable {
    case rir, rpe, fail
    var label: String {
        switch self {
        case .rir:  return "RIR"
        case .rpe:  return "RPE"
        case .fail: return "FAIL"
        }
    }
}

// MARK: - An exercise as logged inside a session
struct LoggedExercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var sets: [SetEntry] = []
    var notes: String = ""
    /// Target string ("4×8-10") shown while logging. Not persisted as essential data.
    var target: String = ""
    // Superset / method (optional, backward compatible)
    var supersetGroup: Int?           // exercises with the same group id form a superset
    var method: String?               // TrainMethod raw value
    /// Per-set effort tracking scale: EffortMode raw value, or nil (disabled).
    var effortMode: String? = nil
    /// True when this is a bodyweight exercise: weight field means additional load.
    var isBodyweight: Bool? = nil

    var volume: Double { sets.reduce(0) { $0 + pf($1.reps) * pf($1.weight) } }
    var maxWeight: Double { sets.map { pf($0.weight) }.max() ?? 0 }
    var trainMethod: TrainMethod { TrainMethod(rawValue: method ?? "normal") ?? .normal }
    var effortScale: EffortMode? { effortMode.flatMap { EffortMode(rawValue: $0) } }
    var bodyweight: Bool { isBodyweight == true }
}

// MARK: - Sport kinds
enum Sport: String, Codable, CaseIterable {
    case strength, running, swimming, cycling, walking, other
    var label: String { L.t("sport." + rawValue) }
    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .running:  return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .cycling:  return "figure.outdoor.cycle"
        case .walking:  return "figure.walk"
        case .other:    return "bolt.heart.fill"
        }
    }
    var color: String {
        switch self {
        case .strength: return "ffe000"
        case .running:  return "ff5a52"
        case .swimming: return "4fb8c4"
        case .cycling:  return "7fc950"
        case .walking:  return "b08fff"
        case .other:    return "ffb000"
        }
    }
    var isCardio: Bool { self != .strength }
}

// MARK: - A saved, customizable cardio activity type (mirrors WorkoutPlan for
// strength days: its own name, color and underlying sport, fully editable, and
// persisted so a custom "Other" activity name never has to be retyped).
struct CardioType: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var sport: String          // Sport raw value (drives icon + calorie MET)
    var color: String          // hex from Theme.cardioColors (customizable)
    var sub: String?           // optional editable subtitle (mirrors WorkoutPlan.sub)

    var sportType: Sport { Sport(rawValue: sport) ?? .other }
}

// MARK: - A completed workout session (strength or cardio)
struct WorkoutSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: String
    var planId: String
    var planName: String       // snapshot, survives plan deletion
    var planColor: String      // snapshot hex
    var exercises: [LoggedExercise] = []
    // Internal-load / cardio fields (all optional, backward compatible)
    var sport: String?         // Sport raw value; nil => strength
    var durationMin: Int?      // legacy whole-minute duration (kept for old data)
    var durationSec: Int?      // canonical duration in seconds (H/M/S input)
    var rpe: Int?              // session global RPE 1-10 (Borg CR10) for sRPE
    var avgHR: Int?            // average heart rate (manual) for TRIMP
    var maxHRSes: Int?         // max heart rate during session (manual)
    var rmssd: Double?         // RMSSD typed for this session (optional)
    var distanceKm: Double?    // running / cycling / walking
    var paceManual: Double?    // user pace/speed override in the sport's native unit
    var elevationM: Double?    // optional climb
    var poolLengthM: Int?      // swimming pool length
    var caloriesManual: Int?   // user override of the calorie estimate
    /// HKWorkout UUID when this session was imported from Apple Health (e.g. a
    /// Garmin/Fitbit/Polar/Huawei watch that synced to Health). Used to dedupe
    /// re-imports and to badge the session as externally sourced.
    var healthUUID: String?
    /// Human-readable origin of an imported session: the Health source app name
    /// ("Garmin Connect", "Polar Flow") or an imported file name. nil = logged in
    /// the app. Drives the "imported" badge.
    var source: String?

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var sportType: Sport { Sport(rawValue: sport ?? "strength") ?? .strength }

    /// Canonical duration in seconds. Prefers the new H/M/S value, falling back to
    /// the legacy whole-minute field so old sessions keep working.
    var durationSeconds: Int? {
        if let s = durationSec, s > 0 { return s }
        if let m = durationMin, m > 0 { return m * 60 }
        return nil
    }
    /// Duration in (possibly fractional) minutes for the science formulas.
    var durationMinutesD: Double? { durationSeconds.map { Double($0) / 60.0 } }

    /// sRPE internal load = duration (min) × session RPE.
    var sRPE: Double? {
        guard let d = durationMinutesD, let r = rpe, d > 0, r > 0 else { return nil }
        return d * Double(r)
    }

    /// Pace/speed unit for this sport: cycling tracks speed (km/h), swimming
    /// tracks min/100m, everything else min/km.
    var paceIsSpeed: Bool { sportType == .cycling }
    var paceUnit: String {
        switch sportType {
        case .cycling:  return "km/h"
        case .swimming: return "/100m"
        default:        return "/km"
        }
    }
    /// Auto pace/speed computed from distance + duration, in the native unit.
    var autoPace: Double? {
        guard let mins = durationMinutesD, mins > 0, let dist = distanceKm, dist > 0 else { return nil }
        switch sportType {
        case .cycling:  return dist / (mins / 60)            // km/h
        case .swimming: return mins / (dist * 1000 / 100)    // min per 100 m
        default:        return mins / dist                    // min per km
        }
    }
    /// Effective pace: a manual override wins, otherwise the auto value.
    var effectivePace: Double? { paceManual ?? autoPace }

    /// Legacy: average pace in min/km (running/walking) or min/100m (swimming).
    var pace: Double? {
        guard let mins = durationMinutesD, mins > 0, let dist = distanceKm, dist > 0 else { return nil }
        if sportType == .swimming { return mins / (dist * 1000 / 100) }
        return mins / dist
    }
}

// MARK: - Body measurements
struct BodyEntry: Codable, Identifiable, Equatable {
    var date: String
    var waist: Double?
    var chest: Double?
    var arms: Double?
    var legs: Double?
    var neck: Double?
    var hips: Double?
    var bfManual: Double?
    var id: String { date }

    func value(for key: String) -> Double? {
        switch key {
        case "waist": return waist
        case "chest": return chest
        case "arms":  return arms
        case "legs":  return legs
        case "neck":  return neck
        case "hips":  return hips
        default:      return nil
        }
    }
    mutating func set(_ key: String, _ v: Double) {
        switch key {
        case "waist": waist = v
        case "chest": chest = v
        case "arms":  arms = v
        case "legs":  legs = v
        case "neck":  neck = v
        case "hips":  hips = v
        default: break
        }
    }
}

struct MeasureField: Identifiable {
    let key: String
    let label: String
    let color: String
    var id: String { key }
}

let measureFields: [MeasureField] = [
    MeasureField(key: "waist", label: "Vita",    color: "ff5a52"),
    MeasureField(key: "chest", label: "Petto",   color: "4fb8c4"),
    MeasureField(key: "arms",  label: "Braccia", color: "ffb000"),
    MeasureField(key: "legs",  label: "Gambe",   color: "7fc950"),
    MeasureField(key: "neck",  label: "Collo",   color: "b08fff"),
    MeasureField(key: "hips",  label: "Fianchi", color: "ffe000")
]

// MARK: - Custom workout plans (fully editable)
struct PlanExercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var sets: Int = 3
    var reps: String = "10"
    // Superset / method (optional)
    var supersetGroup: Int?
    var method: String?
    /// Per-set effort tracking scale for this exercise (EffortMode raw value, or nil = off).
    var effortMode: String? = nil
    /// True when this is a bodyweight exercise.
    var isBodyweight: Bool? = nil
    /// Muscle group (MuscleGroup raw value) assigned in the editor; propagated to
    /// the exercise library on save so Progress can browse by muscle.
    var muscle: String? = nil

    var trainMethod: TrainMethod { TrainMethod(rawValue: method ?? "normal") ?? .normal }
    var effortScale: EffortMode? { effortMode.flatMap { EffortMode(rawValue: $0) } }
    var bodyweight: Bool { isBodyweight == true }
}

struct WorkoutPlan: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var sub: String = ""
    var color: String = "ffe000"
    var exercises: [PlanExercise] = []
}

// MARK: - Goal / energy mode
enum GoalMode: String, Codable, CaseIterable {
    case cut, maintain, bulk
    /// Typical weekly bodyweight change (% of bodyweight) midpoint.
    var defaultWeeklyPct: Double {
        switch self {
        case .cut:      return -0.6
        case .maintain: return 0.0
        case .bulk:     return 0.25
        }
    }
    var calorieAdjust: Double {     // fraction applied to TDEE as a starting point
        switch self {
        case .cut:      return -0.18
        case .maintain: return 0.0
        case .bulk:     return 0.12
        }
    }
}

// MARK: - Activity level (TDEE multiplier)
enum Activity: String, Codable, CaseIterable {
    case sedentary, light, moderate, high, athlete
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light:     return 1.375
        case .moderate:  return 1.55
        case .high:      return 1.725
        case .athlete:   return 1.9
        }
    }
}

// MARK: - User preferences / goals / profile
struct Prefs: Codable, Equatable {
    var timer: Int = 60
    // Clean, generic starting numbers (male defaults); the onboarding swaps in
    // female defaults when the user picks "Female". Existing users keep their
    // saved values — these only seed a brand-new install.
    var goalWeight: Double = 75
    var goalBF: Double = 15
    var startWeight: Double = 80
    var height: Double = 1.80
    // --- everything below is optional for backward-compatible decoding ---
    var language: String?      // "it" | "en"; nil => follow the device
    var onboarded: Bool?       // has the first-launch onboarding completed
    var sex: String?           // "m" | "f"
    var birthDate: String?     // yyyy-MM-dd
    var goalMode: String?      // GoalMode raw value
    var weeklyRate: Double?    // target kg/week, signed (+gain / -loss)
    var activity: String?      // Activity raw value
    var trainingDays: Int?     // sessions/week planned
    var restingHR: Int?        // resting HR for TRIMP / zones
    var maxHR: Int?            // measured max HR (else estimated from age)
    var sleepTracking: Bool?   // prompt for sleep score (default true)
    /// Optional weekly schedule: exactly 7 entries, Monday..Sunday. Each entry is
    /// a plan id, a cardio-type id, "rest", or "" (auto/none). When any slot is
    /// assigned, the "next workout" follows this weekday schedule; otherwise it
    /// falls back to simple rotation through the plan list.
    var schedule: [String]?
    var healthKit: Bool?       // user opted into Apple Health import
    /// Which Health categories to import (keys in HealthCategory.allKeys). nil =>
    /// all daily metrics on (the long-standing default). Lets the user pick exactly
    /// what flows in from Apple Health.
    var healthImport: [String]?
    /// Import past workouts recorded by other watches (Garmin/Fitbit/…). Default
    /// OFF: different watch formats don't always translate cleanly into the app.
    var importWorkouts: Bool?
    var units: String?         // "metric" | "imperial"; nil => metric
    /// Days explicitly marked as rest (yyyy-MM-dd). A rest day is not a session,
    /// just a marker shown with a dedicated icon/color on the week strip and
    /// calendar so missed days can be logged as intentional recovery.
    var restDays: [String]?

    // Convenience accessors -----------------------------------------------
    var langCode: String {
        if let language, language == "it" || language == "en" { return language }
        return Locale.preferredLanguages.first?.hasPrefix("it") == true ? "it" : "en"
    }
    var didOnboard: Bool { onboarded == true }
    var sex_: String { sex ?? "m" }
    var goal: GoalMode { GoalMode(rawValue: goalMode ?? "maintain") ?? .maintain }
    var activityLevel: Activity { Activity(rawValue: activity ?? "moderate") ?? .moderate }
    var sleepEnabled: Bool { sleepTracking ?? true }

    var age: Int? {
        guard let birthDate, let d = isoFormatter.date(from: birthDate) else { return nil }
        let yrs = Calendar.current.dateComponents([.year], from: d, to: Date()).year
        return yrs.map { max(0, $0) }
    }
    /// Estimated max HR: measured value wins, else Tanaka (208 - 0.7·age).
    var estMaxHR: Int {
        if let maxHR, maxHR > 0 { return maxHR }
        let a = Double(age ?? 30)
        return Int((208 - 0.7 * a).rounded())
    }
    var restHRorDefault: Int { (restingHR ?? 0) > 0 ? restingHR! : 60 }
    var healthKitEnabled: Bool { healthKit == true }
    /// Selected Health import categories — defaults to every daily metric on.
    var healthCategories: Set<String> { Set(healthImport ?? HealthCategory.allKeys) }
    func importsHealth(_ key: String) -> Bool { healthCategories.contains(key) }
    var importWorkoutsEnabled: Bool { importWorkouts == true }
    var imperial: Bool { units == "imperial" }
    var restDaySet: Set<String> { Set(restDays ?? []) }
    /// Schedule normalized to exactly 7 slots (Mon..Sun); missing -> all empty.
    var weekSchedule: [String] {
        guard let s = schedule, s.count == 7 else { return Array(repeating: "", count: 7) }
        return s
    }
    /// True when at least one weekday has a real assignment (not "" / "rest").
    var hasSchedule: Bool { weekSchedule.contains { !$0.isEmpty && $0 != "rest" } }
    /// +1 if the goal is to gain weight, -1 if to lose, 0 if maintain-ish.
    func goalDirection(current: Double) -> Int {
        let diff = goalWeight - current
        if abs(diff) < 0.3 { return 0 }
        return diff > 0 ? 1 : -1
    }
}

// MARK: - Apple Health import categories (user-selectable)
/// The daily Health metrics the app can pull in. The user toggles these in
/// Settings; only selected ones are read and gap-filled into daily entries.
enum HealthCategory: String, CaseIterable, Identifiable {
    case steps, restHR, hrv, sleep, sleepHR, activeKcal, exerciseMin, vo2max
    var id: String { rawValue }
    static var allKeys: [String] { allCases.map { $0.rawValue } }
    var labelKey: String { "hk.cat." + rawValue }
    var icon: String {
        switch self {
        case .steps:       return "figure.walk"
        case .restHR:      return "heart.fill"
        case .hrv:         return "waveform.path.ecg"
        case .sleep:       return "bed.double.fill"
        case .sleepHR:     return "heart.text.square.fill"
        case .activeKcal:  return "flame.fill"
        case .exerciseMin: return "timer"
        case .vo2max:      return "lungs.fill"
        }
    }
}

// MARK: - Saved exercise entry (exercise library)
// Auto-populated the first time any exercise is logged, so a user who drops an
// exercise for months can still find it (with its full history) in the library.
struct ExerciseItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var isBodyweight: Bool = false
    var lastUsed: String?      // yyyy-MM-dd, for ordering
    /// Movement family this exercise rolls up to for progress/PRs. Variants of the
    /// same movement (e.g. "Wide-grip lat pulldown", a rear-delt variation) share a
    /// base so their progress reads as one line. nil => its own name is the base.
    var base: String?
    /// Muscle-group key (MuscleGroup raw value) for browsing the Progress picker.
    var category: String?
}

// MARK: - Muscle-group categories (for browsing exercises by area)
enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest, back, legs, shoulders, arms, core, fullbody, cardio, other
    var id: String { rawValue }
    var labelKey: String { "mg." + rawValue }
    var color: String {
        switch self {
        case .chest:     return "ff5a52"
        case .back:      return "4fb8c4"
        case .legs:      return "ffb000"
        case .shoulders: return "b08fff"
        case .arms:      return "7fc950"
        case .core:      return "ff5da2"
        case .fullbody:  return "ffe000"
        case .cardio:    return "53a8ff"
        case .other:     return "8a857d"
        }
    }
}

// MARK: - The whole persisted document
struct AppData: Codable {
    var daily: [DailyEntry] = []
    var sessions: [WorkoutSession] = []
    var body: [BodyEntry] = []
    var plans: [WorkoutPlan] = []
    var prefs: Prefs = Prefs()
    var cardioTypes: [CardioType]? = nil       // optional for backward-compatible decoding
    var foods: [FoodItem]? = nil               // saved local food list (per-100 macros)
    var exerciseItems: [ExerciseItem]? = nil   // saved exercise library (auto-populated)
}
