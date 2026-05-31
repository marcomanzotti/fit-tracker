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
    @State private var sessDuration = ""
    @State private var sessRPE = ""
    @State private var sessAvgHR = ""
    @State private var sessRMSSD = ""

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

            BigButton(title: saved ? t("wk.saved") : t("wk.save_session"), color: saved ? Theme.good : Theme.acc) {
                saveSession()
            }
        }
    }

    // MARK: Session internal-load capture (sRPE / TRIMP inputs)
    private var sessionLoadCard: some View {
        Card {
            Lbl(text: t("load.title"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                loadField(t("wk.duration"), $sessDuration)
                loadField(t("wk.rpe"), $sessRPE)
            }.padding(.bottom, 10)
            HStack(spacing: 10) {
                loadField(t("wk.avg_hr"), $sessAvgHR)
                loadField(t("wk.rmssd"), $sessRMSSD)
            }
        }
    }

    private func loadField(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            InputField(placeholder: "—", text: binding, keyboard: .numberPad)
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
        let pr = store.exercisePR(ex.name)
        let prevEx = lastSess?.exercises.first { $0.name == ex.name }
        let sug = store.suggested(planId: plan.id, exercise: ex.name)
        let prog = store.progression(planId: plan.id, exercise: ex.name)

        return Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ex.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                    HStack(spacing: 6) {
                        if !ex.target.isEmpty { Tag(text: ex.target) }
                        if ex.trainMethod != .normal {
                            Badge(text: ex.trainMethod.short + (ex.supersetGroup.map { " \($0)" } ?? ""),
                                  color: Theme.blue, bg: Theme.blue.opacity(0.14))
                        }
                    }
                }
                Spacer()
                if pr > 0 {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("PR").font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                        Text("\(trimNum(pr)) kg").font(.num(20)).foregroundColor(Theme.acc)
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

            // Column headers
            HStack(spacing: 9) {
                Spacer().frame(width: 28)
                Text(t("wk.reps").uppercased()).font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub).frame(width: 66)
                Text("KG").font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub).frame(width: 66)
                Spacer()
            }
            .padding(.bottom, 6)

            ForEach(log[i].sets.indices, id: \.self) { j in
                setRow(i, j, pr: pr)
            }

            // Footer controls
            HStack {
                HStack(spacing: 8) {
                    GhostButton(title: t("wk.add_set")) { log[i].sets.append(SetEntry()) }
                    GhostButton(title: "\(t("wk.timer")) \(store.prefs.timer)s", color: Theme.blue) { timer.start(store.prefs.timer) }
                }
                Spacer()
                if log[i].volume > 0 {
                    Text("\(t("wk.vol")) \(Int(log[i].volume)) · \(t("wk.max")) \(trimNum(log[i].maxWeight)) kg")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
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

    private func setRow(_ i: Int, _ j: Int, pr: Double) -> some View {
        let w = pf(log[i].sets[j].weight)
        let isPR = w > pr && w > 0
        return HStack(spacing: 9) {
            Text("S\(j + 1)").font(.num(11)).foregroundColor(Theme.sub).frame(width: 28)
            SmallNumField(text: $log[i].sets[j].reps, highlight: isPR)
            SmallNumField(text: $log[i].sets[j].weight, highlight: isPR)
            if isPR {
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
        .background(isPR ? Theme.acc.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
        log.append(LoggedExercise(name: name, sets: (0..<3).map { _ in SetEntry() }, notes: "", target: "3×10"))
        // Persist to the plan template so it appears next time.
        if let idx = store.plans.firstIndex(where: { $0.id == plan.id }) {
            store.plans[idx].exercises.append(PlanExercise(name: name, sets: 3, reps: "10"))
        }
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

        var sess = WorkoutSession(date: today(), planId: plan.id,
                                  planName: plan.name, planColor: plan.color,
                                  exercises: exercises)
        sess.durationMin = Int(sessDuration)
        sess.rpe = Int(sessRPE)
        sess.avgHR = Int(sessAvgHR)
        sess.rmssd = sessRMSSD.isEmpty ? nil : pf(sessRMSSD)
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
