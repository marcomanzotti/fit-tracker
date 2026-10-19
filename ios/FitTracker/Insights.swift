import SwiftUI
import Charts

// MARK: - Small helpers
private func zoneColor(_ z: String) -> Color {
    switch z {
    case "ok", "ready": return Theme.good
    case "warn", "easy", "slow", "fast", "drift", "high", "low": return Theme.acc2
    case "risk", "rest", "wrong": return Theme.red
    default: return Theme.sub
    }
}

func paceStr(_ minPerUnit: Double) -> String {
    let m = Int(minPerUnit)
    let s = Int((minPerUnit - Double(m)) * 60)
    return String(format: "%d:%02d", m, s)
}

// MARK: - Today: readiness and recovery in one card
struct TodayCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let r = store.readiness()
        let recovery = store.recoveryEstimate()
        Group {
            if r.score != nil || r.samples > 0 || recovery != nil {
                Card(accent: zoneColor(r.advice)) {
                    InfoLbl(text: t("load.readiness"), info: .readiness, color: Theme.acc2).padding(.bottom, 10)
                    readiness(r)
                    if let recovery { recoveryRow(recovery) }
                }
            }
        }
    }

    @ViewBuilder
    private func readiness(_ r: ReadinessResult) -> some View {
        if let score = r.score {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score)").font(.num(34)).foregroundColor(zoneColor(r.advice))
                Text("/100").font(.system(size: 12)).foregroundColor(Theme.sub)
                Spacer()
                Text(t(adviceKey(r.advice)).uppercased())
                    .font(.head(11, .semibold)).tracking(1).foregroundColor(zoneColor(r.advice))
            }
            .padding(.bottom, 8)
            if let scale = store.infoScale(.readiness) { RangeBar(scale: scale, value: Double(score)) }
            if !r.warnings.isEmpty {
                Label(t("load.vitals_warning", r.warnings.map { t(NightVitalsCard.spec($0).name) }.joined(separator: ", ")),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.acc2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        } else {
            Text(t("load.need_data")).font(.system(size: 12)).foregroundColor(Theme.sub)
        }
    }

    private func recoveryRow(_ r: RecoveryEstimate) -> some View {
        let left = r.remaining
        return VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 6)
            HStack(spacing: 2) {
                Text(t("recovery.title")).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
                InfoButton(id: .recovery)
                Spacer()
                Text(left.map { $0 == 0 ? t("recovery.done") : t("recovery.left", $0) } ?? "\(r.hours) h")
                    .font(.num(18)).foregroundColor(left == 0 ? Theme.good : Theme.txt)
            }
            if let left {
                Bar(value: Double(r.hours - left) / Double(max(1, r.hours)), gradient: [Theme.acc2, Theme.good])
            }
            Text(t("recovery.total", r.hours, relativeDay(r.sessionDate)))
                .font(.system(size: 11)).foregroundColor(Theme.sub)
        }
    }

    private func relativeDay(_ date: String) -> String {
        if date == today() { return t("recovery.today") }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()).map { isoFormatter.string(from: $0) }
        return date == yesterday ? t("recovery.yesterday") : fmtDM(date)
    }

    private func adviceKey(_ a: String) -> String {
        switch a { case "ready": return "load.ready"; case "easy": return "load.easy"; case "rest": return "load.rest"; default: return "load.need_data" }
    }
}

// MARK: - Load: this week against the last, and the form (Home summary)
// Banister TRIMP per session, summed by week. Appears only once at least one
// session carries an average HR, since that's what TRIMP is computed from. The
// tap opens Stats › Load, where the form, the trend and the intensity live.
struct WeekLoadCard: View {
    @EnvironmentObject var store: Store
    var open: () -> Void

