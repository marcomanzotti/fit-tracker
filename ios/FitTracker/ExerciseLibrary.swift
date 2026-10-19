import Foundation

// MARK: - Curated starting exercise library (~150)
// A hand-picked catalog the user can browse by muscle group in the editor, search,
// and create variants from. It is NOT meant to be exhaustive — a focused set of
// the movements people actually program beats a noisy 800-entry dump. Names are
// English (like the default plans) since they're stored as data the user can
// rename; the UI chrome around them is localized, the movement names are not.
//
// Each seed carries its muscle-group `category` and a `bodyweight` flag. The
// `base` (movement family) is left to `Store.normalizedBase`, so grip/stance
// variants the user adds later automatically roll up to the same family for PRs
// and progress — exactly the behavior the auto-populated library already uses.
//
// Seeding runs once, gated by `prefs.seededExercises`, and never overwrites an
// existing entry (so a user's own bodyweight/category/base edits always win) nor
// re-adds anything the user has deleted.

struct SeedExercise {
    let name: String
    let group: MuscleGroup
    let bodyweight: Bool
    init(_ name: String, _ group: MuscleGroup, bw: Bool = false) {
        self.name = name; self.group = group; self.bodyweight = bw
    }
}

extension Store {
    static let seedExercises: [SeedExercise] = [
        // --- Chest -----------------------------------------------------------
        SeedExercise("Barbell bench press", .chest),
        SeedExercise("Incline barbell bench press", .chest),
        SeedExercise("Decline barbell bench press", .chest),
        SeedExercise("Flat dumbbell press", .chest),
        SeedExercise("Incline dumbbell press", .chest),
        SeedExercise("Decline dumbbell press", .chest),
        SeedExercise("Dumbbell chest fly", .chest),
        SeedExercise("Incline dumbbell fly", .chest),
        SeedExercise("Cable chest fly", .chest),
        SeedExercise("Low-to-high cable fly", .chest),
        SeedExercise("Pec deck", .chest),
        SeedExercise("Machine chest press", .chest),
        SeedExercise("Push-up", .chest, bw: true),
        SeedExercise("Incline push-up", .chest, bw: true),
        SeedExercise("Decline push-up", .chest, bw: true),
        SeedExercise("Chest dip", .chest, bw: true),

        // --- Back ------------------------------------------------------------
        SeedExercise("Pull-up", .back, bw: true),
        SeedExercise("Chin-up", .back, bw: true),
        SeedExercise("Wide-grip pull-up", .back, bw: true),
        SeedExercise("Lat pulldown", .back),
        SeedExercise("Close-grip lat pulldown", .back),
        SeedExercise("Neutral-grip lat pulldown", .back),
        SeedExercise("Barbell row", .back),
        SeedExercise("Pendlay row", .back),
        SeedExercise("Dumbbell row", .back),
        SeedExercise("Single-arm dumbbell row", .back),
        SeedExercise("Seated cable row", .back),
        SeedExercise("Chest-supported row", .back),
        SeedExercise("T-bar row", .back),
        SeedExercise("Machine row", .back),
        SeedExercise("Straight-arm pulldown", .back),
        SeedExercise("Conventional deadlift", .back),
        SeedExercise("Rack pull", .back),
        SeedExercise("Inverted row", .back, bw: true),
        SeedExercise("Back extension", .back, bw: true),

        // --- Legs ------------------------------------------------------------
        SeedExercise("Back squat", .legs),
        SeedExercise("Front squat", .legs),
        SeedExercise("High-bar squat", .legs),
        SeedExercise("Hack squat", .legs),
        SeedExercise("Leg press", .legs),
        SeedExercise("Bulgarian split squat", .legs),
        SeedExercise("Walking lunge", .legs),
        SeedExercise("Reverse lunge", .legs),
        SeedExercise("Goblet squat", .legs),
        SeedExercise("Romanian deadlift", .legs),
        SeedExercise("Stiff-leg deadlift", .legs),
        SeedExercise("Sumo deadlift", .legs),
        SeedExercise("Leg extension", .legs),
        SeedExercise("Lying leg curl", .legs),
        SeedExercise("Seated leg curl", .legs),
        SeedExercise("Hip thrust", .legs),
        SeedExercise("Glute bridge", .legs, bw: true),
        SeedExercise("Cable kickback", .legs),
        SeedExercise("Standing calf raise", .legs),
        SeedExercise("Seated calf raise", .legs),
        SeedExercise("Step-up", .legs, bw: true),
        SeedExercise("Pistol squat", .legs, bw: true),
        SeedExercise("Bodyweight squat", .legs, bw: true),
        SeedExercise("Nordic hamstring curl", .legs, bw: true),

        // --- Shoulders -------------------------------------------------------
        SeedExercise("Overhead barbell press", .shoulders),
        SeedExercise("Seated dumbbell shoulder press", .shoulders),
        SeedExercise("Standing dumbbell press", .shoulders),
        SeedExercise("Arnold press", .shoulders),
        SeedExercise("Machine shoulder press", .shoulders),
        SeedExercise("Dumbbell lateral raise", .shoulders),
        SeedExercise("Cable lateral raise", .shoulders),
        SeedExercise("Machine lateral raise", .shoulders),
        SeedExercise("Front raise", .shoulders),
        SeedExercise("Rear-delt fly", .shoulders),
        SeedExercise("Reverse pec deck", .shoulders),
        SeedExercise("Face pull", .shoulders),
        SeedExercise("Upright row", .shoulders),
        SeedExercise("Barbell shrug", .shoulders),
        SeedExercise("Dumbbell shrug", .shoulders),
        SeedExercise("Pike push-up", .shoulders, bw: true),

        // --- Arms ------------------------------------------------------------
        SeedExercise("Barbell curl", .arms),
        SeedExercise("EZ-bar curl", .arms),
        SeedExercise("Dumbbell curl", .arms),
        SeedExercise("Incline dumbbell curl", .arms),
        SeedExercise("Hammer curl", .arms),
        SeedExercise("Concentration curl", .arms),
        SeedExercise("Preacher curl", .arms),
        SeedExercise("Cable curl", .arms),
        SeedExercise("Spider curl", .arms),
        SeedExercise("Triceps rope pushdown", .arms),
        SeedExercise("Triceps bar pushdown", .arms),
        SeedExercise("Overhead triceps extension", .arms),
        SeedExercise("Skull crusher", .arms),
        SeedExercise("Close-grip bench press", .arms),
        SeedExercise("Triceps dip", .arms, bw: true),
        SeedExercise("Bench dip", .arms, bw: true),
        SeedExercise("Wrist curl", .arms),
        SeedExercise("Reverse wrist curl", .arms),
        SeedExercise("Reverse curl", .arms),

        // --- Core ------------------------------------------------------------
        SeedExercise("Plank", .core, bw: true),
        SeedExercise("Side plank", .core, bw: true),
        SeedExercise("Crunch", .core, bw: true),
        SeedExercise("Bicycle crunch", .core, bw: true),
        SeedExercise("Hanging leg raise", .core, bw: true),
        SeedExercise("Lying leg raise", .core, bw: true),
        SeedExercise("Cable crunch", .core),
        SeedExercise("Russian twist", .core, bw: true),
        SeedExercise("Mountain climber", .core, bw: true),
        SeedExercise("Dead bug", .core, bw: true),
        SeedExercise("Hollow hold", .core, bw: true),
        SeedExercise("Ab wheel rollout", .core, bw: true),
        SeedExercise("Sit-up", .core, bw: true),
        SeedExercise("Flutter kicks", .core, bw: true),
        SeedExercise("Wall sit", .legs, bw: true),

        // --- Full body / functional -----------------------------------------
        SeedExercise("Burpee", .fullbody, bw: true),
        SeedExercise("Kettlebell swing", .fullbody),
        SeedExercise("Clean and press", .fullbody),
        SeedExercise("Power clean", .fullbody),
        SeedExercise("Thruster", .fullbody),
        SeedExercise("Farmer's carry", .fullbody),
        SeedExercise("Turkish get-up", .fullbody),
        SeedExercise("Box jump", .fullbody, bw: true),
        SeedExercise("Jumping jack", .fullbody, bw: true),
        SeedExercise("Battle ropes", .fullbody),
        SeedExercise("Sled push", .fullbody),
        SeedExercise("Bear crawl", .fullbody, bw: true),

        // --- Cardio / conditioning (often logged as timed / interval) --------
        SeedExercise("High knees", .cardio, bw: true),
        SeedExercise("Jump rope", .cardio, bw: true),
        SeedExercise("Sprints", .cardio, bw: true),
        SeedExercise("Rowing erg", .cardio),
        SeedExercise("Assault bike", .cardio),
        SeedExercise("Stair climber", .cardio),
        SeedExercise("Shadow boxing", .cardio, bw: true),
    ]

