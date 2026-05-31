import SwiftUI

// MARK: - Small helpers
private func zoneColor(_ z: String) -> Color {
    switch z {
    case "ok", "ready": return Theme.good
    case "warn", "easy", "slow", "fast", "high", "low": return Theme.acc2
    case "risk", "rest", "wrong": return Theme.red
    default: return Theme.sub
    }
}

func paceStr(_ minPerUnit: Double) -> String {
    let m = Int(minPerUnit)
    let s = Int((minPerUnit - Double(m)) * 60)
    return String(format: "%d:%02d", m, s)
}

// MARK: - Readiness (HRV) card
struct ReadinessCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let r = store.readiness()
        Group {
            if r.score != nil || r.samples > 0 {
                Card(accent: zoneColor(r.advice)) {
                    Lbl(text: t("load.readiness"), color: Theme.acc2).padding(.bottom, 10)
                    if let score = r.score {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(score)").font(.num(34)).foregroundColor(zoneColor(r.advice))
                            Text("/100").font(.system(size: 12)).foregroundColor(Theme.sub)
                            Spacer()
                            Text(t(adviceKey(r.advice)).uppercased())
                                .font(.head(11, .semibold)).tracking(1).foregroundColor(zoneColor(r.advice))
                        }
                        .padding(.bottom, 8)
                        Bar(value: Double(score) / 100, gradient: [zoneColor(r.advice), Theme.acc])
                    } else {
                        Text(t("load.need_data")).font(.system(size: 12)).foregroundColor(Theme.sub)
                    }
                }
            }
        }
    }
    private func adviceKey(_ a: String) -> String {
        switch a { case "ready": return "load.ready"; case "easy": return "load.easy"; case "rest": return "load.rest"; default: return "load.need_data" }
    }
}

// MARK: - Internal-load card (ACWR + monotony/strain)
struct LoadCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let acwr = store.acwr()
        let wk = store.weekLoad(offset: 0)
        Group {
            if acwr.ratio != nil || wk.total > 0 {
                Card {
                    Lbl(text: t("load.title"), color: Theme.acc2).padding(.bottom, 12)
                    if let ratio = acwr.ratio {
                        HStack {
                            Text(t("load.acwr")).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
                            Spacer()
                            Text(trimNum(ratio)).font(.num(20)).foregroundColor(zoneColor(acwr.zone))
                        }
                        .padding(.bottom, 5)
                        Bar(value: min(1, ratio / 2), gradient: [zoneColor(acwr.zone), zoneColor(acwr.zone)])
                        Text(t(acwrKey(acwr.zone))).font(.system(size: 10)).foregroundColor(zoneColor(acwr.zone))
                            .padding(.top, 5).padding(.bottom, 12)
                    }
                    HStack(spacing: 9) {
                        StatTile(label: t("load.weekly"), value: "\(Int(wk.total))", valueColor: Theme.txt)
                        StatTile(label: t("load.monotony"), value: wk.monotony.map { trimNum(($0 * 10).rounded() / 10) } ?? "—",
                                 valueColor: (wk.monotony ?? 0) > 2 ? Theme.acc2 : Theme.txt)
                        StatTile(label: t("load.strain"), value: wk.strain.map { "\(Int($0))" } ?? "—",
                                 valueColor: Theme.blue)
                    }
                    if (wk.monotony ?? 0) > 2 || acwr.zone == "high" {
                        Text(t("load.deload")).font(.head(11, .semibold)).tracking(0.5)
                            .foregroundColor(Theme.red).padding(.top, 10)
                    }
                }
            }
        }
    }
    private func acwrKey(_ z: String) -> String {
        switch z { case "low": return "load.acwr_low"; case "high": return "load.acwr_high"; default: return "load.acwr_ok" }
    }
}

