import SwiftUI
import Combine

final class Store: ObservableObject {
    @Published var daily: [DailyEntry] = []
    @Published var sessions: [WorkoutSession] = []
    @Published var body: [BodyEntry] = []
    @Published var plans: [WorkoutPlan] = []
    @Published var cardioTypes: [CardioType] = []
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
            $cardioTypes.map { _ in () }.eraseToAnyPublisher(),
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
            cardioTypes = a.cardioTypes ?? []
        }
        if plans.isEmpty { plans = Store.defaultPlans() }
        if cardioTypes.isEmpty { cardioTypes = Store.defaultCardioTypes() }
        L.lang = prefs.langCode
        loaded = true
    }

    /// Keep the global localization language in sync with the stored preference.
    func syncLang() { L.lang = prefs.langCode }

    func save() {
        guard loaded else { return }
        let a = AppData(daily: daily, sessions: sessions, body: body, plans: plans, prefs: prefs, cardioTypes: cardioTypes)
        guard let d = try? JSONEncoder().encode(a) else { return }
        try? d.write(to: dataURL, options: .atomic)
        // Rolling dated backup in Documents (visible in the Files app).
        let bk = docsURL.appendingPathComponent("backup-\(today()).json")
        try? d.write(to: bk, options: .atomic)
    }

    /// Produce a JSON file URL for sharing/export.
    func exportFile() -> URL? {
        let a = AppData(daily: daily, sessions: sessions, body: body, plans: plans, prefs: prefs, cardioTypes: cardioTypes)
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
        cardioTypes = (a.cardioTypes?.isEmpty == false) ? a.cardioTypes! : Store.defaultCardioTypes()
        prefs = a.prefs
        return true
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }
}

// MARK: - Default starting templates (3-day Push / Pull / Legs split, fully editable)
// Names and exercises are English defaults; everything is customizable per user.
extension Store {
    static func defaultPlans() -> [WorkoutPlan] {
        [
            WorkoutPlan(id: "p1", name: "Push", sub: "Chest + Shoulders + Triceps", color: "ff5a52", exercises: [
                PlanExercise(name: "Barbell bench press", sets: 4, reps: "6-8"),
                PlanExercise(name: "Incline dumbbell press", sets: 3, reps: "8-10"),
                PlanExercise(name: "Seated dumbbell shoulder press", sets: 3, reps: "10"),
                PlanExercise(name: "Cable lateral raise", sets: 3, reps: "12-15"),
                PlanExercise(name: "Cable chest fly", sets: 3, reps: "12"),
                PlanExercise(name: "Triceps rope pushdown", sets: 3, reps: "12")
            ]),
            WorkoutPlan(id: "p2", name: "Pull", sub: "Back + Biceps + Rear Delts", color: "4fb8c4", exercises: [
                PlanExercise(name: "Pull-up", sets: 4, reps: "6-10"),
                PlanExercise(name: "Barbell row", sets: 3, reps: "8-10"),
                PlanExercise(name: "Lat pulldown", sets: 3, reps: "10-12"),
                PlanExercise(name: "Seated cable row", sets: 3, reps: "12"),
                PlanExercise(name: "Face pull", sets: 3, reps: "15"),
                PlanExercise(name: "EZ-bar biceps curl", sets: 3, reps: "10-12")
            ]),
            WorkoutPlan(id: "p3", name: "Legs", sub: "Quads + Hamstrings + Calves", color: "ffb000", exercises: [
                PlanExercise(name: "Barbell back squat", sets: 4, reps: "6-8"),
                PlanExercise(name: "Romanian deadlift", sets: 3, reps: "8-10"),
                PlanExercise(name: "Leg press", sets: 3, reps: "12"),
                PlanExercise(name: "Seated leg curl", sets: 3, reps: "12"),
                PlanExercise(name: "Leg extension", sets: 3, reps: "15"),
                PlanExercise(name: "Standing calf raise", sets: 4, reps: "15")
            ])
        ]
    }

    /// Default customizable cardio activities (colors from Theme.cardioColors).
    static func defaultCardioTypes() -> [CardioType] {
        [
            CardioType(id: "c-run",  name: "Running", sport: "running",  color: "ff5a52"),
            CardioType(id: "c-swim", name: "Swimming", sport: "swimming", color: "4fb8c4"),
            CardioType(id: "c-bike", name: "Cycling", sport: "cycling",  color: "7fc950"),
            CardioType(id: "c-walk", name: "Walking", sport: "walking",  color: "b08fff")
        ]
    }