    /// The whole exercise library grouped by muscle group, for the browse-by-muscle
    /// picker. Each group is name-sorted; groups with no exercises are dropped. An
    /// optional `query` filters by name (case/diacritic-insensitive).
    func exercisesByMuscle(query: String = "") -> [(group: MuscleGroup, items: [ExerciseItem])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return MuscleGroup.allCases.compactMap { g in
            var items = exerciseItems.filter { ($0.category ?? Store.guessCategory($0.name).rawValue) == g.rawValue }
            if !q.isEmpty { items = items.filter { $0.name.localizedCaseInsensitiveContains(q) } }
            guard !items.isEmpty else { return nil }
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return (g, items)
        }
    }

    /// Insert the curated library once. Skips any name that already exists (the
    /// user's own entries and edits always win) and runs only when not yet seeded,
    /// so deleted seeds don't reappear. Seeds carry no `lastUsed`, so they sit in
    /// the browse-by-muscle picker without polluting the "recent" ordering.
    func seedExerciseLibraryIfNeeded() {
        guard prefs.seededExercises != true else { return }
        let existing = Set(exerciseItems.map { $0.name })
        for s in Store.seedExercises where !existing.contains(s.name) {
            exerciseItems.append(ExerciseItem(
                name: s.name,
                isBodyweight: s.bodyweight,
                lastUsed: nil,
                base: Store.normalizedBase(s.name),
                category: s.group.rawValue))
        }
        prefs.seededExercises = true
    }
}