    var body: some View {
        let week = store.weeklyTrimp()
        let prev = store.weeklyTrimp(offset: 1)
        let form = store.loadDataStatus().reliable ? store.formPercent() : nil
        Group {
            if store.hasAnyTrimp {
                Button { tap(); open() } label: {
                    Card(accent: Theme.acc2) {
                        HStack(spacing: 2) {
                            Lbl(text: t("trimp.title"), color: Theme.acc2)
                            Spacer()
                            if let form, let scale = store.infoScale(.form) { BandLabel(scale: scale, value: form) }
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.sub).padding(.leading, 6)
                        }
                        .padding(.bottom, 12)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(week.rounded()))").font(.num(34)).foregroundColor(Theme.acc2)
                            Text(t("trimp.this_week")).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                            Spacer()
                        }
                        .padding(.bottom, 12)
                        let mx = max(week, prev, 1)
                        cmpRow(t("trimp.this_week"), week, mx, Theme.acc2)
                        cmpRow(t("trimp.last_week"), prev, mx, Theme.sub).padding(.top, 7)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cmpRow(_ label: String, _ value: Double, _ mx: Double, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub).frame(width: 78, alignment: .leading)
            Bar(value: value / mx, gradient: [color, color.opacity(0.6)], height: 8)
            Text("\(Int(value.rounded()))").font(.num(13)).foregroundColor(Theme.txt).frame(width: 38, alignment: .trailing)
        }
    }
}

// MARK: - Internal-load card (ACWR + monotony/strain)
struct LoadCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let ds = store.loadDataStatus()
        let wk = store.weekLoad(offset: 0)
        Group {
            if ds.reliable {
                fullCard(wk: wk)
            } else if ds.sessions > 0 {
                buildingCard(ds)
            }
        }
    }

    // Shown until there is enough load history for ACWR to be trustworthy. With a
    // couple of sessions the ratio is wildly out of scale, so we explain what's
    // still needed instead of printing a meaningless number.
    private func buildingCard(_ ds: Store.LoadDataStatus) -> some View {
        Card(accent: Theme.acc2) {
            HStack(spacing: 2) {
                Lbl(text: t("load.title"), color: Theme.acc2)
                InfoButton(id: .load, color: Theme.acc2)
                Spacer()
                Badge(text: t("load.building"), color: Theme.acc2, bg: Theme.acc2.opacity(0.14))
            }
            .padding(.bottom, 10)
            Text(t("load.building_body", ds.needSessions, ds.needDays))
                .font(.system(size: 12)).foregroundColor(Theme.txt).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
            HStack(spacing: 9) {
                StatTile(label: t("load.sessions_logged"), value: "\(ds.sessions)/\(ds.needSessions)",
                         valueColor: ds.sessions >= ds.needSessions ? Theme.good : Theme.txt)
                StatTile(label: t("load.history_days"), value: "\(ds.spanDays)/\(ds.needDays)",
                         valueColor: ds.spanDays >= ds.needDays ? Theme.good : Theme.txt)
            }
        }
    }

    private func fullCard(wk: WeekLoad) -> some View {
        Group {
                Card {
                    InfoLbl(text: t("load.title"), info: .load, color: Theme.acc2).padding(.bottom, 12)
                    // Runaway acute load plus a monotonous week is Foster's classic
                    // overreaching signature — the one combination worth acting on.
                    if store.deloadAdvice() {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                                Text(t("load.deload")).font(.head(12, .bold)).tracking(0.3)
                            }
                            .foregroundColor(Theme.red)
                            Text(t("load.deload_why")).font(.system(size: 10)).foregroundColor(Theme.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 9).padding(.horizontal, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.bottom, 12)
                    }
                    HStack(spacing: 9) {
                        StatTile(label: t("load.weekly"), value: "\(Int(wk.total))", valueColor: Theme.txt, info: .trimp)
                        StatTile(label: t("load.monotony"), value: wk.monotony.map { trimNum(($0 * 10).rounded() / 10) } ?? "—",
                                 valueColor: (wk.monotony ?? 0) > 2 ? Theme.acc2 : Theme.txt, info: .monotony)
                        StatTile(label: t("load.strain"), value: wk.strain.map { "\(Int($0))" } ?? "—",
                                 valueColor: Theme.blue, info: .strain)
                    }
                }
        }
    }
}

