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
    private func mergeWatchExercises(_ exs: [WatchResultExercise]) {
        for we in exs {
            guard let li = log.firstIndex(where: { $0.name == we.name }) else { continue }
            let n = max(we.reps.count, we.weight.count)
            while log[li].sets.count < n { log[li].sets.append(SetEntry()) }
            for j in 0..<n where j < log[li].sets.count {
                if log[li].sets[j].reps.isEmpty, j < we.reps.count, pf(we.reps[j]) > 0 { log[li].sets[j].reps = we.reps[j] }
                if log[li].sets[j].weight.isEmpty, j < we.weight.count, pf(we.weight[j]) > 0 { log[li].sets[j].weight = we.weight[j] }
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

    private func lastSessionBlock(_ last: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Lbl(text: "\(t("wk.last")) · \(last.date)", color: Theme.acc2).padding(.bottom, 3)
            ForEach(last.exercises.prefix(3)) { e in
                (Text(e.name).foregroundColor(Theme.txt.opacity(0.7)).fontWeight(.semibold)
                 + Text(": " + e.sets.map { "\(disp($0.weight))×\(disp($0.reps))" }.joined(separator: " · "))
                    .foregroundColor(Theme.sub))
                    .font(.system(size: 11))
            }
            if last.exercises.count > 3 {
                Text("+\(last.exercises.count - 3) \(t("wk.others"))").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
            }
        }
        .padding(.vertical, 11).padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.acc.opacity(0.04))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.acc).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
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
                    }
                }
                Spacer()
                if pr > 0 {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("PR").font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                        Text(bw && pr == 0 ? "BW" : "\(trimNum(pr)) kg").font(.num(20)).foregroundColor(Theme.acc)
                        // Estimated 1RM — the best single-effort strength signal,
                        // more comparable across rep ranges than top weight alone.
                        if let e = store.bestE1RM(ex.name), e > 0 {
                            Text("e1RM \(trimNum(e)) kg").font(.system(size: 9, weight: .semibold)).foregroundColor(Theme.acc2)
                        }
                    }
                }
            }
            .padding(.bottom, 10)

            if let prevEx, !prevEx.sets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("wk.last_time_label").uppercased()).font(.head(9, .semibold)).tracking(2).foregroundColor(Theme.blue)
                    FlowText(items: prevEx.sets.enumerated().map { "S\($0.offset + 1): \(disp($0.element.weight))×\(disp($0.element.reps))" })
                }
                .padding(.vertical, 9).padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.blue.opacity(0.12), lineWidth: 1))
                .padding(.bottom, 10)
            }

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
                intervalBlock(exB)
            case .timed:
                timedBlock(exB, bw: bw)
            case .reps:
                // Effort scale selector
                EffortModeSelector(effortMode: exB.effortMode)
                    .padding(.bottom, 8)

                // Column headers
                HStack(spacing: 9) {
                    Spacer().frame(width: 28)
                    Text(t("wk.reps").uppercased()).font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub).frame(width: 66)
                    Text(bw ? "+KG" : "KG").font(.head(9, .semibold)).tracking(1.5).foregroundColor(bw ? Theme.good : Theme.sub).frame(width: 66)
                    if effortScale != nil {
                        Text(effortScale!.label).font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.acc2).frame(width: 48)
                    }
                    Spacer()
                }
                .padding(.bottom, 6)

                ForEach(exB.sets) { $set in
                    setRow($set, in: exB, pr: pr, bw: bw, effortScale: effortScale)
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
                    GhostButton(title: "\(t("wk.timer")) \(store.prefs.timer)s", color: Theme.blue) { timer.start(store.prefs.timer) }
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

    // MARK: Timed (isometric) logging — per-set hold seconds + optional added load
    private func timedBlock(_ exB: Binding<LoggedExercise>, bw: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 9) {
                Spacer().frame(width: 28)
                Text(t("pe.target_sec").uppercased()).font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub).frame(width: 66)
                Text(bw ? "+KG" : "KG").font(.head(9, .semibold)).tracking(1.5).foregroundColor(bw ? Theme.good : Theme.sub).frame(width: 66)
                Spacer()
            }
            .padding(.bottom, 2)
            ForEach(exB.sets) { $set in
                let idx = exB.wrappedValue.sets.firstIndex(where: { $0.id == $set.id }) ?? 0
                HStack(spacing: 9) {
                    Text("S\(idx + 1)").font(.num(11)).foregroundColor(Theme.sub).frame(width: 28)
                    SmallNumField(text: secondsBinding($set))
                    SmallNumField(text: $set.weight)
                    Button { tap(); exB.wrappedValue.sets.removeAll { $0.id == $set.id } } label: {
                        Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.5))
                            .frame(width: 34, height: 42)
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// String binding over a set's optional `seconds` (decimal-friendly).
    private func secondsBinding(_ set: Binding<SetEntry>) -> Binding<String> {
        Binding(
            get: { set.wrappedValue.seconds.map { trimNum($0) } ?? "" },
            set: { set.wrappedValue.seconds = pf($0) > 0 ? pf($0) : nil }
        )
    }

    // MARK: Interval (HIIT) logging — prescription + completed-rounds stepper
    private func intervalBlock(_ exB: Binding<LoggedExercise>) -> some View {
        let ex = exB.wrappedValue
        let work = ex.workSec ?? 30, rest = ex.restSec ?? 15, target = ex.rounds ?? 8
        let done = Binding(get: { exB.wrappedValue.rounds ?? target },
                           set: { exB.wrappedValue.rounds = $0 })
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                intervalChip("\(work)s", t("pe.work_sec"), Theme.acc)
                intervalChip("\(rest)s", t("pe.rest_sec"), Theme.blue)
                intervalChip("\(work + rest)s", t("wk.round"), Theme.sub)
            }
            HStack(spacing: 10) {
                Text(t("wk.rounds_done").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
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

    private func intervalChip(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.num(16)).foregroundColor(color)
            Text(label.uppercased()).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
                        pr: Double, bw: Bool, effortScale: EffortMode?) -> some View {
        let id = set.wrappedValue.id
        let idx = exB.wrappedValue.sets.firstIndex(where: { $0.id == id }) ?? 0
        let w = pf(set.wrappedValue.weight)
        let isPR = w > pr && w > 0
        return HStack(spacing: 9) {
            Text("S\(idx + 1)").font(.num(11)).foregroundColor(Theme.sub).frame(width: 28)
            SmallNumField(text: set.reps, highlight: isPR)
            SmallNumField(text: set.weight, highlight: isPR && !bw)
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

    private func disp(_ s: String) -> String { s.isEmpty ? "?" : s }
}

// MARK: - Simple wrapping row of small tags
struct FlowText: View {
    let items: [String]
    var body: some View {
        FlexWrap(items, spacing: 5) { item in
            Text(item).font(.num(11)).foregroundColor(Theme.blue)
                .padding(.vertical, 3).padding(.horizontal, 8)
                .background(Theme.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
