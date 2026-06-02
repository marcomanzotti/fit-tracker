import SwiftUI

struct LiveWorkoutView: View {
    let plan: WorkoutPlan
    @Binding var log: [LoggedExercise]
    var onBack: () -> Void
    var onSaved: () -> Void

    @EnvironmentObject var store: Store
    @EnvironmentObject var timer: RestTimer
    @EnvironmentObject var toast: ToastCenter

    @State private var addName = ""
    @State private var showNotes: Set<UUID> = []
    @State private var saved = false
    @State private var sessDurationSec: Int? = nil
    @State private var sessAvgHR = ""
    @State private var sessRMSSD = ""
    @State private var sessCalManual = ""

    private var lastSess: WorkoutSession? { store.lastSession(forPlan: plan.id) }

    var body: some View {
        VStack(spacing: 11) {
            backRow
            if let last = lastSess { lastSessionBlock(last) }

            ForEach(log.indices, id: \.self) { i in
                exerciseCard(i)
            }

            addExerciseCard
            sessionLoadCard
            caloriesCard

            BigButton(title: saved ? t("wk.saved") : t("wk.save_session"), color: saved ? Theme.good : Theme.acc) {
                saveSession()
            }
        }
    }

    // MARK: Calories burned (always shown; manual override wins)
    /// Build a session snapshot from the current inputs so the calorie estimate
    /// reflects whatever data the user has entered (volume, duration, avg HR).
    private func currentSessionSnapshot() -> WorkoutSession {
        var s = WorkoutSession(date: today(), planId: plan.id, planName: plan.name,
                               planColor: plan.color, exercises: log)
        s.durationSec = sessDurationSec
        s.avgHR = Int(sessAvgHR)
        return s
    }

    private var estCalories: Int { store.estimateCalories(currentSessionSnapshot()) }

