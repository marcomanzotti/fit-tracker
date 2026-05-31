import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Binding var tab: Tab

    @State private var weightInput = ""
    @State private var sleepInput = ""
    @State private var shareURL: IdentURL?

    var body: some View {
        let lw = store.lastWeight
        let bmi = store.bmi(lw)
        let cat = store.bmiCategory(bmi)
        let ws = store.sortedDaily.filter { $0.weight != nil }

        // Check-in
        if !store.hasCheckedIn() {
            checkInCard
        } else {
            checkedInCard
        }

        // Key stats
        HStack(spacing: 9) {
            StatTile(label: t("home.weight"), value: trimNum(lw), unit: "kg", note: "BMI \(trimNum(bmi)) · \(cat.0)", info: "bmi")
            StatTile(label: t("home.streak"), value: "\(store.streak)", valueColor: Theme.acc, note: store.streak == 1 ? t("home.day") : t("home.days"))
            StatTile(label: t("home.sessions"), value: "\(store.sessions.count)", valueColor: Theme.blue, note: t("home.total"))
        }

        weekStripCard
        goalsCard(lw: lw)
        nextWorkoutCard

        Group {
            OverloadCard()
            ReadinessCard()
            LoadCard()
            NutritionCard()
        }

        if ws.count > 1 { weightChartCard(ws) }
        weekComparisonCard
        backupRow
    }

    // MARK: Week activity strip (sporty 7-day overview)
    private var weekStripCard: some View {
        let cal = Calendar.current
        let now = Date()
        // Build the last 7 calendar days, oldest -> today.
        let days: [(label: String, ds: String, isToday: Bool)] = (0..<7).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: now)!
            let ds = isoFormatter.string(from: d)
            return (L.days[cal.component(.weekday, from: d) - 1], ds, ds == today())
        }
        let trainedDays = days.filter { d in store.sessions.contains { $0.date == d.ds } }.count
        return Card {
            HStack {
                Lbl(text: t("home.week_activity"), color: Theme.acc2)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(trainedDays)").font(.num(18)).foregroundColor(Theme.acc)
                    Text("/ 7 \(t("home.workouts").lowercased())").font(.system(size: 10)).foregroundColor(Theme.sub)
                }
            }
            .padding(.bottom, 12)
            HStack(spacing: 7) {
                ForEach(days, id: \.ds) { d in
                    dayPip(d.label, ds: d.ds, isToday: d.isToday)
                }
            }
        }
    }

    private func dayPip(_ label: String, ds: String, isToday: Bool) -> some View {
        let sess = store.sessions.filter { $0.date == ds }
        let color = sess.first.map { Color(hex: $0.planColor) }
        let trained = color != nil
        return VStack(spacing: 6) {
            Text(label.uppercased()).font(.head(9, .semibold)).tracking(0.5)
                .foregroundColor(isToday ? Theme.acc : Theme.sub)
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(trained ? (color ?? Theme.acc) : Theme.c2)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isToday ? Theme.acc : (trained ? Color.clear : Theme.brd),
                            lineWidth: isToday ? 2 : 1)
                if trained {
                    Image(systemName: sess.first!.sportType.isCardio ? sess.first!.sportType.icon : "dumbbell.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.bg)
                    if sess.count > 1 {
                        Text("\(sess.count)").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.bg)
                            .frame(width: 13, height: 13).background(Theme.bg.opacity(0.001))
                            .offset(x: 13, y: -13)
                    }
                } else {
                    Circle().fill(Theme.brd2).frame(width: 4, height: 4)
                }
            }
            .frame(height: 42)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Check-in
    private var checkInCard: some View {
        Card(bg: Theme.c1) {
            Lbl(text: t("home.checkin"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                labeledField("\(t("home.weight")) (KG)", "87,5", $weightInput)
                if store.prefs.sleepEnabled {
                    labeledField("\(t("home.sleep")) (0-100)", "78", $sleepInput)
                }
            }
            .padding(.bottom, 10)
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
                    Text("\(t("home.weight")) \(trimNum(tw?.weight ?? store.lastWeight)) kg" + (tw?.sleep != nil ? " · \(t("home.sleep")) \(tw!.sleep!)/100" : ""))
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
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
            InputField(placeholder: ph, text: binding)
        }
    }

    private func saveCheckIn() {
        let w = pf(weightInput), s = pf(sleepInput)
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
            Lbl(text: t("home.goals"), color: Theme.acc2).padding(.bottom, 12)
            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text(t("home.weight")).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                        Spacer()
                        Text("\(trimNum(lw)) → \(trimNum(p.goalWeight)) kg").font(.num(13)).foregroundColor(Theme.acc)
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
    }

    // MARK: Next workout
    private var nextWorkoutCard: some View {
        Group {
            if let p = store.nextPlan() {
                Button { tap(); tab = .allena } label: {
                    Card(accent: Color(hex: p.color)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Lbl(text: t("home.next_workout")).padding(.bottom, 6)
                                Text(p.name.uppercased()).font(.head(22, .bold)).tracking(0.5)
                                    .foregroundColor(Color(hex: p.color))
                                Text("\(p.sub) · \(p.exercises.count) \(t("home.exercises"))").font(.system(size: 11))
                                    .foregroundColor(Theme.sub).padding(.top, 5)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(Theme.sub)
                        }
                    }
                }
            }
        }
    }

    // MARK: Weight chart
    private func weightChartCard(_ ws: [DailyEntry]) -> some View {
        let data = Array(ws.suffix(14))
        return Card {
            Lbl(text: t("home.weight14")).padding(.bottom, 8)
            Chart(data) { e in
                LineMark(x: .value("g", fmtShort(e.date)), y: .value("kg", e.weight ?? 0))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.acc)
                AreaMark(x: .value("g", fmtShort(e.date)), y: .value("kg", e.weight ?? 0))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Theme.acc.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                PointMark(x: .value("g", fmtShort(e.date)), y: .value("kg", e.weight ?? 0))
                    .foregroundStyle(Theme.acc).symbolSize(18)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .styledAxes()
            .frame(height: 155)
        }
    }

    // MARK: Week comparison
    private var weekComparisonCard: some View {
        let wk0 = store.weekStats(offset: 0)
        let wk1 = store.weekStats(offset: 1)
        let totalVol = store.sessions.reduce(0.0) { $0 + $1.volume }
        return Card {
            Lbl(text: t("home.week_cmp_title")).padding(.bottom, 4)
            compRow(t("home.avg_weight"), wk0.avgWeight.map { "\(trimNum($0)) kg" } ?? "—", wk1.avgWeight.map { "\(trimNum($0)) \(t("home.prev"))" } ?? "—")
            compRow(t("home.workouts"), "\(wk0.sessions)", "\(wk1.sessions) \(t("home.prev"))")
            compRow(t("home.total_volume"), "\(Int(totalVol)) kg", t("home.lifetime"))
        }
    }

    private func compRow(_ label: String, _ a: String, _ b: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
            Spacer()
            Text(a).font(.num(16)).frame(width: 80, alignment: .trailing).foregroundColor(Theme.txt)
            Text(b).font(.system(size: 11)).foregroundColor(Theme.sub).frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
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
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.mut)
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
