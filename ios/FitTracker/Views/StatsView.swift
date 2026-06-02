import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: Store

    @State private var statsTab = "overview"
    @State private var selEx = ""
    @State private var exSearch = ""

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
        let allEx = store.allExerciseNames()
        let filtered = exSearch.isEmpty
            ? allEx
            : allEx.filter { $0.name.localizedCaseInsensitiveContains(exSearch) }
        return Group {
            Card {
                Lbl(text: t("st.select_ex")).padding(.bottom, 8)
                InputField(placeholder: t("st.search_ex"), text: $exSearch, keyboard: .default)
                    .padding(.bottom, 8)
                if !selEx.isEmpty {
                    HStack(spacing: 8) {
                        Text(selEx).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.acc)
                            .lineLimit(1)
                        Spacer()
                        Button { tap(); selEx = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Theme.sub)
                        }
                    }
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Theme.acc.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                } else if !exSearch.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered, id: \.name) { item in
                                Button { tap(); selEx = item.name; exSearch = "" } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name).font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Theme.txt).lineLimit(1)
                                            Text(item.group).font(.system(size: 10)).foregroundColor(Theme.sub)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(Theme.sub)
                                    }
                                    .padding(.vertical, 9).padding(.horizontal, 12)
                                }
                                .buttonStyle(.plain)
                                if item.name != filtered.last?.name {
                                    Rectangle().fill(Theme.brd).frame(height: 1)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                    .background(Theme.c2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
                }
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

    // MARK: History (two calendars only)
    // Workout + nutrition calendars, nothing underneath them: tapping a workout
    // day opens that session, tapping a nutrition day opens its editor. The full
    // session list and the calorie/macro charts moved to the Train and Nutrition
    // pages respectively, so nothing is duplicated here.
    private var history: some View {
        Group {
            SectionHeader(text: t("st.section_workout"), icon: "dumbbell.fill")
            CalendarCard()

            SectionHeader(text: t("st.section_nutrition"), icon: "fork.knife")
            NutritionCalendarCard()
        }
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