// MARK: - Secondary muscles
extension Store {
    /// A secondary muscle counts half a set in the weekly volume.
    static let secondaryWeight = 0.5

    /// The other groups a movement works hard enough to count: a press loads the
    /// arms and shoulders, a row or pulldown the arms, a deadlift the legs. Flys,
    /// raises and curls are isolation work and add nothing. Read from the name and
    /// the primary group, so the user's own exercises follow without extra data.
    static func secondaryGroups(of name: String, primary: MuscleGroup) -> [MuscleGroup] {
        let n = name.lowercased()
        func has(_ words: String...) -> Bool { words.contains { n.contains($0) } }
        switch primary {
        case .chest:
            return has("fly", "pec deck", "crossover") ? [] : [.arms, .shoulders]
        case .back:
            if has("deadlift", "rack pull") { return [.legs, .arms] }
            return has("pulldown", "pull-up", "chin-up", "row") ? [.arms] : []
        case .shoulders:
            return has("press") ? [.arms] : []
        case .legs:
            return has("deadlift") ? [.back] : []
        case .arms, .core, .fullbody, .cardio, .other:
            return []
        }
    }
}

// MARK: - Library lookups and edits that rewrite history
extension Store {
    // MARK: Exercise library

    /// Auto-save an exercise the first time it is seen; update its bodyweight flag.
    /// On first save it also gets a suggested movement family (base) and a guessed
    /// muscle-group category, both of which the user can later override. `used`
    /// is true only when the exercise was logged: being in a plan is not using it.
    func touchExerciseInLibrary(_ name: String, isBodyweight: Bool = false, used: Bool = true) {
        touchExercisesInLibrary([(name, isBodyweight)], used: used)
    }

    /// The same for several exercises at once (a finished session), changing the
    /// library once.
    func touchExercisesInLibrary(_ entries: [(name: String, isBodyweight: Bool)], used: Bool = true) {
        var items = exerciseItems
        let day = today()
        for (name, isBodyweight) in entries {
            if let i = items.firstIndex(where: { $0.name == name }) {
                if used { items[i].lastUsed = day }
                if isBodyweight { items[i].isBodyweight = true }
                if items[i].base == nil { items[i].base = Store.normalizedBase(name) }
                if items[i].category == nil { items[i].category = Store.guessCategory(name).rawValue }
            } else {
                items.append(ExerciseItem(name: name, isBodyweight: isBodyweight, lastUsed: used ? day : nil,
                                          base: Store.normalizedBase(name), category: Store.guessCategory(name).rawValue))
            }
        }
        if items != exerciseItems { exerciseItems = items }
    }

