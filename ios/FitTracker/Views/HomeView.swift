import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Binding var tab: Tab

    @State private var weightInput = ""
    // "This week" day logging: a picker for empty days, then the session editor.
    @State private var pickerDate: IdentDate?
    @State private var editingSession: WorkoutSession?
    @State private var pendingEdit: WorkoutSession?

    var body: some View {
        TodayCard()
        nextWorkoutCard
        if !store.hasCheckedIn() { checkInCard } else { checkedInCard }
        weekStripCard
        WeekLoadCard { store.statsRequest = "load"; tab = .stats }
        nutritionTodayCard
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
                Text(t("home.tap_to_log")).font(.ui(10, weight: .medium)).foregroundColor(Theme.sub)
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
            Text(label.uppercased()).font(.head(10, .semibold)).tracking(0.5)
                .foregroundColor(isToday ? Theme.acc : Theme.sub)
            Button {
                tap()
                // Open the day sheet (lists logged workouts + Health/Fitness
                // imports) for any non-future day, so an existing session never
                // blocks reaching the import list. Future days do nothing.
                if ds <= today() { pickerDate = IdentDate(date: ds) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(fill)
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        // On the ivory rest chip a yellow ring is invisible (1.07:1): dark there.
                        .stroke(isToday ? (rest ? Theme.bg : Theme.acc) : ((trained || rest) ? Color.clear : Theme.brd),
                                lineWidth: isToday ? 2 : 1)
                    if trained {
                        Image(systemName: sess.first!.sportType.isCardio ? sess.first!.sportType.icon : "dumbbell.fill")
                            .font(.ui(13, weight: .bold)).foregroundColor(Theme.bg)
                        if sess.count > 1 {
                            Text("\(sess.count)").font(.ui(10, weight: .bold)).foregroundColor(Theme.bg)
                                .frame(width: 13, height: 13).background(Theme.bg.opacity(0.001))
                                .offset(x: 13, y: -13)
                        }
                    } else if rest {
                        RestChip()
                    } else {
                        Image(systemName: "plus").font(.ui(12, weight: .bold)).foregroundColor(Theme.sub)
                    }
                }
                .frame(height: 42)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel([spokenDay(ds), rest ? t("a11y.rest_day") : sess.map(\.planName).joined(separator: ", ")]
                .filter { !$0.isEmpty }.joined(separator: ", "))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Check-in
    // Body weight only: sleep score comes from Apple Health and is shown on the
    // Body → Sleep card, so there's nothing else worth typing here every day.
    private var checkInCard: some View {
        Card(bg: Theme.c1) {
            Lbl(text: t("home.checkin"), color: Theme.acc2).padding(.bottom, 10)
            labeledField("\(t("home.weight")) (\(Units.wLabel.uppercased()))", Units.imperial ? "193" : "87,5", $weightInput)
                .padding(.bottom, 12)
            FilledButton(title: t("home.save_checkin")) { saveCheckIn() }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.acc.opacity(0.3), lineWidth: 1))
    }

    private var checkedInCard: some View {
        let tw = store.daily.first { $0.date == today() }
        return Card(accent: Theme.good) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("home.checkin_done").uppercased()).font(.head(12, .semibold)).tracking(1).foregroundColor(Theme.good)
                    Text("\(dispW(tw?.weight ?? store.lastWeight)) \(Units.wLabel) · \(store.bmiComment(weight: tw?.weight ?? store.lastWeight).text)")
                        .font(.ui(11)).foregroundColor(Theme.sub)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(store.streak)").font(.num(22)).foregroundColor(Theme.good)
                    Text(store.streak == 1 ? t("home.day") : t("home.days")).font(.ui(11)).foregroundColor(Theme.sub)
                    InfoButton(id: .streak, size: 18)
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

    private func saveCheckIn() {
        let w = Units.wIn(pf(weightInput))   // input → kg
        guard Store.plausibleWeightKg.contains(w) else {
            haptic(.error)
            toast.show(t("home.weight_invalid", dispW(Store.plausibleWeightKg.lowerBound),
                         dispW(Store.plausibleWeightKg.upperBound), Units.wLabel), duration: ToastCenter.longDuration)
            return
        }
        store.saveCheckIn(weight: w, sleep: nil)
        weightInput = ""
        toast.show(t("home.checkin_saved"))
    }

    // MARK: Nutrition today (kcal and protein; the rest lives in the Nutrition tab)
    private var nutritionTodayCard: some View {
        let e = store.energyTargets()
        let entry = store.dailyEntry(today())
        let kcal = entry?.totalKcal ?? 0
        let protein = entry?.totalProtein ?? 0
        let pct = e.target > 0 ? Double(kcal) / e.target : 0
        return Button { tap(); tab = .nutri } label: {
            Card(accent: Theme.acc) {
                HStack {
                    Lbl(text: t("nutp.today"), color: Theme.acc2)
                    Spacer()
                    Image(systemName: "chevron.right").font(.ui(11, weight: .semibold)).foregroundColor(Theme.sub)
                }
                .padding(.bottom, 10)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(kcal)").font(.num(28)).foregroundColor(kcal > 0 ? Theme.acc : Theme.sub)
                    Text("/ \(Int(e.target)) kcal").font(.ui(12, weight: .semibold)).foregroundColor(Theme.sub)
                    Spacer()
                    Text("\(t("nut.protein")) \(Int(protein)) / \(Int(e.protein)) g")
                        .font(.ui(11, weight: .semibold)).foregroundColor(Theme.blue)
                }
                .padding(.bottom, 8)
                Bar(value: min(1, pct), gradient: pct > 1.12 ? [Theme.red, Theme.red] : [Theme.acc, Theme.acc2])
            }
        }
        .buttonStyle(.plain)
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
                                        .font(.head(10, .semibold)).tracking(0.5).foregroundColor(Theme.sub)
                                }
                                .padding(.bottom, 6)
                                HStack(spacing: 8) {
                                    Image(systemName: item.icon).font(.ui(18, weight: .bold))
                                        .foregroundColor(Color(hex: item.color))
                                    Text(item.name.uppercased()).font(.head(22, .bold)).tracking(0.5)
                                        .foregroundColor(Color(hex: item.color))
                                }
                                if !item.sub.isEmpty {
                                    Text(item.sub).font(.ui(11)).foregroundColor(Theme.sub).padding(.top, 5)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(Theme.sub).padding(.trailing, 52)
                        }
                    }
                }
                // Outside the card's own button: a button inside a button swallows the tap.
                .overlay(alignment: .trailing) {
                    Button { haptic(.success); store.startRequest = item.id; tab = .allena } label: {
                        Image(systemName: "play.fill").accessibilityLabel(t("a11y.start"))
                            .font(.ui(17, weight: .bold)).foregroundColor(Theme.bg)
                            .frame(width: 46, height: 46).background(Color(hex: item.color)).clipShape(Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.trailing, 14)
                }
            }
        }
    }
}

// MARK: - Chart axis styling shared across the app
extension View {
    /// The axes of every dated chart. The x axis asks for about four labels
    /// whatever the number of points and formats them for the span shown, so the
    /// dates never run into each other. Vertical guide lines in the label gray
    /// let the eye read a value back to its date.
    func dateAxes(_ dates: [Date]) -> some View {
        let span = (dates.max() ?? Date()).timeIntervalSince(dates.min() ?? Date()) / 86_400
        return self
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.sub.opacity(0.18))
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(axisDate(d, spanDays: span)).font(.ui(10)).foregroundStyle(Theme.sub)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.mut)
                    AxisValueLabel().font(.ui(10)).foregroundStyle(Theme.sub)
                }
            }
    }
}
