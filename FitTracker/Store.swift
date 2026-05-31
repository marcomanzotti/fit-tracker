import SwiftUI
import Combine

final class Store: ObservableObject {
    @Published var daily: [DailyEntry] = []
    @Published var sessions: [WorkoutSession] = []
    @Published var body: [BodyEntry] = []
    @Published var plans: [WorkoutPlan] = []
    @Published var prefs: Prefs = Prefs()

    private var loaded = false
    private var bag = Set<AnyCancellable>()

    var docsURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    var dataURL: URL { docsURL.appendingPathComponent("fittracker.json") }

    init() {
        load()
        // Autosave: any change to the published collections persists after a short debounce.
        let pubs: [AnyPublisher<Void, Never>] = [
            $daily.map { _ in () }.eraseToAnyPublisher(),
            $sessions.map { _ in () }.eraseToAnyPublisher(),
            $body.map { _ in () }.eraseToAnyPublisher(),
            $plans.map { _ in () }.eraseToAnyPublisher(),
            $prefs.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(pubs)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] in self?.save() }
            .store(in: &bag)
    }

    // MARK: Persistence
    func load() {
        if let d = try? Data(contentsOf: dataURL),
           let a = try? JSONDecoder().decode(AppData.self, from: d) {
            daily = a.daily; sessions = a.sessions; body = a.body; plans = a.plans; prefs = a.prefs
        }
        if plans.isEmpty { plans = Store.defaultPlans() }
        loaded = true
    }

    func save() {
        guard loaded else { return }
        let a = AppData(daily: daily, sessions: sessions, body: body, plans: plans, prefs: prefs)
        guard let d = try? JSONEncoder().encode(a) else { return }
        try? d.write(to: dataURL, options: .atomic)
        // Rolling dated backup in Documents (visible in the Files app).
        let bk = docsURL.appendingPathComponent("backup-\(today()).json")
        try? d.write(to: bk, options: .atomic)
    }

    /// Produce a JSON file URL for sharing/export.
    func exportFile() -> URL? {
        let a = AppData(daily: daily, sessions: sessions, body: body, plans: plans, prefs: prefs)
        guard let d = try? JSONEncoder.pretty.encode(a) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fittracker-\(today()).json")
        try? d.write(to: url, options: .atomic)
        return url
    }

    func importFile(_ url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let d = try? Data(contentsOf: url),
              let a = try? JSONDecoder().decode(AppData.self, from: d) else { return false }
        daily = a.daily; sessions = a.sessions; body = a.body
        plans = a.plans.isEmpty ? Store.defaultPlans() : a.plans
        prefs = a.prefs
        return true
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }
}

// MARK: - Default starting templates (the original 4-day plan, now editable)
extension Store {
    static func defaultPlans() -> [WorkoutPlan] {
        [
            WorkoutPlan(id: "p1", name: "Push", sub: "Spalle + Petto", color: "ff5a52", exercises: [
                PlanExercise(name: "Military press bilanciere", sets: 4, reps: "8-10"),
                PlanExercise(name: "Shoulder press manubri seduto", sets: 3, reps: "10"),
                PlanExercise(name: "Lateral raise al cavo", sets: 3, reps: "12"),
                PlanExercise(name: "Panca inclinata manubri", sets: 3, reps: "10"),
                PlanExercise(name: "Cavi incrociati bassi", sets: 3, reps: "12"),
                PlanExercise(name: "Triceps pushdown al cavo", sets: 3, reps: "12")
            ]),
            WorkoutPlan(id: "p2", name: "Pull", sub: "Schiena + Bicipiti", color: "4fb8c4", exercises: [
                PlanExercise(name: "Lat machine presa larga", sets: 4, reps: "10-12"),
                PlanExercise(name: "Pulley presa stretta", sets: 3, reps: "12"),
                PlanExercise(name: "Rematore manubrio 1 braccio", sets: 3, reps: "10"),
                PlanExercise(name: "Face pull al cavo", sets: 3, reps: "15"),
                PlanExercise(name: "Curl bilanciere EZ", sets: 3, reps: "10"),
                PlanExercise(name: "Curl a martello manubri", sets: 3, reps: "12")
            ]),
            WorkoutPlan(id: "p3", name: "Gambe", sub: "Quad + Posteriori", color: "ffb000", exercises: [
                PlanExercise(name: "Leg press", sets: 4, reps: "12"),
                PlanExercise(name: "RDL singola gamba", sets: 3, reps: "10/lato"),
                PlanExercise(name: "Leg curl seduto", sets: 3, reps: "12"),
                PlanExercise(name: "Adductor machine", sets: 3, reps: "15"),
                PlanExercise(name: "Abductor machine", sets: 3, reps: "15"),
                PlanExercise(name: "Calf raise in piedi", sets: 3, reps: "15")
            ]),
            WorkoutPlan(id: "p4", name: "Spalle & Core", sub: "Postura + V-Shape", color: "ff6a00", exercises: [
                PlanExercise(name: "Arnold press manubri", sets: 4, reps: "10"),
                PlanExercise(name: "Lateral raise cavo", sets: 3, reps: "12"),
                PlanExercise(name: "Rear delt fly manubri", sets: 3, reps: "12"),
                PlanExercise(name: "Shrug manubri", sets: 3, reps: "15"),
                PlanExercise(name: "Plank laterale", sets: 3, reps: "30s/lato"),
                PlanExercise(name: "Crunch al cavo", sets: 3, reps: "15")
            ])
        ]
    }
}

