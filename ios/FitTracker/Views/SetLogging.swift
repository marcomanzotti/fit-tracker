import SwiftUI

// MARK: - Shared set-logging blocks (live workout + session editor)
// An exercise is logged differently depending on its kind: reps × weight, a hold
// in seconds, or rounds of work/rest. These views own that difference once, so the
// live workout and the past-session editor stay identical — before this, the
// editor always drew reps × weight, which meant the seconds of yesterday's plank
// simply could not be corrected.

/// Grey hint for an empty field: what the same set held last time. Blank or zero
/// values fall back to a neutral dash so an empty past set never reads as a target.
func lastTimeHint(_ v: String?) -> String {
    guard let v, !v.isEmpty, pf(v) > 0 else { return "–" }
    return v
}

/// Same-numbered set from a previous performance of this exercise, or nil past its
/// end (an extra set today has nothing to compare against).
func previousSet(_ prev: LoggedExercise?, _ idx: Int) -> SetEntry? {
    guard let prev, idx < prev.sets.count else { return nil }
    return prev.sets[idx]
}

/// String binding over a set's optional `seconds` (decimal-friendly).
func secondsBinding(_ set: Binding<SetEntry>) -> Binding<String> {
    Binding(get: { set.wrappedValue.seconds.map { trimNum($0) } ?? "" },
            set: { set.wrappedValue.seconds = pf($0) > 0 ? pf($0) : nil })
}

/// The "LAST 12/07" caption that explains the grey placeholders, shown at the head
/// of the columns it refers to.
struct LastTimeCaption: View {
    let prev: LoggedExercise?
    let date: String?
    var body: some View {
        if let prev, !prev.sets.isEmpty, let date {
            Text("\(t("wk.last_short").uppercased()) \(fmtDM(date))")
                .font(.head(8, .semibold)).tracking(0.8).foregroundColor(Theme.blue.opacity(0.8))
        }
    }
}

// MARK: - Timed (isometric) sets: hold seconds + optional added load
struct TimedSetRows: View {
    @Binding var exercise: LoggedExercise
    var bodyweight: Bool
    var previous: LoggedExercise? = nil
    var lastDate: String? = nil
    /// Starting seconds for the hold timer. nil hides the play button — a past
    /// session is corrected by typing, not by running a stopwatch for it.
    var holdTarget: ((SetEntry) -> Double)? = nil
    var onStartHold: ((UUID, Double) -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 9) {
                Spacer().frame(width: 28)
                Text(t("pe.target_sec").uppercased()).font(.head(9, .semibold)).tracking(1.5)
                    .foregroundColor(Theme.sub).frame(width: 66)
                Text(bodyweight ? "+KG" : "KG").font(.head(9, .semibold)).tracking(1.5)
                    .foregroundColor(bodyweight ? Theme.good : Theme.sub).frame(width: 66)
                Spacer()
                LastTimeCaption(prev: previous, date: lastDate)
            }
            .padding(.bottom, 2)
            ForEach($exercise.sets) { $set in
                let idx = exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                let prevSet = previousSet(previous, idx)
                HStack(spacing: 9) {
                    Text("S\(idx + 1)").font(.num(11)).foregroundColor(Theme.sub).frame(width: 28)
                    SmallNumField(text: secondsBinding($set),
                                  placeholder: lastTimeHint(prevSet?.seconds.map { trimNum($0) }))
                    SmallNumField(text: $set.weight, placeholder: lastTimeHint(prevSet?.weight))
                    if let holdTarget, let onStartHold {
                        // Run the hold instead of guessing the number afterwards.
                        Button { tap(); onStartHold(set.id, holdTarget(set)) } label: {
                            Image(systemName: "play.circle.fill").font(.system(size: 22))
                                .foregroundColor(Theme.acc).frame(width: 34, height: 42)
                        }.buttonStyle(.plain)
                    }
                    Button { tap(); exercise.sets.removeAll { $0.id == set.id } } label: {
                        Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.5))
                            .frame(width: 30, height: 42)
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Interval (HIIT) sets: prescription + completed-rounds stepper
struct IntervalSetBlock: View {
    @Binding var exercise: LoggedExercise
    /// Prescribed rounds, from the plan. The stepper below counts what was done.
    var prescribedRounds: Int? = nil

    var body: some View {
        let work = exercise.workSec ?? 30
        let rest = exercise.restSec ?? 15
        let target = prescribedRounds ?? exercise.rounds ?? 8
        let done = Binding(get: { exercise.rounds ?? target },
                           set: { exercise.rounds = $0 })
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                chip("\(work)s", t("pe.work_sec"), Theme.acc)
                chip("\(rest)s", t("pe.rest_sec"), Theme.blue)
                chip("\(work + rest)s", t("wk.round"), Theme.sub)
            }
            HStack(spacing: 10) {
                Text(t("wk.rounds_done").uppercased()).font(.head(9, .semibold)).tracking(1)
                    .foregroundColor(Theme.sub)
                Spacer()
                Button { tap(); done.wrappedValue = max(0, done.wrappedValue - 1) } label: {
                    Image(systemName: "minus").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.txt)
                        .frame(width: 30, height: 30).background(Theme.c3).clipShape(Circle())
                }.buttonStyle(.plain)
                Text("\(done.wrappedValue)/\(target)").font(.num(18)).frame(minWidth: 50)
                Button { tap(); done.wrappedValue += 1 } label: {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.txt)
                        .frame(width: 30, height: 30).background(Theme.c3).clipShape(Circle())
                }.buttonStyle(.plain)
            }
        }
    }

    private func chip(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.num(16)).foregroundColor(color)
            Text(label.uppercased()).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Plate calculator + warm-up ramp