// MARK: - Internal-load trend (visual bar chart of daily sRPE/TRIMP)
struct LoadTrendCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let series = store.dailyLoadSeries(days: 14)
        let hasLoad = series.contains { $0.load > 0 }
        let barColor = Theme.acc2
        Group {
            if hasLoad {
                Card {
                    HStack(spacing: 2) {
                        Lbl(text: t("load.trend_title"), color: Theme.acc2)
                        InfoButton(id: .load, color: Theme.acc2)
                        Spacer()
                    }
                    .padding(.bottom, 12)
                    // Plot against real dates so the x-axis can thin its labels
                    // (every 3rd day) instead of cramming 14 overlapping dates.
                    Chart(series) { p in
                        BarMark(
                            x: .value("day", p.day, unit: .day),
                            y: .value("load", p.load),
                            width: .ratio(0.7)
                        )
                        .cornerRadius(3)
                        .foregroundStyle(LinearGradient(
                            colors: [barColor, barColor.opacity(0.55)],
                            startPoint: .top, endPoint: .bottom))
                    }
                    .chartYScale(domain: .automatic(includesZero: true))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { v in
                            AxisGridLine().foregroundStyle(Theme.mut)
                            AxisValueLabel(centered: false) {
                                if let d = v.as(Date.self) {
                                    Text(fmtDM(isoFormatter.string(from: d)))
                                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Theme.mut)
                            AxisValueLabel().font(.system(size: 10)).foregroundStyle(Theme.sub)
                        }
                    }
                    .frame(height: 120)
                }
            }
        }
    }
}

// MARK: - Nutrition targets card
struct NutritionCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let e = store.energyTargets()
        let trend = store.weightTrend()
        let lea = store.energyAvailability()
        let adh = store.adherence()
        Card(accent: Theme.acc) {
            HStack(spacing: 6) {
                Lbl(text: t("nut.title"), color: Theme.acc2)
                InfoButton(id: .tdee, color: Theme.acc2)
                Spacer()
                if e.adaptive { Badge(text: t("nut.adaptive"), color: Theme.good, bg: Theme.good.opacity(0.14)) }
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
                StatTile(label: t("nut.protein"), value: "\(Int(e.protein))", unit: "g", valueColor: Theme.blue, info: .macros)
                StatTile(label: t("nut.carbs"), value: "\(Int(e.carbs))", unit: "g", valueColor: Theme.acc2, info: .macros)
                StatTile(label: t("nut.fat"), value: "\(Int(e.fat))", unit: "g", valueColor: Theme.good, info: .macros)
            }
            .padding(.bottom, 10)
            // Carb-cycling targets stacked one per line — the "rest day" label
            // wraps awkwardly when placed beside the training-day one.
            HStack(alignment: .top, spacing: 2) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(t("nut.carb_high")): \(Int(e.carbHigh))g")
                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                    Text("\(t("nut.carb_low")): \(Int(e.carbLow))g")
                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                }
                InfoButton(id: .carbcycle)
                Spacer()
                Text("\(t("nut.salt")) \(trimNum(e.saltMax))g").font(.system(size: 10)).foregroundColor(Theme.sub)
                InfoButton(id: .salt, size: 16)
            }
            .padding(.bottom, 12)

            // Real weight trend vs target
            if let rate = trend.ratePerWeek {
                HStack(spacing: 2) {
                    Text(t("nut.trend")).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
                    InfoButton(id: .trend)
                    Spacer()
                    Text("\(rate > 0 ? "+" : "")\(trimNum(rate)) \(t("nut.per_week"))")
                        .font(.num(15)).foregroundColor(zoneColor(trend.status))
                }
                Text(trendText(trend)).font(.system(size: 10)).foregroundColor(zoneColor(trend.status)).padding(.top, 3)
            }
            if lea.risk == "risk" || lea.risk == "warn" {
                HStack(spacing: 2) {
                    Text("\(t(lea.risk == "risk" ? "nut.lea_risk" : "nut.lea_warn"))" + (lea.ea.map { " · EA \(trimNum($0))" } ?? ""))
                        .font(.head(11, .semibold)).tracking(0.3)
                        .foregroundColor(lea.risk == "risk" ? Theme.red : Theme.acc2)
                    InfoButton(id: .lea, color: lea.risk == "risk" ? Theme.red : Theme.acc2)
                    Spacer()
                }
                .padding(.top, 8)
            }
            // Adherence (2-3 week consistency that drives the adaptive target)
            if adh.status != "none" {
                Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 10)
                HStack(spacing: 2) {
                    Text(t("nut.adherence")).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
                    InfoButton(id: .adherence)
                    Spacer()
                }
                HStack(spacing: 9) {
                    StatTile(label: t("nut.logging"), value: "\(Int((adh.loggingPct * 100).rounded()))", unit: "%",
                             valueColor: adh.status == "low_logging" ? Theme.acc2 : Theme.good, info: .adherence)
                    StatTile(label: t("nut.steps_avg"), value: adh.avgSteps.map { "\($0)" } ?? "—",
                             valueColor: Theme.blue, info: .steps)
                    StatTile(label: t("nut.vol_sessions"), value: "\(adh.sessions)", valueColor: Theme.txt)
                }
                if adh.status == "low_logging" {
                    Text(t("nut.low_logging")).font(.system(size: 10)).foregroundColor(Theme.acc2).padding(.top, 8)
                }
            }
            Text(t("nut.who_note")).font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 8)
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
        case "drift": s = t("nut.trend_drift")
        default: s = ""
        }
        if tr.kcalAdjust != 0 { s += " · " + t("nut.adjust", tr.kcalAdjust) }
        return s
    }
}