    private var caloriesCard: some View {
        Card(accent: Theme.acc) {
            HStack(spacing: 2) {
                Lbl(text: t("wk.calories"), color: Theme.acc2)
                InfoButton(id: "calories", color: Theme.acc2)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(sessCalManual.isEmpty ? "\(estCalories)" : sessCalManual)
                        .font(.num(28)).foregroundColor(Theme.acc)
                    Text("kcal").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
            }
            .padding(.bottom, 10)
            HStack(spacing: 8) {
                Text(t("wk.cal_override").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Spacer()
                InputField(placeholder: "\(estCalories)", text: $sessCalManual, keyboard: .numberPad)
                    .frame(width: 110)
            }
            Text(t("wk.cal_hint")).font(.system(size: 9)).foregroundColor(Theme.sub).padding(.top, 6)
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
            // Optional, sensor-only recovery metric — clearly flagged as recommended.
            Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 11)
            HStack(spacing: 7) {
                Text(t("load.recommended").uppercased()).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Badge(text: t("load.sensor"), color: Theme.blue, bg: Theme.blue.opacity(0.12))
                Spacer()
            }
            .padding(.bottom, 9)
            loadField(t("wk.rmssd"), $sessRMSSD, info: "rmssd", keyboard: .decimalPad)
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
    private var backRow: some View {
        HStack(spacing: 12) {
            GhostButton(title: "← \(t("wk.back"))") { onBack() }
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
    private func exerciseCard(_ i: Int) -> some View {
        let ex = log[i]
        let bw = ex.bodyweight
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

            // Effort scale selector
            effortSelector(i)
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

            ForEach(log[i].sets.indices, id: \.self) { j in
                setRow(i, j, pr: pr, bw: bw, effortScale: effortScale)
            }

            // Bodyweight hint
            if bw {
                Text(t("wk.bw_hint")).font(.system(size: 9)).foregroundColor(Theme.sub).padding(.top, 4)
            }

            // Footer controls
            HStack {
                HStack(spacing: 8) {
                    GhostButton(title: t("wk.add_set")) { log[i].sets.append(SetEntry()) }
                    GhostButton(title: "\(t("wk.timer")) \(store.prefs.timer)s", color: Theme.blue) { timer.start(store.prefs.timer) }
                }
                Spacer()
                if log[i].volume > 0 {
                    let volLabel = bw
                        ? "\(t("wk.max")) +\(trimNum(log[i].maxWeight)) kg"
                        : "\(t("wk.vol")) \(Int(log[i].volume)) · \(t("wk.max")) \(trimNum(log[i].maxWeight)) kg"
                    Text(volLabel).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
            }
            .padding(.top, 9)

            // Notes
            if showNotes.contains(ex.id) {
                TextField("", text: $log[i].notes, prompt: Text(t("wk.note_ph")).foregroundColor(Theme.sub), axis: .vertical)
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

    private func setRow(_ i: Int, _ j: Int, pr: Double, bw: Bool, effortScale: EffortMode?) -> some View {
        let w = pf(log[i].sets[j].weight)
        let isPR = w > pr && w > 0
        let effortVal = Binding<String>(
            get: { log[i].sets[j].effortVal.map { "\($0)" } ?? "" },
            set: { log[i].sets[j].effortVal = Int($0) }
        )
        return HStack(spacing: 9) {
            Text("S\(j + 1)").font(.num(11)).foregroundColor(Theme.sub).frame(width: 28)
            SmallNumField(text: $log[i].sets[j].reps, highlight: isPR)
            SmallNumField(text: $log[i].sets[j].weight, highlight: isPR && !bw)
            if let scale = effortScale {
                effortField(scale, binding: effortVal)
            }
            if isPR && !bw {
                Text("PR").font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.acc)
            } else {
                Button { tap(); log[i].sets.remove(at: j) } label: {
                    Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.5))
                        .frame(width: 34, height: 42)
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .background(isPR && !bw ? Theme.acc.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder
    private func effortField(_ scale: EffortMode, binding: Binding<String>) -> some View {
        switch scale {
        case .rir, .rpe:
            SmallNumField(text: binding, highlight: false)
                .frame(width: 48)
        case .fail:
            let isOn = binding.wrappedValue == "1"
            Button {
                tap()
                binding.wrappedValue = isOn ? "0" : "1"
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Theme.red.opacity(0.18) : Theme.c2)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isOn ? Theme.red.opacity(0.5) : Theme.brd, lineWidth: 1)
                    Image(systemName: isOn ? "bolt.fill" : "bolt")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isOn ? Theme.red : Theme.sub)
                }
                .frame(width: 48, height: 42)
            }
            .buttonStyle(.plain)
        }
    }

    private func effortSelector(_ i: Int) -> some View {
        let cur = log[i].effortScale
        return HStack(spacing: 6) {
            Text(t("wk.effort").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            Spacer()
            ForEach([EffortMode?.none] + EffortMode.allCases.map { Optional($0) }, id: \.?.rawValue) { mode in
                let label = mode?.label ?? t("wk.effort.off")
                let active = cur == mode
                Button {
                    tap()
                    log[i].effortMode = mode?.rawValue
                } label: {
                    Text(label).font(.head(10, .semibold)).tracking(0.5)
                        .foregroundColor(active ? Theme.bg : Theme.sub)
                        .padding(.vertical, 5).padding(.horizontal, 9)
                        .background(active ? Theme.acc2 : Theme.c2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(active ? Theme.acc2 : Theme.brd, lineWidth: 1))
                }
                .buttonStyle(.plain)
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

    // MARK: Save
    private func saveSession() {
        guard !saved else { return }
        let exercises = log.map { e -> LoggedExercise in
            var copy = e
            copy.sets = e.sets.filter { $0.filled }
            return copy
        }.filter { !$0.sets.isEmpty }
        guard !exercises.isEmpty else { toast.show(t("wk.nothing_save")); return }

        // Auto-save every exercise to the library and update their bodyweight flag.
        for ex in exercises {
            store.touchExerciseInLibrary(ex.name, isBodyweight: ex.bodyweight)
        }

        var sess = WorkoutSession(date: today(), planId: plan.id,
                                  planName: plan.name, planColor: plan.color,
                                  exercises: exercises)
        sess.durationSec = sessDurationSec
        sess.avgHR = Int(sessAvgHR)
        sess.rmssd = sessRMSSD.isEmpty ? nil : pf(sessRMSSD)
        sess.caloriesManual = Int(sessCalManual).flatMap { $0 > 0 ? $0 : nil }
        store.sessions.append(sess)
        saved = true
        timer.stop()
        haptic(.success)
        toast.show(t("wk.session_saved"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { onSaved() }
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