// MARK: - Nutrition targets card
struct NutritionCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let e = store.energyTargets()
        let trend = store.weightTrend()
        let lea = store.energyAvailability()
        Card(accent: Theme.acc) {
            HStack {
                Lbl(text: t("nut.title"), color: Theme.acc2)
                Spacer()
                Text(modeLabel(e.mode).uppercased()).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.acc)
            }
            .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(e.target))").font(.num(34)).foregroundColor(Theme.txt)
                Text("kcal").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                Text("TDEE \(Int(e.tdee)) · BMR \(Int(e.bmr))").font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 12)

            HStack(spacing: 9) {
                StatTile(label: t("nut.protein"), value: "\(Int(e.protein))", unit: "g", valueColor: Theme.blue)
                StatTile(label: t("nut.carbs"), value: "\(Int(e.carbs))", unit: "g", valueColor: Theme.acc2)
                StatTile(label: t("nut.fat"), value: "\(Int(e.fat))", unit: "g", valueColor: Theme.good)
            }
            .padding(.bottom, 10)
            HStack {
                Text("\(t("nut.carb_high")): \(Int(e.carbHigh))g · \(t("nut.carb_low")): \(Int(e.carbLow))g")
                    .font(.system(size: 10)).foregroundColor(Theme.sub)
                Spacer()
                Text("\(t("nut.salt")) \(trimNum(e.saltMax))g").font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 12)

            // Real weight trend vs target
            if let rate = trend.ratePerWeek {
                HStack {
                    Text(t("nut.trend")).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
                    Spacer()
                    Text("\(rate > 0 ? "+" : "")\(trimNum(rate)) \(t("nut.per_week"))")
                        .font(.num(15)).foregroundColor(zoneColor(trend.status))
                }
                Text(trendText(trend)).font(.system(size: 10)).foregroundColor(zoneColor(trend.status)).padding(.top, 3)
            }
            if lea.risk == "risk" || lea.risk == "warn" {
                Text("\(t(lea.risk == "risk" ? "nut.lea_risk" : "nut.lea_warn"))" + (lea.ea.map { " · EA \(trimNum($0))" } ?? ""))
                    .font(.head(11, .semibold)).tracking(0.3)
                    .foregroundColor(lea.risk == "risk" ? Theme.red : Theme.acc2).padding(.top, 8)
            }
            Text(t("nut.who_note")).font(.system(size: 9)).foregroundColor(Theme.sub).padding(.top, 8)
        }
    }
    private func modeLabel(_ m: GoalMode) -> String {
        switch m { case .cut: return t("nut.cut"); case .bulk: return t("nut.bulk"); default: return t("nut.maintain") }
    }
    private func trendText(_ tr: TrendResult) -> String {
        var s: String
        switch tr.status {
        case "ok": s = t("nut.trend_ok")
        case "fast": s = t("nut.trend_fast")
        case "slow": s = t("nut.trend_slow")
        case "wrong": s = t("nut.trend_wrong")
        default: s = ""
        }
        if tr.kcalAdjust != 0 { s += " · " + t("nut.adjust", tr.kcalAdjust) }
        return s
    }
}

// MARK: - Progressive-overload suggestions card
struct OverloadCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let plan = store.nextPlan()
        let items: [(String, ProgKind)] = plan.map { p in
            p.exercises.compactMap { ex in
                store.progression(planId: p.id, exercise: ex.name).map { (ex.name, $0) }
            }
        } ?? []
        let actionable = items.filter { $0.1 == .addLoad || $0.1 == .addReps }
        return Group {
            if !actionable.isEmpty {
                Card(accent: Theme.acc2) {
                    Lbl(text: t("wk.suggested"), color: Theme.acc2).padding(.bottom, 4)
                    ForEach(actionable.prefix(4).indices, id: \.self) { i in
                        let it = actionable[i]
                        HStack {
                            Text(it.0).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.txt).lineLimit(1)
                            Spacer()
                            Text(t(it.1.key)).font(.head(11, .semibold)).tracking(0.3)
                                .foregroundColor(it.1 == .addLoad ? Theme.acc : Theme.blue)
                        }
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
                    }
                }
            }
        }
    }
}

// MARK: - Calendar (sessions colored by workout type)
struct CalendarCard: View {
    @EnvironmentObject var store: Store
    @State private var monthOffset = 0
    @State private var editing: WorkoutSession?

    var body: some View {
        let cal = Calendar.current
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date())!
        let comps = cal.dateComponents([.year, .month], from: base)
        let firstOfMonth = cal.date(from: comps)!
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7   // Monday=0
        let monthSessions = store.sessions.filter { $0.date.hasPrefix(monthPrefix(firstOfMonth)) }