    /// Rebuild a Train-page plan from a past session (used when the original plan
    /// was deleted). Carries over names, set counts, a representative rep target,
    /// method, effort scale, bodyweight flag, and the library muscle group.
    @discardableResult
    func recreatePlan(from session: WorkoutSession) -> WorkoutPlan {
        let exs: [PlanExercise] = session.exercises.map { le in
            // Most common rep value across the logged sets as the new target.
            let reps = le.sets.compactMap { Int(pf($0.reps)) }.filter { $0 > 0 }
            let repTarget = reps.isEmpty ? "10" : "\(mode(reps))"
            return PlanExercise(name: le.name, sets: max(1, le.sets.count), reps: repTarget,
                                supersetGroup: le.supersetGroup, method: le.method,
                                effortMode: le.effortMode, isBodyweight: le.isBodyweight,
                                muscle: exerciseCategory(le.name))
        }
        let plan = WorkoutPlan(name: session.planName, color: session.planColor, exercises: exs)
        plans.append(plan)
        registerPlanExercises(plan)
        return plan
    }

    /// Most frequent value in a list (ties resolved by first seen).
    private func mode(_ xs: [Int]) -> Int {
        var counts: [Int: Int] = [:]
        for x in xs { counts[x, default: 0] += 1 }
        return counts.max { a, b in a.value < b.value }?.key ?? (xs.first ?? 10)
    }

    /// Register every exercise in a plan into the library (creating entries as
    /// needed) and apply the muscle group / bodyweight flag chosen in the editor.
    /// Called on plan save so the library is always populated and recoverable, even
    /// after the plan itself is later deleted.
    func registerPlanExercises(_ plan: WorkoutPlan) {
        let named = plan.exercises.compactMap { ex -> (PlanExercise, String)? in
            let name = ex.name.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : (ex, name)
        }
        touchExercisesInLibrary(named.map { ($0.1, $0.0.bodyweight) }, used: false)
        var items = exerciseItems
        for (ex, name) in named {
            if let m = ex.muscle, !m.isEmpty, let i = items.firstIndex(where: { $0.name == name }) { items[i].category = m }
        }
        if items != exerciseItems { exerciseItems = items }
    }

    /// Set the movement family + muscle-group for an exercise (creates the library
    /// entry if needed). Empty base => the exercise is its own family.
    func setExerciseFamily(_ name: String, base: String?, category: String?) {
        let cleanBase = base?.trimmingCharacters(in: .whitespaces)
        if let i = exerciseItems.firstIndex(where: { $0.name == name }) {
            exerciseItems[i].base = (cleanBase?.isEmpty ?? true) ? Store.normalizedBase(name) : cleanBase
            if let category { exerciseItems[i].category = category }
        } else {
            exerciseItems.append(ExerciseItem(name: name,
                                              base: (cleanBase?.isEmpty ?? true) ? Store.normalizedBase(name) : cleanBase,
                                              category: category ?? Store.guessCategory(name).rawValue))
        }
    }

    // MARK: Exercise rename / merge / delete (rewrites historical data)

    /// Rename an exercise everywhere it appears — every logged set in past
    /// sessions, every plan, and the library — so the whole history follows the new
    /// name. When `to` already exists this is a MERGE: the two histories combine
    /// under the destination name, and the source library entry is dropped (the
    /// destination's bodyweight/base/category metadata wins). PRs, progress charts
    /// and "last session" all recompute automatically off the rewritten sessions.
    /// Returns false (no-op) for an empty/identical target.
    @discardableResult
    func renameExercise(from oldName: String, to newRaw: String) -> Bool {
        let newName = newRaw.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != oldName else { return false }
        let isMerge = exerciseItems.contains { $0.name == newName }
            || plans.contains { $0.exercises.contains { $0.name == newName } }
            || sessions.contains { $0.exercises.contains { $0.name == newName } }

        // 1) Rewrite every logged exercise in past sessions, 2) the plan templates:
        // on copies, so each collection changes (and saves, and redraws) once.
        var newSessions = sessions
        for si in newSessions.indices {
            for ei in newSessions[si].exercises.indices where newSessions[si].exercises[ei].name == oldName {
                newSessions[si].exercises[ei].name = newName
            }
        }
        sessions = newSessions
        var newPlans = plans
        for pi in newPlans.indices {
            for ei in newPlans[pi].exercises.indices where newPlans[pi].exercises[ei].name == oldName {
                newPlans[pi].exercises[ei].name = newName
            }
        }
        plans = newPlans
        // 3) Library: on merge drop the old entry (keep the destination's metadata);
        //    on a plain rename, carry the old entry's metadata over to the new name.
        if let oi = exerciseItems.firstIndex(where: { $0.name == oldName }) {
            if isMerge {
                // Preserve the freshest lastUsed across the two entries.
                if let di = exerciseItems.firstIndex(where: { $0.name == newName }) {
                    let merged = max(exerciseItems[di].lastUsed ?? "", exerciseItems[oi].lastUsed ?? "")
                    exerciseItems[di].lastUsed = merged.isEmpty ? exerciseItems[di].lastUsed : merged
                }
                exerciseItems.remove(at: oi)
            } else {
                exerciseItems[oi].name = newName
            }
        } else if !isMerge {
            touchExerciseInLibrary(newName, used: false)
        }
        return true
    }