    // MARK: Cardio type mutations
    func commitCardioType(_ ct: CardioType) {
        if let i = cardioTypes.firstIndex(where: { $0.id == ct.id }) { cardioTypes[i] = ct }
        else { cardioTypes.append(ct) }
    }
    func deleteCardioType(_ id: String) { cardioTypes.removeAll { $0.id == id } }
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
        if b < 18.5 { return (L.t("bmi.under"), Theme.blue) }
        if b < 25   { return (L.t("bmi.normal"), Theme.good) }
        if b < 30   { return (L.t("bmi.over"), Theme.acc2) }
        return (L.t("bmi.obese"), Theme.red)
    }

    /// US-Navy body-fat estimate from neck & waist (cm).
    func bfNavy(waist: Double?, neck: Double?) -> Double? {
        guard let waist, let neck, waist > neck else { return nil }
        let v = 86.010 * log10(waist - neck) - 70.041 * log10(prefs.height * 100) + 36.76
        return (v * 10).rounded() / 10
    }

    func hasCheckedIn() -> Bool { daily.contains { $0.date == today() && $0.weight != nil } }

    /// Consecutive days with a check-in or workout. The current day is a grace
    /// period: the streak stays alive all day even before today's check-in, and
    /// only breaks once a full day has passed with nothing logged. So if today is
    /// not logged yet we start counting from yesterday rather than zeroing out.
    var streak: Int {
        var dates = Set<String>()
        daily.forEach { dates.insert($0.date) }
        sessions.forEach { dates.insert($0.date) }
        let cal = Calendar.current
        var d = cal.startOfDay(for: Date())
        // Today still open: don't penalize until it actually elapses.
        if !dates.contains(isoFormatter.string(from: d)) {
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        var n = 0
        for _ in 0..<400 {
            let s = isoFormatter.string(from: d)
            if dates.contains(s) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
            else { break }
        }
        return n
    }

    // MARK: - Next workout (schedule-aware)
    /// What the user should train next: a strength plan or a cardio activity.
    enum NextItem {
        case plan(WorkoutPlan)
        case cardio(CardioType)
        var name: String { switch self { case .plan(let p): return p.name; case .cardio(let c): return c.name } }
        var color: String { switch self { case .plan(let p): return p.color; case .cardio(let c): return c.color } }
        var sub: String {
            switch self {
            case .plan(let p): return p.sub
            case .cardio(let c): return c.sportType.label
            }
        }
        var icon: String {
            switch self {
            case .plan: return "dumbbell.fill"
            case .cardio(let c): return c.sportType.icon
            }
        }
    }

    /// Resolve a schedule slot id to a concrete item (plan or cardio), if any.
    private func scheduleItem(_ id: String) -> NextItem? {
        if id.isEmpty || id == "rest" { return nil }
        if let p = plans.first(where: { $0.id == id }) { return .plan(p) }
        if let c = cardioTypes.first(where: { $0.id == id }) { return .cardio(c) }
        return nil
    }

    /// The next thing to train. With a weekly schedule, walks forward from today
    /// (Mon..Sun, looping to next week) to the next assigned, non-rest weekday,
    /// skipping today if it's already been trained. Without a schedule, rotates
    /// through the plan list after the most recent session.
    func nextUp() -> NextItem? {
        let cal = Calendar.current
        if prefs.hasSchedule {
            let sched = prefs.weekSchedule
            let todayMon = (cal.component(.weekday, from: Date()) + 5) % 7   // Monday = 0
            let trainedToday = sessions.contains { $0.date == today() }
            for off in 0..<8 {
                if off == 0 && trainedToday { continue }
                if let item = scheduleItem(sched[(todayMon + off) % 7]) { return item }
            }
            return nil
        }
        return nextPlanRotation().map { .plan($0) }
    }

    /// Next strength plan only (used by progressive-overload suggestions).
    func nextStrengthPlan() -> WorkoutPlan? {
        if prefs.hasSchedule, case .plan(let p)? = nextUp() { return p }
        return nextPlanRotation()
    }

    /// Rotation: the plan after the most recent session's plan, looping.
    func nextPlanRotation() -> WorkoutPlan? {
        guard !plans.isEmpty else { return nil }
        guard let last = sessions.sorted(by: { $0.date > $1.date }).first,
              let idx = plans.firstIndex(where: { $0.id == last.planId }) else { return plans.first }
        return plans[(idx + 1) % plans.count]
    }

    /// Set the assignment for a weekday (Mon=0..Sun=6) in the weekly schedule.
    func setSchedule(weekday: Int, id: String) {
        guard (0..<7).contains(weekday) else { return }
        var s = prefs.weekSchedule
        s[weekday] = id
        // Drop the schedule entirely when nothing meaningful remains.
        prefs.schedule = s.contains { !$0.isEmpty && $0 != "rest" } ? s : nil
    }
    func clearSchedule() { prefs.schedule = nil }

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

    /// Energy spent in a session, in kcal, as *active* energy (the resting
    /// baseline is removed, so the number is comparable to what a sports watch
    /// reports). Each category has its own formula:
    ///   - manual override always wins;
    ///   - each aerobic sport (cycling / running / walking / swimming) has its
    ///     own speed->MET curve, refined by avg HR when no distance is logged;
    ///   - strength uses avg HR + duration, plus a small bump from volume lifted;
    ///   - an unknown custom activity ("other", e.g. padel) uses a generic
    ///     HR + duration estimate, or a moderate fixed MET if no HR.
    /// A new activity that picks an existing sport category inherits that sport's
    /// formula automatically (it flows through `sportType`).
    func estimateCalories(_ s: WorkoutSession) -> Int {
        if let manual = s.caloriesManual, manual > 0 { return manual }
        let w = lastWeight
        guard let dur = s.durationMinutesD, dur > 0 else {
            // No duration logged: fall back to a strength volume/sets heuristic.
            return Int((s.volume * 0.022 + Double(s.totalSets) * 3 + 60).rounded())
        }
        let hours = dur / 60
        let speed: Double? = s.distanceKm.flatMap { $0 > 0 ? $0 / hours : nil }   // km/h
        let hrr = hrReserve(s.avgHR, session: s)
        let met = sportMET(s.sportType, speedKmh: speed, hrr: hrr)
        // Active energy = (MET - 1 resting) x weight x hours.
        var kcal = max(1.0, met - 1.0) * w * hours
        if s.sportType == .strength { kcal += min(90.0, s.volume * 0.008) }
        return max(1, Int(kcal.rounded()))
    }

    /// Heart-rate reserve fraction (0...1) from profile resting/max HR, or nil
    /// when no avg HR was entered.
    private func hrReserve(_ hr: Int?, session s: WorkoutSession) -> Double? {
        guard let hr, hr > 0 else { return nil }
        let rest = Double(prefs.restHRorDefault)
        let mx = Double(s.maxHRSes ?? prefs.estMaxHR)
        guard mx > rest else { return nil }
        return max(0, min(1, (Double(hr) - rest) / (mx - rest)))
    }

    /// Per-category gross MET. Aerobic sports use a speed->MET curve calibrated so
    /// the resulting active energy stays close to a sports-watch reading (the old
    /// HR-only Keytel equation badly overestimated, e.g. ~1200 kcal for a steady
    /// ride). When no speed is available we fall back to an HR-driven estimate,
    /// then to a moderate fixed MET.
    private func sportMET(_ sport: Sport, speedKmh v: Double?, hrr: Double?) -> Double {
        switch sport {
        case .running:
            if let v, v > 0 { return max(6.0, 0.95 * v + 0.5) }     // ~10 MET at 10 km/h
            if let hrr { return 3.0 + 9.0 * hrr }
            return 9.5
        case .cycling:
            if let v, v > 0 {
                switch v {
                case ..<16:  return 3.8
                case ..<20:  return 5.0      // ~17 km/h leisure -> ~500 kcal active for an 88-min ride
                case ..<24:  return 6.8
                case ..<28:  return 8.5
                case ..<33:  return 10.5
                default:     return 12.5
                }
            }
            if let hrr { return 2.5 + 7.0 * hrr }
            return 6.0
        case .walking:
            if let v, v > 0 {
                switch v {
                case ..<3.2: return 2.5
                case ..<4.8: return 3.3
                case ..<6.4: return 4.5
                case ..<8.0: return 6.0
                default:     return 7.5
                }
            }
            if let hrr { return 2.0 + 4.0 * hrr }
            return 3.5
        case .swimming:
            if let v, v > 0 { return v > 4 ? 10.0 : (v < 2.5 ? 6.0 : 8.3) }
            if let hrr { return 4.0 + 7.0 * hrr }
            return 8.0
        case .strength:
            if let hrr { return 2.8 + 5.5 * hrr }
            return 4.5
        case .other:
            if let hrr { return 2.0 + 7.0 * hrr }
            return 6.0
        }
    }

    // MARK: Daily nutrition & recovery
    func saveDailyExtras(kcal: Int? = nil, protein: Double? = nil, carbs: Double? = nil,
                         fat: Double? = nil, salt: Double? = nil, steps: Int? = nil,
                         rmssd: Double? = nil, restHR: Int? = nil) {
        let day = today()
        var e = daily.first(where: { $0.date == day }) ?? DailyEntry(date: day)
        if let kcal { e.kcal = kcal }
        if let protein { e.protein = protein }
        if let carbs { e.carbs = carbs }
        if let fat { e.fat = fat }
        if let salt { e.salt = salt }
        if let steps { e.steps = steps }
        if let rmssd { e.rmssd = rmssd }
        if let restHR { e.restHR = restHR }
        daily.removeAll { $0.date == day }
        daily.append(e)
    }

    // MARK: Apple Health import (optional, gap-fill only)
    /// Merge Health samples into daily entries. Imported values only fill missing
    /// fields so a manually typed number is never overwritten.
    func applyHealthSamples(_ samples: [HealthDaySample]) {
        for s in samples {
            var e = daily.first(where: { $0.date == s.date }) ?? DailyEntry(date: s.date)
            if e.steps == nil, let v = s.steps, v > 0 { e.steps = v }
            if e.restHR == nil, let v = s.restHR, v > 0 { e.restHR = v }
            if e.hrvSDNN == nil, let v = s.hrvSDNN, v > 0 { e.hrvSDNN = v }
            daily.removeAll { $0.date == s.date }
            daily.append(e)
        }
    }

    /// Request authorization (if needed) and pull the last `days` days from Health.
    func syncHealth(days: Int = 30, completion: ((Bool) -> Void)? = nil) {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { completion?(false); return }
        hk.requestAuthorization { granted in
            guard granted else { completion?(false); return }
            hk.fetch(days: days) { samples in
                self.applyHealthSamples(samples)
                // Keep resting HR profile fresh from the most recent reading.
                if let last = samples.compactMap({ $0.restHR }).last, last > 0 { self.prefs.restingHR = last }
                completion?(true)
            }
        }
    }

    // MARK: Session editing
    func deleteSession(_ id: UUID) { sessions.removeAll { $0.id == id } }
    func updateSession(_ s: WorkoutSession) {
        if let i = sessions.firstIndex(where: { $0.id == s.id }) { sessions[i] = s }
    }

    // MARK: Rest days (markers, not sessions)
    func isRestDay(_ date: String) -> Bool { prefs.restDaySet.contains(date) }
    func setRestDay(_ date: String, on: Bool) {
        var set = prefs.restDaySet
        if on { set.insert(date) } else { set.remove(date) }
        prefs.restDays = set.isEmpty ? nil : Array(set).sorted()
    }
    func toggleRestDay(_ date: String) { setRestDay(date, on: !isRestDay(date)) }

    // MARK: Quick insert (log a workout for a past/other day from Home or Calendar)
    /// Create a strength session for `date`, prefilled from the most recent
    /// session of that plan (its sets, reps, weights, load), or from the plan
    /// template when there's no history. Marking the day clears any rest flag.
    @discardableResult
    func quickInsertSession(plan: WorkoutPlan, date: String) -> WorkoutSession {
        let last = sessions.filter { $0.planId == plan.id }.sorted { $0.date > $1.date }.first
        let exercises: [LoggedExercise]
        if let last {
            exercises = last.exercises.map { e in
                LoggedExercise(name: e.name,
                               sets: e.sets.map { SetEntry(reps: $0.reps, weight: $0.weight) },
                               notes: "", target: e.target,
                               supersetGroup: e.supersetGroup, method: e.method)
            }
        } else {
            exercises = plan.exercises.map { pe in
                LoggedExercise(name: pe.name,
                               sets: (0..<max(1, pe.sets)).map { _ in SetEntry() },
                               target: "\(pe.sets)×\(pe.reps)",
                               supersetGroup: pe.supersetGroup, method: pe.method)
            }
        }
        var s = WorkoutSession(date: date, planId: plan.id, planName: plan.name,
                               planColor: plan.color, exercises: exercises)
        s.durationSec = last?.durationSeconds
        s.avgHR = last?.avgHR
        s.maxHRSes = last?.maxHRSes
        setRestDay(date, on: false)
        sessions.append(s)
        return s
    }

    /// Create a cardio session for `date`, prefilled from the most recent log of
    /// that activity. Returns it so the caller can open the editor to adjust.
    @discardableResult
    func quickInsertCardio(type: CardioType, date: String) -> WorkoutSession {
        let pid = "cardio-\(type.id)"
        let last = sessions.filter { $0.planId == pid }.sorted { $0.date > $1.date }.first
        var s = WorkoutSession(date: date, planId: pid, planName: type.name,
                               planColor: type.color, exercises: [], sport: type.sport)
        s.durationSec = last?.durationSeconds
        s.avgHR = last?.avgHR
        s.distanceKm = last?.distanceKm
        s.paceManual = last?.paceManual
        setRestDay(date, on: false)
        sessions.append(s)
        return s
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
