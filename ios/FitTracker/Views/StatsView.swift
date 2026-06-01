import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: Store

    @State private var statsTab = "overview"
    @State private var selEx = ""
    @State private var openId: UUID?
    @State private var editingSession: WorkoutSession?

    private var tabs: [(String, String)] {
        [("overview", t("st.overview")), ("pr", t("st.records")), ("prog", t("st.progress")), ("storico", t("st.history"))]
    }

    var body: some View {
        // Tab bar
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(tabs, id: \.0) { t in
                    Button { tap(); statsTab = t.0 } label: {
                        Text(t.1.uppercased()).font(.head(12, .semibold)).tracking(1)
                            .foregroundColor(statsTab == t.0 ? Theme.bg : Theme.sub)
                            .padding(.vertical, 8).padding(.horizontal, 16)
                            .background(statsTab == t.0 ? Theme.acc : Theme.mut)
                            .clipShape(Capsule())
                    }
                }
            }
        }

        switch statsTab {
        case "overview": overview
        case "pr":       records
        case "prog":     progress
        default:         history
        }
    }

    // MARK: Overview
    private var overview: some View {
        let ws = store.sortedDaily
        let d90 = Array(ws.suffix(90))
        let withW = d90.filter { $0.weight != nil }
        let sleepD = d90.filter { $0.sleep != nil }
        let bf = store.currentBF
        return Group {
            if withW.count > 1 {
                Card {
                    Lbl(text: t("st.weight90")).padding(.bottom, 8)
                    Chart(withW) { e in
                        LineMark(x: .value("g", fmtShort(e.date)), y: .value("w", Units.wOut(e.weight ?? 0)))
                            .interpolationMethod(.catmullRom).foregroundStyle(Theme.acc)
                        AreaMark(x: .value("g", fmtShort(e.date)), y: .value("w", Units.wOut(e.weight ?? 0)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Theme.acc.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    .chartYScale(domain: .automatic(includesZero: false)).styledAxes().frame(height: 155)
                }
            }
            if sleepD.count > 1 {
                Card {
                    Lbl(text: t("st.sleep")).padding(.bottom, 8)
                    Chart(sleepD) { e in
                        LineMark(x: .value("g", fmtShort(e.date)), y: .value("s", e.sleep ?? 0))
                            .interpolationMethod(.catmullRom).foregroundStyle(Theme.blue)
                        AreaMark(x: .value("g", fmtShort(e.date)), y: .value("s", e.sleep ?? 0))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Theme.blue.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    .chartYScale(domain: 0...100).styledAxes().frame(height: 155)
                }
            }
            if withW.count > 1 {
                Card {
                    Lbl(text: t("st.bmi_time")).padding(.bottom, 8)
                    Chart(withW) { e in
                        LineMark(x: .value("g", fmtShort(e.date)), y: .value("bmi", store.bmi(e.weight ?? 0)))
                            .interpolationMethod(.catmullRom).foregroundStyle(Color(hex: "b08fff"))
                        AreaMark(x: .value("g", fmtShort(e.date)), y: .value("bmi", store.bmi(e.weight ?? 0)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "b08fff").opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    .chartYScale(domain: .automatic(includesZero: false)).styledAxes().frame(height: 120)
                }
                if let bf {
                    Card {
                        Lbl(text: t("st.composition")).padding(.bottom, 8)
                        Chart {
                            ForEach(withW) { e in
                                LineMark(x: .value("g", fmtShort(e.date)),
                                         y: .value("w", Units.wOut(((e.weight ?? 0) * (1 - bf / 100) * 10).rounded() / 10)),
                                         series: .value("s", t("st.lean")))
                                    .foregroundStyle(Theme.blue).interpolationMethod(.catmullRom)
                                LineMark(x: .value("g", fmtShort(e.date)),
                                         y: .value("w", Units.wOut(((e.weight ?? 0) * bf / 100 * 10).rounded() / 10)),
                                         series: .value("s", t("st.fat")))
                                    .foregroundStyle(Theme.red).interpolationMethod(.catmullRom)
                            }
                        }
                        .chartForegroundStyleScale(domain: [t("st.lean"), t("st.fat")], range: [Theme.blue, Theme.red])
                        .chartLegend(position: .bottom, spacing: 8)
                        .chartYScale(domain: .automatic(includesZero: false)).styledAxes().frame(height: 155)
                    }
                }
            }
            if withW.count < 2 {
                Card { EmptyBox(title: t("st.no_data"), text: t("st.charts_hint")) }
            }
            profileCard
        }
    }

    // MARK: Profile / goals
    private var profileCard: some View {
        ProfileCard()
    }

    // MARK: Records
    private var records: some View {
        let prs = store.allPRs()
        let names = store.allExerciseNames()
        return Card {
            Lbl(text: t("st.maxes")).padding(.bottom, 4)
            if names.isEmpty {
                Text(t("st.maxes_hint"))
                    .font(.system(size: 12)).foregroundColor(Theme.sub).padding(.vertical, 8)
            }
            ForEach(names.indices, id: \.self) { idx in
                let item = names[idx]
                let pr = prs[item.name]
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.txt)
                        if let d = pr?.date { Text(d).font(.system(size: 10)).foregroundColor(Theme.sub) }
                    }
                    Spacer()
                    Text((pr?.weight ?? 0) > 0 ? "\(trimNum(pr!.weight)) kg" : "—")
                        .font(.num(25)).foregroundColor(Theme.acc)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
            }
        }
    }

    // MARK: Progress
    private var progress: some View {
        Group {
            Card {
                Lbl(text: t("st.select_ex")).padding(.bottom, 8)
                Picker("", selection: $selEx) {
                    Text(t("st.choose")).tag("")
                    ForEach(store.plans) { p in
                        ForEach(p.exercises) { ex in
                            Text("\(p.name) · \(ex.name)").tag(ex.name)
                        }
                    }
                }
                .pickerStyle(.menu).tint(Theme.txt)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }

            if !selEx.isEmpty {
                let data = store.exerciseHistory(selEx)
                if data.isEmpty {
                    Card { EmptyBox(title: t("st.no_data"), text: t("st.progress_hint")) }
                } else {
                    Card {
                        Lbl(text: t("st.max_per_session")).padding(.bottom, 8)
                        Chart(data, id: \.date) { d in
                            LineMark(x: .value("g", d.date), y: .value("kg", d.maxW))
                                .foregroundStyle(Theme.acc).interpolationMethod(.catmullRom)
                            PointMark(x: .value("g", d.date), y: .value("kg", d.maxW))
                                .foregroundStyle(Theme.acc).symbolSize(30)
                        }
                        .chartYScale(domain: .automatic(includesZero: false)).styledAxes().frame(height: 155)
                    }
                    Card {
                        Lbl(text: t("st.vol_per_session")).padding(.bottom, 8)
                        Chart(data, id: \.date) { d in
                            BarMark(x: .value("g", d.date), y: .value("vol", d.vol))
                                .foregroundStyle(Theme.acc.opacity(0.55)).cornerRadius(5)
                        }
                        .styledAxes().frame(height: 120)
                    }
                    if data.count >= 2, let f = data.first, let l = data.last {
                        HStack(spacing: 9) {
                            StatTile(label: t("st.first"), value: trimNum(f.maxW), unit: "kg", valueColor: Theme.sub)
                            StatTile(label: t("st.last"), value: trimNum(l.maxW), unit: "kg")
                            StatTile(label: t("st.delta"), value: "\(l.maxW - f.maxW >= 0 ? "+" : "")\(trimNum(l.maxW - f.maxW))", unit: "kg", valueColor: Theme.acc)
                        }
                    }
                }
            } else {
                Card { EmptyBox(title: t("st.progress"), text: t("st.progress_hint")) }
            }
        }
    }

    // MARK: History (calendar + list)
    private var history: some View {
        let sorted = store.sessions.sorted { $0.date > $1.date }
        return Group {
            CalendarCard()
            if sorted.isEmpty {
                Card { EmptyBox(title: t("st.empty_history"), text: t("st.no_workouts")) }
            } else {
                ForEach(sorted) { s in
                    historyCard(s)
                }
            }
        }
        .sheet(item: $editingSession) { s in SessionEditorView(session: s) }
    }

    private func historyCard(_ s: WorkoutSession) -> some View {
        let isOpen = openId == s.id
        return Card {
            Button { tap(); openId = isOpen ? nil : s.id } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.planName.uppercased()).font(.head(18, .bold)).tracking(0.5)
                            .foregroundColor(Color(hex: s.planColor))
                        Text("\(s.date) · \(s.totalSets) \(t("wk.sets_n")) · ~\(store.estimateCalories(s)) kcal")
                            .font(.system(size: 10)).foregroundColor(Theme.sub)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Badge(text: "\(Int(s.volume)) kg")
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12)).foregroundColor(Theme.sub)
                    }
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(s.exercises) { ex in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(ex.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.txt)
                            FlexWrap(Array(ex.sets.enumerated().map { "S\($0.offset + 1): \(disp($0.element.weight))×\(disp($0.element.reps))" }), spacing: 4) { tag in
                                Text(tag).font(.num(11)).foregroundColor(Theme.sub)
                                    .padding(.vertical, 4).padding(.horizontal, 9)
                                    .background(Theme.mut).clipShape(Capsule())
                            }
                            if !ex.notes.isEmpty {
                                Text(ex.notes).font(.system(size: 11)).foregroundColor(Theme.sub)
                            }
                            Text("Vol \(Int(ex.volume)) · Max \(trimNum(ex.maxWeight)) kg")
                                .font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                        }
                    }
                    if s.sportType.isCardio {
                        Text(cardioLine(s)).font(.system(size: 12)).foregroundColor(Theme.sub)
                    }
                    if let tr = store.trimp(s) {
                        Text("TRIMP \(Int(tr))")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.acc2)
                    } else if let load = s.sRPE {
                        Text("sRPE \(Int(load))")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.acc2)
                    }
                    GhostButton(title: t("wk.edit_session")) { editingSession = s }
                        .padding(.top, 4)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(Theme.brd).frame(height: 1) }
            }
        }
    }

    private func disp(_ s: String) -> String { s.isEmpty ? "?" : s }

    private func cardioLine(_ s: WorkoutSession) -> String {
        var parts: [String] = [s.sportType.label]
        if let sec = s.durationSeconds { parts.append(fmtDuration(sec)) }
        if let km = s.distanceKm { parts.append("\(dispDist(km)) \(Units.distLabel)") }
        if let p = s.effectivePace {
            parts.append(s.paceIsSpeed ? "\(trimNum((p * 10).rounded() / 10)) \(s.paceUnit)" : paceStr(p) + s.paceUnit)
        }
        if let hr = s.avgHR { parts.append("\(hr) bpm") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Editable profile / goals
struct ProfileCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter

    @State private var goalW = ""
    @State private var goalBF = ""
    @State private var startW = ""
    @State private var height = ""
    @State private var timer = ""
    @State private var loaded = false

    var body: some View {
        Card {
            Lbl(text: t("pc.title"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                miniField("\(t("pc.goal_weight")) (\(Units.wLabel))".uppercased(), "80", $goalW)
                miniField(t("pc.goal_bf").uppercased(), "15", $goalBF)
            }.padding(.bottom, 10)
            HStack(spacing: 10) {
                miniField("\(t("pc.start_weight")) (\(Units.wLabel))".uppercased(), "88", $startW)
                miniField("\(t("pc.height")) (\(Units.heightLabel))".uppercased(), Units.imperial ? "71" : "185", $height)
            }.padding(.bottom, 10)
            miniField(t("pc.timer").uppercased(), "60", $timer).padding(.bottom, 12)
            FilledButton(title: t("pc.save")) {
                var p = store.prefs
                if pf(goalW) > 0 { p.goalWeight = Units.wIn(pf(goalW)) }
                if pf(goalBF) > 0 { p.goalBF = pf(goalBF) }
                if pf(startW) > 0 { p.startWeight = Units.wIn(pf(startW)) }
                if pf(height) > 0 { p.height = Units.heightIn(pf(height)) }
                if pf(timer) > 0 { p.timer = Int(pf(timer)) }
                store.prefs = p
                toast.show(t("pc.saved"))
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            goalW = dispW(store.prefs.goalWeight)
            goalBF = trimNum(store.prefs.goalBF)
            startW = dispW(store.prefs.startWeight)
            height = trimNum((Units.heightOut(store.prefs.height) * 10).rounded() / 10)
            timer = "\(store.prefs.timer)"
        }
    }

    private func miniField(_ label: String, _ ph: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            InputField(placeholder: ph, text: binding)
        }
        .frame(maxWidth: .infinity)
    }
}
