import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Binding var tab: Tab

    @State private var weightInput = ""
    @State private var sleepInput = ""
    @State private var shareURL: IdentURL?
    @State private var editingGoal = false
    // "This week" day logging: a picker for empty days, then the session editor.
    @State private var pickerDate: IdentDate?
    @State private var editingSession: WorkoutSession?
    @State private var pendingEdit: WorkoutSession?

    var body: some View {
        let lw = store.lastWeight
        let comment = store.bmiComment(weight: lw)

        // Check-in
        if !store.hasCheckedIn() {
            checkInCard
        } else {
            checkedInCard
        }

        // Key stats — three equally-sized tiles in a row (Weight · Streak ·
        // Sessions). Body fat lives in the goals section, so it's not repeated here.
        HStack(spacing: 9) {
            StatTile(label: t("home.weight"), value: dispW(lw), unit: Units.wLabel,
                     note: comment.text, info: "bmi")
            StatTile(label: t("home.streak"), value: "\(store.streak)", valueColor: Theme.acc,
                     note: store.streak == 1 ? t("home.day") : t("home.days"), info: "streak")
            StatTile(label: t("home.sessions"), value: "\(store.sessions.count)", valueColor: Theme.blue,
                     note: t("home.total"), info: "sessions")
        }

        weekStripCard
        nextWorkoutCard
        WeeklyPlanCard()
        goalsCard(lw: lw)

        // Scientific dashboard (visual + data, with info popups).
        // Headline metrics are computable from your data: TRIMP (avg HR) and
        // ACWR (EWMA). Readiness only appears if you log HRV (optional sensor).
        Group {
            TrimpCard()
            LoadCard()
            LoadTrendCard()
            NutritionCard()
            ReadinessCard()
        }

        backupRow
    }

    // MARK: Week activity strip (sporty 7-day overview, tap a day to log)
    private var weekStripCard: some View {
        let cal = Calendar.current
        let now = Date()
        // Build the last 7 calendar days, oldest -> today.
        let days: [(label: String, ds: String, isToday: Bool)] = (0..<7).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: now)!
            let ds = isoFormatter.string(from: d)
            return (L.days[cal.component(.weekday, from: d) - 1], ds, ds == today())
        }
        return Card {
            HStack {
                Lbl(text: t("home.week_activity"), color: Theme.acc2)
                Spacer()
                Text(t("home.tap_to_log")).font(.system(size: 9, weight: .medium)).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 12)
            HStack(spacing: 7) {
                ForEach(days, id: \.ds) { d in
                    dayPip(d.label, ds: d.ds, isToday: d.isToday)
                }
            }
        }
        .sheet(item: $pickerDate, onDismiss: { if let s = pendingEdit { pendingEdit = nil; editingSession = s } }) { d in
            DayPickerSheet(date: d.date) { pendingEdit = $0 }
        }
        .sheet(item: $editingSession) { s in SessionEditorView(session: s) }
    }

    private func dayPip(_ label: String, ds: String, isToday: Bool) -> some View {
        let sess = store.sessions.filter { $0.date == ds }
        let trained = !sess.isEmpty
        let rest = !trained && store.isRestDay(ds)
        let fill: Color = trained ? Color(hex: sess.first!.planColor) : (rest ? Theme.restFill : Theme.c2)
        return VStack(spacing: 6) {
            Text(label.uppercased()).font(.head(9, .semibold)).tracking(0.5)
                .foregroundColor(isToday ? Theme.acc : Theme.sub)
            Button {
                tap()
                if let first = sess.first { editingSession = first }
                else { pickerDate = IdentDate(date: ds) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(fill)
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(isToday ? Theme.acc : ((trained || rest) ? Color.clear : Theme.brd),
                                lineWidth: isToday ? 2 : 1)
                    if trained {
                        Image(systemName: sess.first!.sportType.isCardio ? sess.first!.sportType.icon : "dumbbell.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.bg)
                        if sess.count > 1 {
                            Text("\(sess.count)").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.bg)
                                .frame(width: 13, height: 13).background(Theme.bg.opacity(0.001))
                                .offset(x: 13, y: -13)
                        }
                    } else if rest {
                        RestChip()
                    } else {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.brd2)
                    }
                }
                .frame(height: 42)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Check-in
    private var checkInCard: some View {
        Card(bg: Theme.c1) {
            Lbl(text: t("home.checkin"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                labeledField("\(t("home.weight")) (\(Units.wLabel.uppercased()))", Units.imperial ? "193" : "87,5", $weightInput)
                if store.prefs.sleepEnabled {
                    labeledFieldInfo("\(t("home.sleep")) (0-100)", "78", $sleepInput, info: "sleep")
                }
            }
            .padding(.bottom, 10)
            if store.prefs.healthKitEnabled {
                Text(t("home.health_autofill")).font(.system(size: 9)).foregroundColor(Theme.sub).padding(.bottom, 8)
            } else {
                Spacer().frame(height: 6)
            }
            FilledButton(title: t("home.save_checkin")) { saveCheckIn() }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.acc.opacity(0.3), lineWidth: 1))
        .onAppear { prefillRecovery() }
        .onReceive(store.$daily) { _ in prefillRecovery() }
    }

    /// Fill the sleep-score input from today's entry — which Apple Health gap-fills
    /// on launch (derived from asleep hours) — but only when the field is still
    /// empty, so it never overwrites what the user is typing. Editable + re-savable.
    private func prefillRecovery() {
        guard sleepInput.isEmpty,
              let e = store.daily.first(where: { $0.date == today() }),
              let s = e.sleep, s > 0 else { return }
        sleepInput = "\(s)"
    }

    private var checkedInCard: some View {
        let tw = store.daily.first { $0.date == today() }
        return Card(accent: Theme.good) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("home.checkin_done").uppercased()).font(.head(12, .semibold)).tracking(1).foregroundColor(Theme.good)
                    Text("\(t("home.weight")) \(dispW(tw?.weight ?? store.lastWeight)) \(Units.wLabel)" + (tw?.sleep != nil ? " · \(t("home.sleep")) \(tw!.sleep!)/100" : ""))
                        .font(.system(size: 11)).foregroundColor(Theme.sub)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(store.streak)").font(.num(22)).foregroundColor(Theme.good)
                    Text(store.streak == 1 ? t("home.day") : t("home.days")).font(.system(size: 11)).foregroundColor(Theme.sub)
                }
            }
        }
    }

    private func labeledField(_ label: String, _ ph: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            FieldLabel(label)
            InputField(placeholder: ph, text: binding)
        }
    }

    private func labeledFieldInfo(_ label: String, _ ph: String, _ binding: Binding<String>, info: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            FieldLabel(label, info: info)
            InputField(placeholder: ph, text: binding, keyboard: .numberPad)
        }
    }

    private func saveCheckIn() {
        let w = Units.wIn(pf(weightInput)), s = pf(sleepInput)   // input → kg
        let hasW = w >= 30 && w <= 250
        let hasS = s > 0 && s <= 100
        guard hasW || hasS else { return }
        store.saveCheckIn(weight: hasW ? w : nil, sleep: hasS ? Int(s.rounded()) : nil)
        weightInput = ""; sleepInput = ""
        toast.show(t("home.checkin_saved"))
    }

    // MARK: Goals
    private func goalsCard(lw: Double) -> some View {
        let p = store.prefs
        // Bidirectional: progress from start weight toward the goal, loss or gain.
        let denom = p.goalWeight - p.startWeight
        let wtPct = abs(denom) < 0.1 ? 1 : max(0, min(1, (lw - p.startWeight) / denom))
        let bf = store.currentBF
        let bfPct = bf.map { max(0, min(1, ($0 - p.goalBF) / max(0.1, 35 - p.goalBF))) }
        return Card {
            HStack(spacing: 2) {
                Lbl(text: t("home.goals"), color: Theme.acc2)
                InfoButton(id: "goal", color: Theme.acc2)
                Spacer()
                Button { tap(); editingGoal = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "target").font(.system(size: 10, weight: .bold))
                        Text(t("goal.change").uppercased()).font(.head(9, .semibold)).tracking(0.8)
                    }
                    .foregroundColor(Theme.acc)
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(Theme.acc.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.acc.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(.bottom, 12)
            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text(t("home.weight")).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                        Spacer()
                        Text("\(dispW(lw)) → \(dispW(p.goalWeight)) \(Units.wLabel)").font(.num(13)).foregroundColor(Theme.acc)
                    }.padding(.bottom, 5)
                    Bar(value: wtPct).padding(.bottom, bf != nil ? 12 : 0)
                    if let bf, let bfPct {
                        HStack {
                            Text(t("home.fat")).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                            Spacer()
                            Text("\(trimNum(bf))% → \(trimNum(p.goalBF))%").font(.num(13)).foregroundColor(Theme.red)
                        }.padding(.bottom, 5)
                        Bar(value: max(0.05, 1 - bfPct), gradient: [Theme.red, Theme.acc])
                    }
                }
                GoalRing(value: wtPct, color: Theme.acc, size: 64)
            }
        }
        .sheet(isPresented: $editingGoal) { GoalEditorView() }
    }

    // MARK: Next workout (schedule-aware: strength plan or cardio activity)
    private var nextWorkoutCard: some View {
        Group {
            if let item = store.nextUp() {
                Button { tap(); tab = .allena } label: {
                    Card(accent: Color(hex: item.color)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 6) {
                                    Lbl(text: t("home.next_workout"))
                                    Text("· " + (store.prefs.hasSchedule ? t("plan.scheduled") : t("plan.rotation")))
                                        .font(.head(8, .semibold)).tracking(0.5).foregroundColor(Theme.sub)
                                }
                                .padding(.bottom, 6)
                                HStack(spacing: 8) {
                                    Image(systemName: item.icon).font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: item.color))
                                    Text(item.name.uppercased()).font(.head(22, .bold)).tracking(0.5)
                                        .foregroundColor(Color(hex: item.color))
                                }
                                if !item.sub.isEmpty {
                                    Text(item.sub).font(.system(size: 11)).foregroundColor(Theme.sub).padding(.top, 5)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(Theme.sub)
                        }
                    }
                }
            }
        }
    }

    // MARK: Backup
    private var backupRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("home.backup").uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                Text(t("home.backup_auto")).font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            Spacer()
            GhostButton(title: t("home.export_data")) {
                if let url = store.exportFile() { shareURL = IdentURL(url: url) }
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Theme.c1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
    }
}

// MARK: - Chart axis styling shared across the app
extension View {
    func styledAxes() -> some View {
        self
            // Vertical guide bands: faint lines in the same gray as the numeric
            // labels (Theme.sub) so the eye can read a value back to its date.
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.sub.opacity(0.18))
                    AxisValueLabel().font(.system(size: 8)).foregroundStyle(Theme.sub)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.mut)
                    AxisValueLabel().font(.system(size: 8)).foregroundStyle(Theme.sub)
                }
            }
    }
}
