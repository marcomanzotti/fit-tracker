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
            StatTile(label: "Peso", value: trimNum(lw), unit: "kg", note: "BMI \(trimNum(bmi)) · \(cat.0)")
            StatTile(label: "Streak", value: "\(store.streak)", valueColor: Theme.acc, note: store.streak == 1 ? "giorno" : "giorni")
            StatTile(label: "Sessioni", value: "\(store.sessions.count)", valueColor: Theme.blue, note: "totali")
        }

        goalsCard(lw: lw)
        nextWorkoutCard

        if ws.count > 1 { weightChartCard(ws) }
        recentPRsCard
        weekComparisonCard
        backupRow
    }

    // MARK: Check-in
    private var checkInCard: some View {
        Card(bg: Theme.c1) {
            Lbl(text: "Check-in di oggi", color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                labeledField("PESO (KG)", "87,5", $weightInput)
                labeledField("SLEEP (0-100)", "78", $sleepInput)
            }
            .padding(.bottom, 10)
            FilledButton(title: "Salva check-in") { saveCheckIn() }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.acc.opacity(0.3), lineWidth: 1))
    }

    private var checkedInCard: some View {
        let tw = store.daily.first { $0.date == today() }
        return Card(accent: Theme.good) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CHECK-IN COMPLETATO").font(.head(12, .semibold)).tracking(1).foregroundColor(Theme.good)
                    Text("Peso \(trimNum(tw?.weight ?? store.lastWeight)) kg" + (tw?.sleep != nil ? " · Sleep \(tw!.sleep!)/100" : ""))
                        .font(.system(size: 11)).foregroundColor(Theme.sub)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(store.streak)").font(.num(22)).foregroundColor(Theme.good)
                    Text(store.streak == 1 ? "giorno" : "gg").font(.system(size: 11)).foregroundColor(Theme.sub)
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
        toast.show("Check-in salvato")
    }

    // MARK: Goals
    private func goalsCard(lw: Double) -> some View {
        let p = store.prefs
        let wtPct = max(0, min(1, (p.startWeight - lw) / max(0.1, p.startWeight - p.goalWeight)))
        let bf = store.currentBF
        let bfPct = bf.map { max(0, min(1, ($0 - p.goalBF) / max(0.1, 35 - p.goalBF))) }
        return Card {
            Lbl(text: "Obiettivi", color: Theme.acc2).padding(.bottom, 12)
            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Peso").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                        Spacer()
                        Text("\(trimNum(lw)) → \(trimNum(p.goalWeight)) kg").font(.num(13)).foregroundColor(Theme.acc)
                    }.padding(.bottom, 5)
                    Bar(value: wtPct).padding(.bottom, bf != nil ? 12 : 0)
                    if let bf, let bfPct {
                        HStack {
                            Text("Grasso").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
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
                                Lbl(text: "Prossimo allenamento").padding(.bottom, 6)
                                Text(p.name.uppercased()).font(.head(22, .bold)).tracking(0.5)
                                    .foregroundColor(Color(hex: p.color))
                                Text("\(p.sub) · \(p.exercises.count) esercizi").font(.system(size: 11))
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
            Lbl(text: "Peso · ultimi 14 giorni").padding(.bottom, 8)
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

    // MARK: Recent PRs
    private var recentPRsCard: some View {
        let items = Array(store.allPRs()
            .filter { $0.value.weight > 0 }
            .sorted { ($0.value.date ?? "") > ($1.value.date ?? "") }
            .prefix(3))
        return Group {
            if !items.isEmpty {
                Card {
                    Lbl(text: "Record recenti").padding(.bottom, 4)
                    ForEach(items.indices, id: \.self) { i in
                        let name = items[i].key
                        let info = items[i].value
                        HStack {
                            Text(name).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.txt)
                            Spacer()
                            Text("\(trimNum(info.weight)) kg").font(.num(22)).foregroundColor(Theme.acc)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
                    }
                }
            }
        }
    }

    // MARK: Week comparison
    private var weekComparisonCard: some View {
        let wk0 = store.weekStats(offset: 0)
        let wk1 = store.weekStats(offset: 1)
        let totalVol = store.sessions.reduce(0.0) { $0 + $1.volume }
        return Card {
            Lbl(text: "Confronto settimane").padding(.bottom, 4)
            compRow("Peso medio", wk0.avgWeight.map { "\(trimNum($0)) kg" } ?? "—", wk1.avgWeight.map { "\(trimNum($0)) prec." } ?? "—")
            compRow("Allenamenti", "\(wk0.sessions)", "\(wk1.sessions) prec.")
            compRow("Volume totale", "\(Int(totalVol)) kg", "lifetime")
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
                Text("BACKUP").font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                Text("Salvataggio automatico locale").font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            Spacer()
            GhostButton(title: "Esporta dati") {
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