// MARK: - Derived data / domain logic (ports of the web app helpers)
extension Store {
    var sortedDaily: [DailyEntry] { daily.sorted { $0.date < $1.date } }

    var lastWeight: Double {
        sortedDaily.last(where: { $0.weight != nil })?.weight ?? prefs.startWeight
    }

    func plan(_ id: String) -> WorkoutPlan? { plans.first { $0.id == id } }

    func bmi(_ w: Double) -> Double { ((w / (prefs.height * prefs.height)) * 10).rounded() / 10 }

    func bmiCategory(_ b: Double) -> (String, Color) {
        if b < 18.5 { return ("Sottopeso", Theme.blue) }
        if b < 25   { return ("Normopeso", Theme.good) }
        if b < 30   { return ("Sovrappeso", Theme.acc2) }
        return ("Obeso", Theme.red)
    }

    /// US-Navy body-fat estimate from neck & waist (cm).
    func bfNavy(waist: Double?, neck: Double?) -> Double? {
        guard let waist, let neck, waist > neck else { return nil }
        let v = 86.010 * log10(waist - neck) - 70.041 * log10(prefs.height * 100) + 36.76
        return (v * 10).rounded() / 10
    }

    func hasCheckedIn() -> Bool { daily.contains { $0.date == today() && $0.weight != nil } }

    var streak: Int {
        var dates = Set<String>()
        daily.forEach { dates.insert($0.date) }
        sessions.forEach { dates.insert($0.date) }
        var n = 0
        var d = Date()
        let cal = Calendar.current
        for _ in 0..<365 {
            let s = isoFormatter.string(from: d)
            if dates.contains(s) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
            else { break }
        }
        return n
    }

    /// Next plan to train, cycling through the plan list after the most recent session.
    func nextPlan() -> WorkoutPlan? {
        guard !plans.isEmpty else { return nil }
        guard let last = sessions.sorted(by: { $0.date > $1.date }).first,
              let idx = plans.firstIndex(where: { $0.id == last.planId }) else { return plans.first }
        return plans[(idx + 1) % plans.count]
    }

    func exercisePR(_ name: String) -> Double {
        var mx = 0.0
        for s in sessions {
            for e in s.exercises where e.name == name {
                mx = max(mx, e.maxWeight)
            }
        }
        return mx
    }

    func lastSession(forPlan id: String) -> WorkoutSession? {
        sessions.filter { $0.planId == id && $0.date != today() }
            .sorted { $0.date > $1.date }.first
    }

    /// Suggested next weight: previous session's max + 2.5kg if every set was completed.
    func suggested(planId: String, exercise: String) -> Double? {
        guard let last = lastSession(forPlan: planId),
              let ex = last.exercises.first(where: { $0.name == exercise }),
              !ex.sets.isEmpty else { return nil }
        let allDone = ex.sets.allSatisfy { pf($0.reps) > 0 && pf($0.weight) > 0 }
        return allDone ? ex.maxWeight + 2.5 : nil
    }

