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
    // Recovery (optional, manual entry)
    var rmssd: Double?        // HRV RMSSD typed from an external HRV app
    var restHR: Int?          // morning resting heart rate
    var id: String { date }
}

// MARK: - A single logged set
struct SetEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var reps: String = ""
    var weight: String = ""

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

    var volume: Double { sets.reduce(0) { $0 + pf($1.reps) * pf($1.weight) } }
    var maxWeight: Double { sets.map { pf($0.weight) }.max() ?? 0 }
    var trainMethod: TrainMethod { TrainMethod(rawValue: method ?? "normal") ?? .normal }
}

// MARK: - Sport kinds
enum Sport: String, Codable, CaseIterable {
    case strength, running, swimming, cycling, walking, other
    var label: String {
        switch self {
        case .strength: return "Forza"
        case .running:  return "Corsa"
        case .swimming: return "Nuoto"
        case .cycling:  return "Bici"
        case .walking:  return "Camminata"
        case .other:    return "Altro"
        }
    }
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
        case .strength: return "ffd21e"
        case .running:  return "ff5a52"
        case .swimming: return "4fb8c4"
        case .cycling:  return "7fc950"
        case .walking:  return "b08fff"
        case .other:    return "ffb000"
        }
    }
    var isCardio: Bool { self != .strength }
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
    var durationMin: Int?      // session duration in minutes (for sRPE / TRIMP / pace)
    var rpe: Int?              // session global RPE 1-10 (Borg CR10) for sRPE
    var avgHR: Int?            // average heart rate (manual) for TRIMP
    var maxHRSes: Int?         // max heart rate during session (manual)
    var rmssd: Double?         // RMSSD typed for this session (optional)
    var distanceKm: Double?    // running / cycling / walking
    var elevationM: Double?    // optional climb
    var poolLengthM: Int?      // swimming pool length
    var caloriesManual: Int?   // user override of the calorie estimate

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var sportType: Sport { Sport(rawValue: sport ?? "strength") ?? .strength }
    /// sRPE internal load = duration (min) × session RPE.
    var sRPE: Double? {
        guard let d = durationMin, let r = rpe, d > 0, r > 0 else { return nil }
        return Double(d * r)
    }
    /// Average pace in min/km (running/walking) or min/100m (swimming).
    var pace: Double? {
        guard let d = durationMin, d > 0 else { return nil }
        if sportType == .swimming, let dist = distanceKm, dist > 0 {
            return Double(d) / (dist * 1000 / 100)   // min per 100 m
        }
        if let dist = distanceKm, dist > 0 { return Double(d) / dist }   // min per km
        return nil
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
    MeasureField(key: "hips",  label: "Fianchi", color: "ffd21e")
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

    var trainMethod: TrainMethod { TrainMethod(rawValue: method ?? "normal") ?? .normal }
}

struct WorkoutPlan: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var sub: String = ""
    var color: String = "ffd21e"
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
    var goalWeight: Double = 80
    var goalBF: Double = 15
    var startWeight: Double = 88
    var height: Double = 1.85
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
    /// +1 if the goal is to gain weight, -1 if to lose, 0 if maintain-ish.
    func goalDirection(current: Double) -> Int {
        let diff = goalWeight - current
        if abs(diff) < 0.3 { return 0 }
        return diff > 0 ? 1 : -1
    }
}

// MARK: - The whole persisted document
struct AppData: Codable {
    var daily: [DailyEntry] = []
    var sessions: [WorkoutSession] = []
    var body: [BodyEntry] = []
    var plans: [WorkoutPlan] = []
    var prefs: Prefs = Prefs()
}
