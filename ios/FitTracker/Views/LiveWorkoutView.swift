import SwiftUI

struct LiveWorkoutView: View {
    let plan: WorkoutPlan
    @Binding var log: [LoggedExercise]
    /// Called when the user minimizes (back) — keeps the workout running.
    var onBack: () -> Void
    /// Called after a Finish or Discard — actually ends the session.
    var onSaved: () -> Void

    @EnvironmentObject var store: Store
    @EnvironmentObject var timer: RestTimer
    @EnvironmentObject var toast: ToastCenter
    @EnvironmentObject var activeWorkout: ActiveWorkout
    @ObservedObject private var watch = WatchSync.shared

    @State private var addName = ""
    @State private var showNotes: Set<UUID> = []
    @State private var saved = false
    @State private var sessDurationSec: Int? = nil
    @State private var sessAvgHR = ""
    @State private var sessCalManual = ""
    @State private var confirmDiscard = false
    /// Set currently being timed by the isometric hold sheet.
    @State private var hold: HoldTarget?
    /// Exercise whose plate breakdown is open.
    @State private var plates: PlateTarget?
    // Drives the live elapsed clock (counts up from the workout start).
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var lastSess: WorkoutSession? { store.lastSession(forPlan: plan.id) }

    var body: some View {
        VStack(spacing: 11) {
            backRow
            if isWatchLive { watchLiveBanner }
            // During an active workout the top slot shows the LIVE elapsed timer
            // (counting up). Past sessions are visible from the calendar/recent
            // list, so the running time is more useful here than the last session.
            liveTimerBlock

            ForEach($log) { $ex in
                exerciseCard($ex)
            }

            addExerciseCard
            sessionLoadCard
            caloriesCard

            // Finish (primary) + Discard (destructive). Back never ends the
            // workout — only these explicit actions do.
            BigButton(title: saved ? t("wk.saved") : t("wk.finish_session"), color: saved ? Theme.good : Theme.acc) {
                saveSession()
            }
            Button { tap(); confirmDiscard = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash").font(.system(size: 12, weight: .bold))
                    Text(t("wk.discard_session")).font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Theme.red)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.red.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .confirmationDialog(t("wk.discard_q"), isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button(t("wk.discard_session"), role: .destructive) { discardSession() }
                Button(t("cancel"), role: .cancel) {}
            }
        }
        // Claim this activity so a workout finished on the watch folds into THIS
        // session instead of creating a duplicate, and stream-fill live as it runs.
        .onAppear { watch.openActivityId = plan.id; if let s = watch.live { applyLive(s) } }
        .onDisappear { if watch.openActivityId == plan.id { watch.openActivityId = nil } }
        .onReceive(tick) { now = $0 }
        .onReceive(watch.$live) { if let s = $0 { applyLive(s) } }
        .onReceive(watch.$pendingResult) { if let r = $0 { applyResult(r) } }
        .sheet(item: $hold) { target in
            HoldTimerSheet(title: target.name, target: target.target,
                           prepSeconds: store.prefs.holdPrep) { seconds in
                writeHold(seconds, to: target)
            }
        }
        .sheet(item: $plates) { p in PlateSheet(exercise: p.name, target: p.weight) }
    }

    /// Weight the plate sheet loads for: the heaviest weight typed in this session's
    /// sets, else the suggested next load, else last time's top weight.
    private func plateTarget(_ ex: LoggedExercise, sug: Double?) -> Double {
        let typed = ex.sets.map { pf($0.weight) }.max() ?? 0
        if typed > 0 { return typed }
        if let sug, sug > 0 { return sug }
        return lastSess?.exercises.first { $0.name == ex.name }?.maxWeight ?? 0
    }

    /// Write a timed set's measured hold back into the log.
    private func writeHold(_ seconds: Double, to target: HoldTarget) {
        guard let ei = log.firstIndex(where: { $0.id == target.exerciseId }),
              let si = log[ei].sets.firstIndex(where: { $0.id == target.setId }) else { return }
        log[ei].sets[si].seconds = seconds
        toast.show(t("hold.done"))
    }