    /// Delete an exercise from the whole history: remove its sets from every past
    /// session (dropping a session that becomes empty), from every plan, and from
    /// the library. Irreversible — used by the manage-exercises screen behind a
    /// confirmation.
    func deleteExercise(_ name: String) {
        // Only a session this delete emptied is dropped. Sessions that never had
        // exercises (Health imports, watch sessions, cardio) are not touched.
        let emptied = sessions.filter { s in !s.exercises.isEmpty && s.exercises.allSatisfy { $0.name == name } }
        dismissHealthWorkouts(emptied.flatMap(\.allHealthUUIDs))
        sessions = sessions.compactMap { session in
            guard session.exercises.contains(where: { $0.name == name }) else { return session }
            var stripped = session
            stripped.exercises.removeAll { $0.name == name }
            return stripped.exercises.isEmpty ? nil : stripped
        }
        for pi in plans.indices {
            plans[pi].exercises.removeAll { $0.name == name }
        }
        exerciseItems.removeAll { $0.name == name }
    }

    /// Groups of exercise names that look like accidental duplicates (same name up
    /// to case, spacing and accents), surfaced as merge suggestions. Only groups
    /// with more than one real variant are returned, most-recent first.
    func similarExerciseGroups() -> [[String]] {
        func key(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
             .replacingOccurrences(of: "-", with: " ")
             .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        }
        let names = Set(allExerciseNames().map { $0.name })
        var byKey: [String: [String]] = [:]
        for n in names { byKey[key(n), default: []].append(n) }
        return byKey.values.filter { $0.count > 1 }
            .map { $0.sorted { recencyOf($0) > recencyOf($1) } }
            .sorted { (recencyOf($0.first ?? "")) > (recencyOf($1.first ?? "")) }
    }

    /// Most recent date this exact exercise name was logged or marked used.
    private func recencyOf(_ name: String) -> String {
        let lib = exerciseItems.first { $0.name == name }?.lastUsed ?? ""
        let logged = sessions.filter { $0.exercises.contains { $0.name == name } }
            .map { $0.date }.max() ?? ""
        return max(lib, logged)
    }

    /// The movement family an exercise rolls up to (its saved base, else a
    /// normalized form of the name).
    func exerciseBase(_ name: String) -> String {
        if let b = libraryItem(name)?.base, !b.isEmpty { return b }
        return Store.normalizedBase(name)
    }

    /// The muscle-group key for an exercise (saved category, else a guess).
    func exerciseCategory(_ name: String) -> String {
        if let c = libraryItem(name)?.category, !c.isEmpty { return c }
        return Store.guessCategory(name).rawValue
    }

    /// Strip common grip / variation qualifiers so variants of one movement share a
    /// family by default (e.g. "Wide-grip lat pulldown" -> "Lat pulldown"). The
    /// result is title-cased; the user can always edit the family afterwards.
    static func normalizedBase(_ name: String) -> String {
        var s = " " + name.lowercased() + " "
        let qualifiers = ["wide-grip", "wide grip", "close-grip", "close grip", "narrow-grip",
                          "narrow grip", "neutral-grip", "neutral grip", "reverse-grip", "reverse grip",
                          "rear-delt", "rear delt", "single-arm", "single arm", "one-arm", "one arm",
                          "wide", "close", "narrow"]
        for q in qualifiers { s = s.replacingOccurrences(of: " \(q) ", with: " ") }
        let cleaned = s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return name }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    /// Best-effort muscle-group from the exercise name's keywords.
    static func guessCategory(_ name: String) -> MuscleGroup {
        let n = name.lowercased()
        func has(_ ks: [String]) -> Bool { ks.contains { n.contains($0) } }
        if has(["squat", "leg press", "leg curl", "leg extension", "lunge", "calf", "hamstring",
                "quad", "glute", "rdl", "romanian", "hip thrust"]) { return .legs }
        if has(["bench", "chest", "fly", "pec", "push-up", "push up", "dip"]) { return .chest }
        if has(["row", "pulldown", "pull-up", "pull up", "chin-up", "lat ", "deadlift", "pull-over", "back extension"]) { return .back }
        if has(["shoulder", "lateral raise", "delt", "overhead press", "ohp", "upright row", "face pull", "shrug"]) { return .shoulders }
        if has(["curl", "triceps", "biceps", "pushdown", "skull", "preacher", "hammer", "forearm"]) { return .arms }
        if has(["plank", "crunch", "ab ", "abs", "core", "sit-up", "sit up", "leg raise", "russian twist"]) { return .core }
        if has(["run", "cycl", "bike", "swim", "walk", "row erg", "rowing", "elliptical", "jump rope"]) { return .cardio }
        return .other
    }

