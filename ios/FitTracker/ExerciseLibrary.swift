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