// MARK: - Calendar (sessions colored by workout type)
struct CalendarCard: View {
    @EnvironmentObject var store: Store
    @State private var monthOffset = 0
    @State private var editing: WorkoutSession?
    @State private var pickerDate: IdentDate?
    @State private var pendingEdit: WorkoutSession?

    var body: some View {
        let cal = Calendar.current
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date())!
        let comps = cal.dateComponents([.year, .month], from: base)
        let firstOfMonth = cal.date(from: comps)!
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7   // Monday=0
        let monthSessions = store.sessions.filter { $0.date.hasPrefix(monthPrefix(firstOfMonth)) }

        return Card {
            MonthHeader(monthOffset: $monthOffset, month: comps.month!, year: comps.year!)

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
                Text(t("cal.tap_hint")).font(.system(size: 11)).foregroundColor(Theme.sub)
                    .frame(maxWidth: .infinity).padding(.top, 10)
            }
        }
        .sheet(item: $editing) { s in SessionEditorView(session: s) }
        .sheet(item: $pickerDate, onDismiss: { if let s = pendingEdit { pendingEdit = nil; editing = s } }) { d in
            DayPickerSheet(date: d.date) { pendingEdit = $0 }
        }
    }

    private func monthPrefix(_ d: Date) -> String {
        cachedFormatter("yyyy-MM").string(from: d)
    }

    private func dayCell(day: Int, firstOfMonth: Date, sessions: [WorkoutSession]) -> some View {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
        let ds = isoFormatter.string(from: date)
        let daySessions = sessions.filter { $0.date == ds }
        let color = daySessions.first.map { Color(hex: $0.planColor) }
        let rest = daySessions.isEmpty && store.isRestDay(ds)
        let dark = color != nil || rest
        let isToday = ds == today()
        // Don't let future days be logged.
        let future = ds > today()
        return Button {
            tap()
            // Always open the day sheet for a non-future day: it lists that day's
            // logged workouts (tap to edit) AND the importable Apple Health /
            // Fitness workouts, so an existing session never blocks the import.
            if !future { pickerDate = IdentDate(date: ds) }
        } label: {
            VStack(spacing: 1) {
                Text("\(day)").font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundColor(dark ? Theme.bg : (isToday ? Theme.acc : Theme.txt))
                if daySessions.count > 1 {
                    Text("\(daySessions.count)").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.bg)
                } else if rest {
                    Image(systemName: Theme.restIcon).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.bg)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 38)
            .chrome(8, fill: color ?? (rest ? Theme.restFill : Color.clear), stroke: isToday && !dark ? Theme.acc : Color.clear)
            .opacity(future ? 0.35 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(future && daySessions.isEmpty)
    }
}