    /// A movement family (base) grouping all of its variant exercise names.
    struct ExFamily: Identifiable {
        var base: String
        var category: String       // MuscleGroup raw value
        var names: [String]
        var id: String { base }
    }

    /// Every known exercise (plans + library) grouped into movement families,
    /// each tagged with a muscle-group, sorted by most-recently-used name.
    func exerciseFamilies() -> [ExFamily] { memo("families") { computeFamilies() } }

    private func computeFamilies() -> [ExFamily] {
        var byBase: [String: (cat: String, names: [String])] = [:]
        for (_, name) in allExerciseNames() where !name.isEmpty {
            let base = exerciseBase(name)
            var entry = byBase[base] ?? (exerciseCategory(name), [])
            if !entry.names.contains(name) { entry.names.append(name) }
            byBase[base] = entry
        }
        return byBase.map { ExFamily(base: $0.key, category: $0.value.cat, names: $0.value.names) }
            .sorted { $0.base.localizedCaseInsensitiveCompare($1.base) == .orderedAscending }
    }

    /// One day of an exercise's history: the top weight and the volume of that day.
    struct ExPoint: Identifiable { var day: Date; var maxW: Double; var vol: Double; var id: Date { day } }
    func exerciseHistory(_ name: String) -> [ExPoint] {
        exerciseHistory(names: [name])
    }

    /// History aggregated over every variant in a movement family: per day the
    /// max weight across variants and the summed volume.
    func exerciseHistory(family base: String) -> [ExPoint] {
        let names = Set(exerciseItems.filter { exerciseBase($0.name) == base }.map { $0.name })
            .union(plans.flatMap { $0.exercises.map { $0.name } }.filter { exerciseBase($0) == base })
        return exerciseHistory(names: names)
    }

    /// Two sessions on one day make one point, so the chart has one value per date.
    private func exerciseHistory(names: Set<String>) -> [ExPoint] {
        var byDay: [String: (maxW: Double, vol: Double)] = [:]
        for s in sessions {
            let exs = s.exercises.filter { names.contains($0.name) }
            guard !exs.isEmpty else { continue }
            let acc = byDay[s.date] ?? (0, 0)
            byDay[s.date] = (max(acc.maxW, exs.map(\.maxWeight).max() ?? 0), acc.vol + exs.reduce(0) { $0 + $1.volume })
        }
        return byDay.keys.sorted().compactMap { date in
            guard let day = isoFormatter.date(from: date), let v = byDay[date] else { return nil }
            return ExPoint(day: day, maxW: v.maxW, vol: v.vol.rounded())
        }
    }

    var bodyLatest: BodyEntry? { memo("bodyLatest") { body.max { $0.date < $1.date } } }
    /// The newest body record on or before `date`: what was true on that day.
    func bodyEntry(onOrBefore date: String) -> BodyEntry? {
        body.filter { $0.date <= date }.max { $0.date < $1.date }
    }
    /// The newest body record strictly before `date`, for "change since last time".
    func bodyEntry(before date: String) -> BodyEntry? {
        body.filter { $0.date < date }.max { $0.date < $1.date }
    }

    /// Effective body-fat %: manual override wins, otherwise Navy estimate.
    var currentBF: Double? {
        memo("currentBF") {
            guard let bl = bodyLatest else { return nil }
            return bl.bfManual ?? bfNavy(waist: bl.waist, neck: bl.neck, hip: bl.hips)
        }
    }
}