    // MARK: Live elapsed timer (replaces the last-session block while active)
    private var elapsedSec: Int {
        guard let start = activeWorkout.startDate else { return 0 }
        return max(0, Int(now.timeIntervalSince(start)))
    }

    private var liveTimerBlock: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Circle().fill(Color(hex: plan.color)).frame(width: 8, height: 8)
                Text(t("wk.workout_live").uppercased())
                    .font(.head(10, .bold)).tracking(1).foregroundColor(Theme.sub)
            }
            Spacer()
            Text(fmtDuration(elapsedSec)).font(.num(30)).foregroundColor(Theme.txt)
                .monospacedDigit()
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: plan.color).opacity(0.06))
        .overlay(alignment: .leading) { Rectangle().fill(Color(hex: plan.color)).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }

    // MARK: Live-from-watch mirroring
    private var isWatchLive: Bool { watch.liveActive && watch.live?.activityId == plan.id }

    private var watchLiveBanner: some View {
        let s = watch.live
        return HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Theme.red).frame(width: 7, height: 7)
                Text(t("wk.watch_live").uppercased()).font(.head(10, .bold)).tracking(1).foregroundColor(Theme.txt)
            }
            Spacer()
            if let s {
                if s.hr > 0 { liveStat("\(s.hr)", "bpm", Theme.red) }
                liveStat(fmtDuration(s.elapsedSec), "", Theme.txt)
                if s.kcal > 0 { liveStat("\(s.kcal)", "kcal", Theme.acc) }
            }
        }
        .padding(.vertical, 11).padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.red.opacity(0.07))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.red).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }

    private func liveStat(_ v: String, _ unit: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(v).font(.num(16)).foregroundColor(color)
            if !unit.isEmpty { Text(unit).font(.system(size: 9, weight: .semibold)).foregroundColor(Theme.sub) }
        }
    }

    /// Mirror live telemetry into the session fields — only filling values the user
    /// hasn't typed, so manual edits always win.
    private func applyLive(_ s: WatchLiveSample) {
        guard s.activityId == plan.id else { return }
        if sessAvgHR.isEmpty, s.avgHR > 0 { sessAvgHR = "\(s.avgHR)" }
        if (sessDurationSec ?? 0) == 0, s.elapsedSec > 0 { sessDurationSec = s.elapsedSec }
        if let exs = s.exercises { mergeWatchExercises(exs) }
    }

    /// Fold the finished watch workout into this open session, then let the user
    /// review and save — no manual re-entry of what the wrist already tracked.
    private func applyResult(_ r: WatchResult) {
        guard r.activityId == plan.id else { return }
        if sessAvgHR.isEmpty, let hr = r.avgHR, hr > 0 { sessAvgHR = "\(hr)" }
        if (sessDurationSec ?? 0) == 0, r.durationSec > 0 { sessDurationSec = r.durationSec }
        if sessCalManual.isEmpty, let k = r.activeKcal, k > 0 { sessCalManual = "\(k)" }
        if let exs = r.exercises { mergeWatchExercises(exs) }
        watch.pendingResult = nil
        toast.show(t("wk.watch_synced"))
    }

    /// Fill empty set fields from the wrist's per-set values (never overwrites).
    /// Timed (isometric) exercises carry per-set hold seconds instead of reps.
    private func mergeWatchExercises(_ exs: [WatchResultExercise]) {
        for we in exs {
            guard let li = log.firstIndex(where: { $0.name == we.name }) else { continue }
            let secs = we.seconds ?? []
            let n = max(max(we.reps.count, we.weight.count), secs.count)
            while log[li].sets.count < n { log[li].sets.append(SetEntry()) }
            for j in 0..<n where j < log[li].sets.count {
                if log[li].sets[j].reps.isEmpty, j < we.reps.count, pf(we.reps[j]) > 0 { log[li].sets[j].reps = we.reps[j] }
                if log[li].sets[j].weight.isEmpty, j < we.weight.count, pf(we.weight[j]) > 0 { log[li].sets[j].weight = we.weight[j] }
                if (log[li].sets[j].seconds ?? 0) == 0, j < secs.count, pf(secs[j]) > 0 { log[li].sets[j].seconds = pf(secs[j]) }
            }
        }
    }

    // MARK: Calories burned
    /// Build a session snapshot from the current inputs so the calorie estimate
    /// reflects whatever data the session has (volume, duration, avg HR). The
    /// duration falls back to the live elapsed time so the finish estimate is
    /// based on the real tracked length even if the user never typed one.
    private func currentSessionSnapshot() -> WorkoutSession {
        var s = WorkoutSession(date: today(), planId: plan.id, planName: plan.name,
                               planColor: plan.color, exercises: log)
        s.durationSec = sessDurationSec ?? (elapsedSec > 0 ? elapsedSec : nil)
        s.avgHR = Int(sessAvgHR)
        return s
    }

    private var estCalories: Int { store.estimateCalories(currentSessionSnapshot()) }

    /// Calories are NOT prefilled while the workout is running — pressing Play
    /// starts a live session, it isn't a completed log. The estimate appears only
    /// once the user enters/records data (duration or HR), and is always editable.
    private var caloriesReady: Bool {
        !sessCalManual.isEmpty || (sessDurationSec ?? 0) > 0 || Int(sessAvgHR) ?? 0 > 0
    }

    private var caloriesCard: some View {
        Card(accent: Theme.acc) {
            HStack(spacing: 2) {
                Lbl(text: t("wk.calories"), color: Theme.acc2)
                InfoButton(id: "calories", color: Theme.acc2)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(!sessCalManual.isEmpty ? sessCalManual : (caloriesReady ? "\(estCalories)" : "—"))
                        .font(.num(28)).foregroundColor(caloriesReady ? Theme.acc : Theme.sub)
                    Text("kcal").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
            }
            .padding(.bottom, 10)
            HStack(spacing: 8) {
                Text(t("wk.cal_override").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Spacer()
                InputField(placeholder: caloriesReady ? "\(estCalories)" : "—", text: $sessCalManual, keyboard: .numberPad)
                    .frame(width: 110)
            }
            Text(caloriesReady ? t("wk.cal_hint") : t("wk.cal_at_finish"))
                .font(.system(size: 9)).foregroundColor(Theme.sub).padding(.top, 6)
        }
    }

    // MARK: Session internal-load capture (TRIMP from duration + avg HR)
    private var liveTrimp: Double? {
        guard let d = sessDurationSec, d > 0, let hr = Int(sessAvgHR), hr > 0 else { return nil }
        var s = WorkoutSession(date: today(), planId: plan.id, planName: plan.name, planColor: plan.color)
        s.durationSec = d; s.avgHR = hr
        return store.trimp(s)
    }

    private var sessionLoadCard: some View {
        Card {
            InfoLbl(text: t("load.title"), info: "load", color: Theme.acc2).padding(.bottom, 10)
            HMSField(label: t("wk.duration"), seconds: $sessDurationSec)
            Spacer().frame(height: 12)
            loadField(t("wk.avg_hr"), $sessAvgHR, info: "trimp")
            if let v = liveTrimp {
                HStack(spacing: 6) {
                    Text("TRIMP").font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                    Text("\(Int(v.rounded()))").font(.num(16)).foregroundColor(Theme.acc2)
                    Spacer()
                    Text(t("load.trimp_hint")).font(.system(size: 9)).foregroundColor(Theme.sub)
                }
                .padding(.top, 12)
            }
            // HRV (recovery) is imported automatically from Apple Health / the
            // watch — readiness runs on it without any manual entry here.
        }
    }

    private func loadField(_ label: String, _ binding: Binding<String>, info: String? = nil,
                           keyboard: UIKeyboardType = .numberPad) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(label, info: info)
            InputField(placeholder: "—", text: binding, keyboard: keyboard)
        }
    }

    // MARK: Header
    // The back control MINIMIZES the workout (it keeps running in the background;
    // the floating strip brings it back). It never ends or discards the session —
    // only the Finish / Discard buttons at the bottom do that.
    private var backRow: some View {
        HStack(spacing: 12) {
            GhostButton(title: "↓ \(t("wk.minimize"))") { onBack() }
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name.uppercased()).font(.head(20, .bold)).tracking(0.5)
                    .foregroundColor(Color(hex: plan.color))
                Text("\(plan.sub) · \(today())").font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            Spacer()
        }
    }

    // MARK: Exercise card
    private func exerciseCard(_ exB: Binding<LoggedExercise>) -> some View {
        let ex = exB.wrappedValue
        let bw = ex.bodyweight
        let kind = ex.exKind
        let pr = store.exercisePR(ex.name)
        let prevEx = lastSess?.exercises.first { $0.name == ex.name }
        let sug = store.suggested(planId: plan.id, exercise: ex.name)
        let prog = store.progression(planId: plan.id, exercise: ex.name)
        let effortScale = ex.effortScale

        return Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ex.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                    HStack(spacing: 6) {
                        if !ex.target.isEmpty { Tag(text: ex.target) }
                        if bw { Badge(text: t("wk.bodyweight"), color: Theme.good, bg: Theme.good.opacity(0.14)) }
                        if ex.trainMethod != .normal {
                            Badge(text: ex.trainMethod.short + (ex.supersetGroup.map { " \($0)" } ?? ""),
                                  color: Theme.blue, bg: Theme.blue.opacity(0.14))
                        }
                        if let scale = effortScale {
                            Badge(text: scale.label, color: Theme.acc2, bg: Theme.acc2.opacity(0.14))
                        }
                        // Plate maths for loaded exercises — the alternative is doing
                        // the arithmetic on chalky hands between sets.
                        if kind == .reps, !bw {
                            Button { tap(); plates = PlateTarget(name: ex.name, weight: plateTarget(ex, sug: sug)) } label: {
                                Image(systemName: "circle.hexagongrid.fill").font(.system(size: 13))
                                    .foregroundColor(Theme.acc2)
                                    .frame(width: 26, height: 22)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
                // PR badge, top-right. For timed (isometric) exercises the record is
                // the longest hold (seconds); for everything else it's the top weight
                // (plus an estimated 1RM). Bodyweight reps with no added load show BW.
                let prSeconds = kind == .timed ? store.exerciseMaxSeconds(ex.name) : 0
                if kind == .timed ? prSeconds > 0 : pr > 0 {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("PR").font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                        if kind == .timed {
                            Text("\(trimNum(prSeconds))s").font(.num(20)).foregroundColor(Theme.acc)
                        } else {
                            Text(bw && pr == 0 ? "BW" : "\(trimNum(pr)) kg").font(.num(20)).foregroundColor(Theme.acc)
                            // Estimated 1RM — the best single-effort strength signal,
                            // more comparable across rep ranges than top weight alone.
                            if let e = store.bestE1RM(ex.name), e > 0 {
                                Text("e1RM \(trimNum(e)) kg").font(.system(size: 9, weight: .semibold)).foregroundColor(Theme.acc2)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 10)

            // "Last time" is NOT a banner: each previous set's numbers appear as the
            // grey placeholder inside the very field you type them into, so reps land
            // under REPS and kilos under KG — no separate block to read, no chance of
            // reading the pair in the wrong order. Only the reference date is shown,
            // in the column-header row below.

            if let sug {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right").font(.system(size: 11))
                    Text("\(t("wk.try")) \(trimNum(sug)) kg").font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Theme.acc2)
                .padding(.vertical, 6).padding(.horizontal, 13)
                .background(Theme.acc.opacity(0.09))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.acc.opacity(0.22), lineWidth: 1))
                .padding(.bottom, 11)
            }

            if let prog, prog == .addLoad || prog == .addReps {
                HStack(spacing: 6) {
                    Image(systemName: prog == .addLoad ? "scalemass" : "plus.forwardslash.minus").font(.system(size: 11))
                    Text(t(prog.key)).font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(prog == .addLoad ? Theme.acc : Theme.blue)
                .padding(.vertical, 6).padding(.horizontal, 13)
                .background((prog == .addLoad ? Theme.acc : Theme.blue).opacity(0.09))
                .clipShape(Capsule())
                .padding(.bottom, 11)
            }

            switch kind {
            case .interval:
                IntervalSetBlock(exercise: exB,
                                 prescribedRounds: store.plan(plan.id)?.exercises
                                     .first { $0.name == ex.name }?.rounds)
            case .timed:
                TimedSetRows(exercise: exB, bodyweight: bw, previous: prevEx,
                             lastDate: lastSess?.date,
                             holdTarget: { set in
                                 targetHold(ex, prevSet: previousSet(prevEx, exB.wrappedValue.sets.firstIndex { $0.id == set.id } ?? 0))
                             },
                             onStartHold: { setId, target in
                                 hold = HoldTarget(setId: setId, exerciseId: ex.id, name: ex.name, target: target)
                             })
            case .reps:
                // Effort scale selector
                EffortModeSelector(effortMode: exB.effortMode)
                    .padding(.bottom, 8)

                // Column headers — the "last time" date rides here, at the head of the
                // columns whose placeholders it explains.
                HStack(spacing: 9) {
                    Spacer().frame(width: 28)
                    Text(t("wk.reps").uppercased()).font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub).frame(width: 66)
                    Text(bw ? "+KG" : "KG").font(.head(9, .semibold)).tracking(1.5).foregroundColor(bw ? Theme.good : Theme.sub).frame(width: 66)
                    if effortScale != nil {
                        Text(effortScale!.label).font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.acc2).frame(width: 48)
                    }
                    Spacer()
                    LastTimeCaption(prev: prevEx, date: lastSess?.date)
                }
                .padding(.bottom, 6)

                ForEach(exB.sets) { $set in
                    setRow($set, in: exB, pr: pr, bw: bw, effortScale: effortScale, prev: prevEx)
                }

                // Bodyweight hint
                if bw {
                    Text(t("wk.bw_hint")).font(.system(size: 9)).foregroundColor(Theme.sub).padding(.top, 4)
                }
            }

            // Footer controls — the per-set add/timer only make sense for reps/timed.
            HStack {
                HStack(spacing: 8) {
                    if kind != .interval {
                        GhostButton(title: t("wk.add_set")) { exB.wrappedValue.sets.append(SetEntry()) }
                    }
                    let rest = restSeconds(for: ex)
                    GhostButton(title: "\(t("wk.timer")) \(rest)s", color: Theme.blue) { startRest(rest) }
                }
                Spacer()
                if ex.volume > 0 {
                    Text(volumeLabel(ex, kind: kind, bw: bw))
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
            }
            .padding(.top, 9)

            // Notes
            if showNotes.contains(ex.id) {
                TextField("", text: exB.notes, prompt: Text(t("wk.note_ph")).foregroundColor(Theme.sub), axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 13)).foregroundColor(Theme.txt)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Theme.c2)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.brd, lineWidth: 1))
                    .padding(.top, 9)
            } else {
                Button { tap(); showNotes.insert(ex.id) } label: {
                    Text(t("wk.add_note")).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.brd, lineWidth: 1))
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: Rest
    /// Rest for this exercise: its own value from the plan, else the global default.
    /// An explicit 0 means "no rest here" and is honoured — the plan editor lets the
    /// stepper reach zero, and a superset's first movement genuinely wants none.
    private func restSeconds(for ex: LoggedExercise) -> Int {
        if let planned = store.plan(plan.id)?.exercises.first(where: { $0.name == ex.name })?.restTimerSec {
            return max(0, planned)
        }
        return store.prefs.timer
    }

    /// Start the rest countdown, schedule the notification that fires if the phone
    /// is pocketed or locked before it ends, and push the countdown to the Lock
    /// Screen activity.
    private func startRest(_ seconds: Int) {
        timer.start(seconds)
        RestNotifier.schedule(after: seconds)
        pushLiveActivity(restEndsAt: Date().addingTimeInterval(Double(seconds)))
    }

    /// Mirror the session's progress onto the Lock Screen / Dynamic Island. Called
    /// on the events that actually change what's shown, never on a timer.
    ///
    /// When no rest end is passed, the one still running is recomputed rather than
    /// cleared — otherwise logging a second set would wipe a countdown the user can
    /// still see ticking inside the app.
    private func pushLiveActivity(restEndsAt: Date? = nil) {
        guard store.prefs.liveActivityEnabled else { return }
        let restEnd = restEndsAt ?? (timer.running
            ? Date().addingTimeInterval(Double(timer.remaining)) : nil)
        let sets = log.reduce(0) { $0 + $1.sets.filter { $0.filled }.count }
        // "Current exercise" = the last one with a completed set, which is what you
        // were just doing when the phone went into your pocket.
        let current = log.last { $0.sets.contains { $0.filled } }?.name ?? ""
        LiveActivityController.update(exercise: current, setsDone: sets, restEndsAt: restEnd)
    }

    /// Starting seconds for the hold timer: the plan's target if set, else what was
    /// held last time, else a plain 30 s so the timer always has somewhere to begin.
    private func targetHold(_ ex: LoggedExercise, prevSet: SetEntry?) -> Double {
        if let planned = store.plan(plan.id)?.exercises.first(where: { $0.name == ex.name })?.effectiveTargetSec,
           planned > 0 { return Double(planned) }
        if let p = prevSet?.seconds, p > 0 { return p }
        return 30
    }

    private func volumeLabel(_ ex: LoggedExercise, kind: ExKind, bw: Bool) -> String {
        switch kind {
        case .reps:
            return bw
                ? "\(t("wk.max")) +\(trimNum(ex.maxWeight)) kg"
                : "\(t("wk.vol")) \(Int(ex.volume)) · \(t("wk.max")) \(trimNum(ex.maxWeight)) kg"
        case .timed:
            return "\(t("wk.max")) \(trimNum(ex.maxSeconds))s"
        case .interval:
            return "\(t("wk.vol")) \(fmtDuration(Int(ex.volume)))"
        }
    }

    private func setRow(_ set: Binding<SetEntry>, in exB: Binding<LoggedExercise>,
                        pr: Double, bw: Bool, effortScale: EffortMode?,
                        prev: LoggedExercise?) -> some View {
        let id = set.wrappedValue.id
        let idx = exB.wrappedValue.sets.firstIndex(where: { $0.id == id }) ?? 0
        // Same-numbered set from the last time this exercise was done in this plan.
        // nil past the end (an extra set today has nothing to compare against).
        let prevSet = prev.flatMap { idx < $0.sets.count ? $0.sets[idx] : nil }
        let w = pf(set.wrappedValue.weight)
        let isPR = w > pr && w > 0
        return HStack(spacing: 9) {
            Text("S\(idx + 1)").font(.num(11)).foregroundColor(Theme.sub).frame(width: 28)
            SmallNumField(text: set.reps, placeholder: lastTimeHint(prevSet?.reps), highlight: isPR)
            SmallNumField(text: set.weight, placeholder: lastTimeHint(prevSet?.weight), highlight: isPR && !bw)
            if let scale = effortScale {
                EffortField(scale: scale, value: set.effortVal)
            }
            if isPR && !bw {
                Text("PR").font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.acc)
            } else {
                Button { tap(); exB.wrappedValue.sets.removeAll { $0.id == id } } label: {
                    Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.5))
                        .frame(width: 34, height: 42)
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .background(isPR && !bw ? Theme.acc.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        // Celebrate the moment a typed weight first crosses the exercise's PR.
        .onChange(of: set.wrappedValue.weight) { newVal in
            let w = pf(newVal)
            if !bw && pr > 0 && w > pr { prHaptic() }
        }
        // A set becoming complete is the moment rest starts — that's when you rack
        // the bar. Only on the transition into "filled", so editing a logged number
        // doesn't restart the clock.
        .onChange(of: set.wrappedValue.filled) { nowFilled in
            guard nowFilled else { return }
            // `running`, not `active`: a finished rest still shows its "GO" strip,
            // and the next set must be able to start a fresh countdown.
            let rest = restSeconds(for: exB.wrappedValue)
            if store.prefs.autoRest, !timer.running, rest > 0 {
                startRest(rest)
            } else {
                pushLiveActivity()
            }
        }
    }

    // MARK: Add exercise on the fly
    private var addExerciseCard: some View {
        Card {
            Lbl(text: t("wk.add_ex")).padding(.bottom, 8)
            HStack(spacing: 9) {
                TextField("", text: $addName, prompt: Text(t("wk.add_ex_ph")).foregroundColor(Theme.sub))
                    .font(.system(size: 15, weight: .medium)).foregroundColor(Theme.txt)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
                Button { addExercise() } label: {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.bg)
                        .frame(width: 50, height: 48).background(Theme.acc)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                }.buttonStyle(.plain)
            }
            Text(t("wk.add_ex_hint"))
                .font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 8)
        }
    }

    private func addExercise() {
        let name = addName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        tap()
        let isBW = store.isBodyweightExercise(name)
        var ex = LoggedExercise(name: name, sets: (0..<3).map { _ in SetEntry() }, notes: "", target: "3×10")
        ex.isBodyweight = isBW ? true : nil
        log.append(ex)
        // Persist to the plan template so it appears next time.
        if let idx = store.plans.firstIndex(where: { $0.id == plan.id }) {
            store.plans[idx].exercises.append(PlanExercise(name: name, sets: 3, reps: "10",
                                                           isBodyweight: isBW ? true : nil))
        }
        // Auto-save to the exercise library on first use.
        store.touchExerciseInLibrary(name, isBodyweight: isBW)
        addName = ""
        toast.show(t("wk.ex_added"))
    }

    // MARK: Finish / Discard
    private func saveSession() {
        guard !saved else { return }
        let exercises = log.map { e -> LoggedExercise in
            var copy = e
            copy.sets = e.sets.filter { $0.filled }
            return copy
        }.filter {
            // Interval exercises carry their data in rounds (no sets); keep them when
            // any round was completed. Everything else needs at least one filled set.
            $0.exKind == .interval ? (($0.rounds ?? 0) > 0) : !$0.sets.isEmpty
        }
        guard !exercises.isEmpty else { toast.show(t("wk.nothing_save")); return }

        // Auto-save every exercise to the library and update their bodyweight flag.
        for ex in exercises {
            store.touchExerciseInLibrary(ex.name, isBodyweight: ex.bodyweight)
        }

        var sess = WorkoutSession(date: today(), planId: plan.id,
                                  planName: plan.name, planColor: plan.color,
                                  exercises: exercises)
        // Duration source of truth: the value the user typed, else any value the
        // paired watch streamed in, else the real phone-tracked elapsed time.
        // (Watch data already merges into sessDurationSec via applyLive/applyResult,
        //  so an Apple Watch session takes precedence when present.)
        sess.durationSec = sessDurationSec ?? (elapsedSec > 0 ? elapsedSec : nil)
        sess.avgHR = Int(sessAvgHR)
        sess.caloriesManual = Int(sessCalManual).flatMap { $0 > 0 ? $0 : nil }
        store.sessions.append(sess)
        // Push it to Apple Health when the user opted in, so a session logged here
        // still closes the rings. Silent no-op when the toggle is off.
        if store.prefs.exportsToHealth {
            store.exportToHealth(sess) { ok in
                toast.show(t(ok ? "hk.exported" : "hk.export_failed"))
            }
        }
        saved = true
        timer.stop()
        haptic(.success)
        toast.show(t("wk.session_saved"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { onSaved() }
    }

    /// Explicit destructive discard — only reached via the red button + confirm.
    private func discardSession() {
        timer.stop()
        haptic(.warning)
        toast.show(t("wk.discarded"))
        onSaved()   // tears down the active workout without saving anything
    }
}
