import Foundation

// MARK: - Parsing helper (mirrors the web app's pf(): accepts "," or ".")
func pf(_ s: String) -> Double {
    Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
}

// MARK: - Daily check-in (weight + sleep score)
struct DailyEntry: Codable, Identifiable, Equatable {
    var date: String          // yyyy-MM-dd
    var weight: Double?
    var sleep: Int?
    var id: String { date }
}

// MARK: - A single logged set
struct SetEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var reps: String = ""
    var weight: String = ""

    var filled: Bool { pf(reps) > 0 || pf(weight) > 0 }
}

// MARK: - An exercise as logged inside a session
struct LoggedExercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var sets: [SetEntry] = []
    var notes: String = ""
    /// Target string ("4×8-10") shown while logging. Not persisted as essential data.
    var target: String = ""

    var volume: Double { sets.reduce(0) { $0 + pf($1.reps) * pf($1.weight) } }
    var maxWeight: Double { sets.map { pf($0.weight) }.max() ?? 0 }
}

// MARK: - A completed workout session
struct WorkoutSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: String
    var planId: String
    var planName: String       // snapshot, survives plan deletion
    var planColor: String      // snapshot hex
    var exercises: [LoggedExercise] = []

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
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
    MeasureField(key: "hips",  label: "Fianchi", color: "ff6a00")
]

// MARK: - Custom workout plans (fully editable)
struct PlanExercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var sets: Int = 3
    var reps: String = "10"
}

struct WorkoutPlan: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var sub: String = ""
    var color: String = "ff6a00"
    var exercises: [PlanExercise] = []
}

// MARK: - User preferences / goals
struct Prefs: Codable, Equatable {
    var timer: Int = 60
    var goalWeight: Double = 80
    var goalBF: Double = 15
    var startWeight: Double = 88
    var height: Double = 1.85
}

// MARK: - The whole persisted document
struct AppData: Codable {
    var daily: [DailyEntry] = []
    var sessions: [WorkoutSession] = []
    var body: [BodyEntry] = []
    var plans: [WorkoutPlan] = []
    var prefs: Prefs = Prefs()
}