/// Which exercise (and weight) the plate sheet is open for.
struct PlateTarget: Identifiable {
    let id = UUID()
    let name: String
    let weight: Double
}

/// What to hang on the bar for a working weight, and how to ramp up to it. Opened
/// from the exercise card during a workout, where the alternative is doing the
/// arithmetic on chalky hands between sets.
struct PlateSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let exercise: String
    /// Working weight to load. 0 when no set carries one yet.
    let target: Double

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("plate.title").uppercased()).font(.head(16, .bold)).tracking(1)
                                .foregroundColor(Theme.txt)
                            Text(exercise).font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(1)
                        }
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    if target <= 0 {
                        Card { Text(t("plate.no_target")).font(.system(size: 12)).foregroundColor(Theme.sub) }
                    } else {
                        plateCard
                        warmupCard
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private var plateCard: some View {
        let load = store.plateBreakdown(target: target)
        return Card(accent: Theme.acc) {
            HStack {
                Lbl(text: t("plate.working"), color: Theme.acc2)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(trimNum(target)).font(.num(28)).foregroundColor(Theme.acc)
                    Text("kg").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
            }
            .padding(.bottom, 12)

            if let load {
                Text("\(t("plate.per_side").uppercased()) · \(t("plate.bar")) \(trimNum(store.prefs.bar)) kg")
                    .font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub).padding(.bottom, 8)
                if load.plates.isEmpty {
                    Text("—").font(.num(20)).foregroundColor(Theme.sub)
                } else {
                    // Index-keyed: the same denomination legitimately repeats
                    // (20 · 20 · 10), so the value can't be the identity.
                    FlowLayout(spacing: 6) {
                        ForEach(Array(load.plates.enumerated()), id: \.offset) { _, p in
                            Text(trimNum(p)).font(.num(15)).foregroundColor(Theme.bg)
                                .padding(.vertical, 7).padding(.horizontal, 12)
                                .background(Theme.acc)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                    }
                }
                if !load.exact {
                    // Never quietly load a different weight than asked for.
                    Text(t("plate.unreachable", trimNum(load.achieved)))
                        .font(.system(size: 10)).foregroundColor(Theme.acc2).padding(.top, 10)
                }
            }
        }
    }

    private var warmupCard: some View {
        let ramp = store.warmupRamp(working: target)
        return Group {
            if !ramp.isEmpty {
                Card {
                    Lbl(text: t("plate.warmup"), color: Theme.acc2).padding(.bottom, 10)
                    ForEach(ramp) { step in
                        HStack(spacing: 10) {
                            Text("\(Int(step.pct * 100))%").font(.head(11, .semibold)).tracking(0.5)
                                .foregroundColor(Theme.sub).frame(width: 42, alignment: .leading)
                            Text("\(trimNum(step.weight)) kg").font(.num(16)).foregroundColor(Theme.txt)
                            Text("× \(step.reps)").font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.sub)
                            Spacer()
                            if let l = store.plateBreakdown(target: step.weight), !l.plates.isEmpty {
                                Text(l.plates.map { trimNum($0) }.joined(separator: " · "))
                                    .font(.system(size: 10)).foregroundColor(Theme.acc2)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
                    }
                }
            }
        }
    }
}