    func estimateCalories(_ s: WorkoutSession) -> Int {
        let totSets = s.totalSets
        let vol = s.volume
        return Int((vol * 0.022 + Double(totSets) * 3 + 60).rounded())
    }

    struct WeekStat { var avgWeight: Double?; var sessions: Int }
    func weekStats(offset: Int) -> WeekStat {
        let cal = Calendar.current
        let now = Date()
        let dow = (cal.component(.weekday, from: now) + 5) % 7   // Monday = 0
        var mon = cal.date(byAdding: .day, value: -dow - offset * 7, to: cal.startOfDay(for: now))!
        mon = cal.startOfDay(for: mon)
        let sun = cal.date(byAdding: .day, value: 7, to: mon)!
        func inRange(_ ds: String) -> Bool {
            guard let d = isoFormatter.date(from: ds) else { return false }
            return d >= mon && d < sun
        }
        let dw = daily.filter { inRange($0.date) && $0.weight != nil }.compactMap { $0.weight }
        let avg = dw.isEmpty ? nil : ((dw.reduce(0, +) / Double(dw.count)) * 10).rounded() / 10
        return WeekStat(avgWeight: avg, sessions: sessions.filter { inRange($0.date) }.count)
    }

    struct PRInfo { var weight: Double; var date: String? }
    /// PR per exercise name across all plans + sessions.
    func allPRs() -> [String: PRInfo] {
        var prs: [String: PRInfo] = [:]
        for p in plans { for e in p.exercises { if prs[e.name] == nil { prs[e.name] = PRInfo(weight: 0, date: nil) } } }
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            for e in s.exercises {
                let w = e.maxWeight
                if w >= (prs[e.name]?.weight ?? 0) { prs[e.name] = PRInfo(weight: w, date: s.date) }
            }
        }
        return prs
    }

    /// Distinct exercise names from every plan, in plan order.
    func allExerciseNames() -> [(group: String, name: String)] {
        var out: [(String, String)] = []
        for p in plans { for e in p.exercises { out.append((p.name, e.name)) } }
        return out
    }

    struct ExPoint { var date: String; var maxW: Double; var vol: Double }
    func exerciseHistory(_ name: String) -> [ExPoint] {
        sessions.filter { s in s.exercises.contains { $0.name == name } }
            .sorted { $0.date < $1.date }
            .map { s in
                let ex = s.exercises.first { $0.name == name }!
                return ExPoint(date: fmtShort(s.date), maxW: ex.maxWeight, vol: ex.volume.rounded())
            }
    }

    var bodyLatest: BodyEntry? { body.sorted { $0.date > $1.date }.first }
    var bodyPrev: BodyEntry? {
        let s = body.sorted { $0.date > $1.date }
        return s.count > 1 ? s[1] : nil
    }

    /// Effective body-fat %: manual override wins, otherwise Navy estimate.
    var currentBF: Double? {
        guard let bl = bodyLatest else { return nil }
        return bl.bfManual ?? bfNavy(waist: bl.waist, neck: bl.neck)
    }

    // MARK: Mutations
    func saveCheckIn(weight: Double?, sleep: Int?) {
        let t = today()
        var entry = daily.first(where: { $0.date == t }) ?? DailyEntry(date: t)
        if let weight { entry.weight = weight }
        if let sleep { entry.sleep = sleep }
        daily.removeAll { $0.date == t }
        daily.append(entry)
    }

    func saveBodyFat(_ v: Double) {
        let t = today()
        var rec = (bodyLatest?.date == t ? bodyLatest! : BodyEntry(date: t))
        rec.bfManual = v
        body.removeAll { $0.date == t }
        body.append(rec)
    }

    func saveMeasurements(_ values: [String: Double]) {
        let t = today()
        var rec = (bodyLatest?.date == t ? bodyLatest! : BodyEntry(date: t))
        for (k, v) in values where v > 0 { rec.set(k, v) }
        body.removeAll { $0.date == t }
        body.append(rec)
    }
}