        return Card {
            HStack {
                Button { tap(); monthOffset -= 1 } label: {
                    Image(systemName: "chevron.left").foregroundColor(Theme.sub).frame(width: 30, height: 30)
                }
                Spacer()
                Text("\(L.months[comps.month! - 1]) \(comps.year!)".uppercased())
                    .font(.head(13, .semibold)).tracking(1).foregroundColor(Theme.txt)
                Spacer()
                Button { tap(); if monthOffset < 0 { monthOffset += 1 } } label: {
                    Image(systemName: "chevron.right").foregroundColor(monthOffset < 0 ? Theme.sub : Theme.mut).frame(width: 30, height: 30)
                }
            }
            .padding(.bottom, 8)

            HStack(spacing: 0) {
                ForEach(Array(L.weekHeaders.enumerated()), id: \.offset) { _, d in
                    Text(d).font(.head(9, .semibold)).foregroundColor(Theme.sub).frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            let cells = firstWeekday + daysInMonth
            let rows = Int(ceil(Double(cells) / 7.0))
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            let day = idx - firstWeekday + 1
                            if day >= 1 && day <= daysInMonth {
                                dayCell(day: day, firstOfMonth: firstOfMonth, sessions: monthSessions)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 38)
                            }
                        }
                    }
                }
            }
            if monthSessions.isEmpty {
                Text(t("cal.no_sessions")).font(.system(size: 11)).foregroundColor(Theme.sub)
                    .frame(maxWidth: .infinity).padding(.top, 10)
            }
        }
        .sheet(item: $editing) { s in SessionEditorView(session: s) }
    }

    private func monthPrefix(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM"
        return f.string(from: d)
    }

    private func dayCell(day: Int, firstOfMonth: Date, sessions: [WorkoutSession]) -> some View {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
        let ds = isoFormatter.string(from: date)
        let daySessions = sessions.filter { $0.date == ds }
        let color = daySessions.first.map { Color(hex: $0.planColor) }
        let isToday = ds == today()
        return Button {
            if let first = daySessions.first { tap(); editing = first }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)").font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundColor(color != nil ? Theme.bg : (isToday ? Theme.acc : Theme.txt))
                if daySessions.count > 1 {
                    Text("\(daySessions.count)").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.bg)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 38)
            .background(color ?? Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isToday && color == nil ? Theme.acc : Color.clear, lineWidth: 1))
        }
        .disabled(daySessions.isEmpty)
    }
}

// MARK: - Session editor (edit / delete a past session)
struct SessionEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var session: WorkoutSession
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("wk.edit_session").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                            Text("\(session.planName) · \(session.date)").font(.system(size: 11)).foregroundColor(Theme.sub)
                        }
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    // Session-level internal load fields
                    Card {
                        Lbl(text: t("load.title")).padding(.bottom, 12)
                        HStack(spacing: 10) {
                            metricField(t("wk.duration"), intBinding(\.durationMin))
                            metricField(t("wk.rpe"), intBinding(\.rpe))
                        }
                        .padding(.bottom, 10)
                        HStack(spacing: 10) {
                            metricField(t("wk.avg_hr"), intBinding(\.avgHR))
                            metricField(t("wk.rmssd"), doubleBinding(\.rmssd))
                        }
                    }

                    ForEach(session.exercises.indices, id: \.self) { i in
                        exerciseEditor(i)
                    }

                    BigButton(title: t("save")) {
                        store.updateSession(session); haptic(.success); dismiss()
                    }
                    Button { tap(); confirmDelete = true } label: {
                        Text(t("wk.del_session")).font(.head(13, .semibold)).foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .alert(t("wk.del_session"), isPresented: $confirmDelete) {
            Button(t("cancel"), role: .cancel) {}
            Button(t("delete"), role: .destructive) { store.deleteSession(session.id); dismiss() }
        } message: { Text(t("confirm_delete")) }
    }

    private func exerciseEditor(_ i: Int) -> some View {
        Card {
            Text(session.exercises[i].name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                .padding(.bottom, 10)
            ForEach(session.exercises[i].sets.indices, id: \.self) { j in
                HStack(spacing: 10) {
                    Text("\(t("wk.set")) \(j + 1)").font(.system(size: 11)).foregroundColor(Theme.sub).frame(width: 54, alignment: .leading)
                    SmallNumField(text: Binding(
                        get: { session.exercises[i].sets[j].reps },
                        set: { session.exercises[i].sets[j].reps = $0 }), placeholder: t("wk.reps"))
                    Text("×").foregroundColor(Theme.sub)
                    SmallNumField(text: Binding(
                        get: { session.exercises[i].sets[j].weight },
                        set: { session.exercises[i].sets[j].weight = $0 }), placeholder: "kg")
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func metricField(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            InputField(placeholder: "—", text: binding, keyboard: .numberPad)
        }
    }
    private func intBinding(_ kp: WritableKeyPath<WorkoutSession, Int?>) -> Binding<String> {
        Binding(get: { session[keyPath: kp].map(String.init) ?? "" },
                set: { session[keyPath: kp] = Int($0) })
    }
    private func doubleBinding(_ kp: WritableKeyPath<WorkoutSession, Double?>) -> Binding<String> {
        Binding(get: { session[keyPath: kp].map { trimNum($0) } ?? "" },
                set: { session[keyPath: kp] = $0.isEmpty ? nil : pf($0) })
    }
}
