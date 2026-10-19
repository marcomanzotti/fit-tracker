import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Store.self) var store

    @State private var statsTab = "overview"
    @State private var selEx = ""          // selected movement family (base)
    @State private var exSearch = ""
    @State private var browseCat: String?  // expanded muscle group in the browser
    @State private var editingFam: FamilyEdit?
    @State private var selVariant: String?  // chosen variant within the selected family
    @State private var exSortKey: ExSortKey = .recent
    @State private var exSortAsc = false
    @State private var showManage = false
    @State private var compWindow: ChartWindow = .m6
    @State private var progWindow: ChartWindow = .y1

    private var tabs: [(String, String)] {
        [("overview", t("st.overview")), ("load", t("st.load")), ("pr", t("st.records")), ("prog", t("st.progress"))]
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
                    .accessibilityAddTraits(statsTab == t.0 ? .isSelected : [])
                }
            }
        }

        Color.clear.frame(height: 0)
            .onChange(of: store.statsRequest, initial: true) { _, request in
                guard let request else { return }
                statsTab = request
                store.statsRequest = nil
            }

        switch statsTab {
        case "overview": overview
        case "load":     load
        case "pr":       records
        default:         progress
        }
    }

    // MARK: Overview
    // Every daily-derived metric uses MetricChartCard: weekly averages over the
    // last 2 months, and an expand button → a larger view with a
    // day/week/month/year toggle.
    private var overview: some View {
        let ws = store.sortedDaily
        let withW = ws.filter { $0.weight != nil }
        let bf = store.currentBF
        return Group {
            WeeklySummaryCard()
            StatsSection(id: "body", title: t("st.sec_body")) {
            MetricChartCard(title: t("home.weight"), info: .weight, color: Theme.acc) {
                $0.weight.map { Units.wOut($0) }
            }
            MetricChartCard(title: t("st.bmi_time"), info: .bmi, color: Theme.purple) {
                e in e.weight.map { store.bmi($0) }
            }
            // FFMI alongside BMI, normalised like the card and the "i" sheet, and only on
            // days between two body-fat measurements (the weight line again otherwise).
            MetricChartCard(title: t("st.ffmi_time"), info: .ffmi, color: Theme.blue) {
                e in e.weight.flatMap { store.ffmiTrend(on: e.date, weight: $0) }
            }
            if withW.count > 1 {
                if let bf {
                    let shown = withW.filter { compWindow.contains($0.date) }
                    Card {
                        InfoLbl(text: t("st.composition"), info: .bodyfat).padding(.bottom, 8)
                        ChartWindowPicker(window: $compWindow).padding(.bottom, 10)
                        Chart {
                            ForEach(shown) { e in
                                LineMark(x: .value(t("chart.date"), chartDay(e.date), unit: .day),
                                         y: .value("w", Units.wOut(((e.weight ?? 0) * (1 - bf / 100) * 10).rounded() / 10)),
                                         series: .value("s", t("st.lean")))
                                    .foregroundStyle(Theme.blue).interpolationMethod(.catmullRom)
                                LineMark(x: .value(t("chart.date"), chartDay(e.date), unit: .day),
                                         y: .value("w", Units.wOut(((e.weight ?? 0) * bf / 100 * 10).rounded() / 10)),
                                         series: .value("s", t("st.fat")))
                                    .foregroundStyle(Theme.fat).interpolationMethod(.catmullRom)
                            }
                        }
                        .chartForegroundStyleScale(domain: [t("st.lean"), t("st.fat")], range: [Theme.blue, Theme.fat])
                        .chartLegend(position: .bottom, spacing: 8)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .dateAxes(shown.map { chartDay($0.date) }).frame(height: 155)
                    }
                }
            }
            if withW.count < 2 {
                Card { EmptyBox(title: t("st.no_data"), text: t("st.charts_hint"), icon: "chart.xyaxis.line") }
            }
            }
            StatsSection(id: "sleep", title: t("st.sec_sleep")) {
            MetricChartCard(title: t("st.sleep"), info: .sleep, color: Theme.blue, yDomain: 0...100) {
                $0.sleep.map(Double.init)
            }
            MetricChartCard(title: t("st.hrv_time"), info: .hrv, color: Theme.blue, unit: "ms") { $0.hrvSleep }
            MetricChartCard(title: t("st.rhr_time"), info: .restingHR, color: Theme.red, unit: "bpm") {
                $0.restHR.map(Double.init)
            }
            MetricChartCard(title: t("st.resp_time"), info: .respRate, color: Theme.blue, unit: "/min") { $0.respRate }
            MetricChartCard(title: t("st.spo2_time"), info: .spo2, color: Color(hex: "ff5d5d"), unit: "%") { $0.spo2 }
            MetricChartCard(title: t("st.walk_hr_time"), info: .walkingHR, color: Theme.acc2, unit: "bpm") {
                $0.walkingHR.map(Double.init)
            }
                VitalsTrendCard()
            }
            StatsSection(id: "activity", title: t("st.sec_activity")) {
            MetricChartCard(title: t("st.steps_time"), info: .steps, color: Theme.orange, kind: .bar) {
                $0.steps.map(Double.init)
            }
            MetricChartCard(title: t("st.daylight_time"), info: .daylight, color: Theme.acc, kind: .bar, unit: "min") {
                $0.daylightMin.map(Double.init)
            }
            MetricChartCard(title: t("st.stand_time"), info: .stand, color: Theme.good, kind: .bar, unit: "h") {
                $0.standHours.map(Double.init)
            }
            MetricChartCard(title: t("st.vo2_time"), info: .vo2max, color: Theme.good) {
                $0.vo2max
            }
                FitnessCard()
                MuscleVolumeCard()
            }
        }
    }

    // MARK: Load — the form, the weekly trend, the time in zones, monotony and strain
    private var load: some View {
        Group {
            FormCard()
            LoadTrendCard()
            LoadCard()
            IntensityCard()
        }
    }

    // MARK: Records
    @ViewBuilder
    private var records: some View {
        StrengthCard()
        prFeed
        currentMaxes
    }

    /// The history of getting stronger: every moment a top weight, an estimated 1RM
    /// or a hold beat its own previous best, newest first. The maxima table below
    /// answers "what can I lift"; this answers "when did that change".
    private var prFeed: some View {
        let events = store.prTimeline()
        return Card(accent: Theme.acc) {
            Lbl(text: t("st.pr_feed"), color: Theme.acc2).padding(.bottom, 4)
            if events.isEmpty {
                Text(t("st.pr_none")).font(.ui(12)).foregroundColor(Theme.sub).padding(.vertical, 8)
            }
            ForEach(events) { e in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.exercise).font(.ui(13, weight: .semibold)).foregroundColor(Theme.txt)
                            .lineLimit(1)
                        Text("\(fmtDM(e.date)) · \(t(e.labelKey))")
                            .font(.ui(10)).foregroundColor(Theme.sub)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(trimNum(e.value))\(e.unit)").font(.num(19)).foregroundColor(Theme.acc)
                        if let d = e.delta, d > 0 {
                            Text("+\(trimNum(d))\(e.unit)").font(.ui(10, weight: .semibold))
                                .foregroundColor(Theme.good)
                        } else {
                            Text(t("st.pr_first")).font(.ui(10)).foregroundColor(Theme.sub)
                        }
                    }
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
            }
        }
    }

    private var currentMaxes: some View {
        let prs = store.allPRs()
        let names = store.allExerciseNames()
        return Card {
            Lbl(text: t("st.maxes")).padding(.bottom, 4)
            if names.isEmpty {
                Text(t("st.maxes_hint"))
                    .font(.ui(12)).foregroundColor(Theme.sub).padding(.vertical, 8)
            }
            ForEach(names.indices, id: \.self) { idx in
                let item = names[idx]
                let pr = prs[item.name]
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.ui(13, weight: .semibold)).foregroundColor(Theme.txt)
                        if let d = pr?.date { Text(fmtDM(d)).font(.ui(10)).foregroundColor(Theme.sub) }
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

    /// Sort keys for the exercise browser — mirrors the nutrition library's logic.
    enum ExSortKey: String, CaseIterable {
        case recent, alpha, sessions
        var label: String {
            switch self {
            case .recent:   return t("food.sort.recent")
            case .alpha:    return t("food.sort.alpha")
            case .sessions: return t("st.sort.sessions")
            }
        }
    }

    // MARK: Progress — search + browse-by-muscle, grouped into movement families
    private var progress: some View {
        let families = sortedFamilies(store.exerciseFamilies())
        let q = exSearch.trimmingCharacters(in: .whitespaces)
        let filtered = q.isEmpty ? families
            : families.filter { f in
                f.base.localizedCaseInsensitiveContains(q) || f.names.contains { $0.localizedCaseInsensitiveContains(q) }
            }
        // Variants saved under the selected family (only meaningful when > 1).
        let variants = selEx.isEmpty ? [] : (families.first { $0.base == selEx }?.names ?? [])
        return Group {
            Card {
                HStack {
                    Lbl(text: t("st.select_ex"))
                    Spacer()
                    Button { tap(); showManage = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "pencil").font(.ui(11, weight: .bold))
                            Text(t("st.manage")).font(.head(10, .semibold)).tracking(0.5)
                        }
                        .foregroundColor(Theme.sub)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Theme.c2).clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.brd, lineWidth: 1))
                    }.buttonStyle(PressableStyle())
                }
                .padding(.bottom, 8)
                InputField(placeholder: t("st.search_ex"), text: $exSearch, keyboard: .default)
                    .padding(.bottom, 8)
                if !selEx.isEmpty {
                    selectedFamilyChip
                    if variants.count > 1 { variantPicker(variants) }
                } else if !q.isEmpty {
                    // Searching: flat list of matching families.
                    familyList(filtered)
                } else {
                    // Browsing: sort bar + a card per muscle group, expandable.
                    exSortBar.padding(.bottom, 8)
                    browseByCategory(families)
                }
            }

            if !selEx.isEmpty {
                // A chosen variant narrows the history to that one exercise name;
                // otherwise the whole family is aggregated.
                let all = selVariant.map { store.exerciseHistory($0) } ?? store.exerciseHistory(family: selEx)
                let data = all.filter { progWindow.contains(isoFormatter.string(from: $0.day)) }
                if all.isEmpty {
                    Card { EmptyBox(title: t("st.no_data"), text: t("st.progress_hint"), icon: "dumbbell") }
                } else {
                    ChartWindowPicker(window: $progWindow)
                    Card {
                        InfoLbl(text: t("st.max_per_session"), info: .overload).padding(.bottom, 8)
                        Chart(data) { d in
                            LineMark(x: .value(t("chart.date"), d.day, unit: .day), y: .value("kg", d.maxW))
                                .foregroundStyle(Theme.acc).interpolationMethod(.catmullRom)
                            PointMark(x: .value(t("chart.date"), d.day, unit: .day), y: .value("kg", d.maxW))
                                .foregroundStyle(Theme.acc).symbolSize(data.count > 40 ? 10 : 30)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .dateAxes(data.map(\.day)).frame(height: 155)
                    }
                    Card {
                        InfoLbl(text: t("st.vol_per_session"), info: .volume).padding(.bottom, 8)
                        Chart(data) { d in
                            BarMark(x: .value(t("chart.date"), d.day, unit: .day), y: .value("vol", d.vol))
                                .foregroundStyle(Theme.acc.opacity(0.55)).cornerRadius(3)
                        }
                        .dateAxes(data.map(\.day)).frame(height: 120)
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
                Card { EmptyBox(title: t("st.progress"), text: t("st.progress_hint"), icon: "dumbbell") }
            }
        }
        .sheet(item: $editingFam) { fam in ExerciseFamilyEditor(base: fam.base) }
        .sheet(isPresented: $showManage) {
            ExerciseManagerView()
                .onDisappear {
                    // The managed name may have changed/disappeared; reset selection
                    // so the progress view never points at a deleted exercise.
                    selEx = ""; selVariant = nil
                }
        }
    }

    private var selectedFamilyChip: some View {
        HStack(spacing: 8) {
            Text(selEx).font(.ui(13, weight: .semibold)).foregroundColor(Theme.acc).lineLimit(1)
            Spacer()
            Button { tap(); editingFam = FamilyEdit(base: selEx) } label: {
                Image(systemName: "pencil").accessibilityLabel(t("a11y.edit")).font(.ui(12)).foregroundColor(Theme.sub).frame(width: 28, height: 28)
            }.buttonStyle(PressableStyle())
            Button { tap(); selEx = ""; selVariant = nil } label: {
                Image(systemName: "xmark.circle.fill").accessibilityLabel(t("a11y.clear")).foregroundColor(Theme.sub)
            }.buttonStyle(PressableStyle())
        }
        .padding(.vertical, 6).padding(.horizontal, 12)
        .background(Theme.acc.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }

    /// Horizontal capsule sort bar for the exercise browser (recent / A-Z /
    /// #sessions), mirroring the nutrition library.
    private var exSortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(t("food.sort").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                ForEach(ExSortKey.allCases, id: \.self) { key in
                    let active = exSortKey == key
                    Button {
                        tap()
                        if exSortKey == key { exSortAsc.toggle() } else { exSortKey = key; exSortAsc = false }
                    } label: {
                        HStack(spacing: 3) {
                            Text(key.label).font(.head(10, .semibold)).tracking(0.5)
                            if active { Image(systemName: exSortAsc ? "arrow.up" : "arrow.down").font(.ui(10, weight: .bold)) }
                        }
                        .foregroundColor(active ? Theme.bg : Theme.sub)
                        .padding(.vertical, 5).padding(.horizontal, 9)
                        .background(active ? Theme.acc : Theme.c2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(active ? Theme.acc : Theme.brd, lineWidth: 1))
                    }.buttonStyle(PressableStyle())
                }
            }
        }
    }

    /// Pick which saved variant of the selected family to view (e.g. "wide grip"
    /// vs "close grip"). "All" aggregates the whole family. Only shown when the
    /// user actually saved more than one variant under the same base.
    private func variantPicker(_ names: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                variantChip(t("st.all_variants"), selected: selVariant == nil) { selVariant = nil }
                ForEach(names, id: \.self) { n in
                    variantChip(n, selected: selVariant == n) { selVariant = n }
                }
            }
        }
        .padding(.top, 8)
    }

    private func variantChip(_ label: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button { tap(); action() } label: {
            Text(label).font(.head(10, .semibold)).tracking(0.3).lineLimit(1)
                .foregroundColor(selected ? Theme.bg : Theme.sub)
                .padding(.vertical, 5).padding(.horizontal, 10)
                .background(selected ? Theme.acc : Theme.c2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? Theme.acc : Theme.brd, lineWidth: 1))
        }.buttonStyle(PressableStyle())
    }

    /// Apply the chosen sort to the family list. "recent" uses the most recent
    /// lastUsed across the family's variants; "sessions" counts logged sessions.
    private func sortedFamilies(_ fams: [Store.ExFamily]) -> [Store.ExFamily] {
        let asc = exSortAsc
        func cmp<T: Comparable>(_ a: T, _ b: T) -> Bool { asc ? a < b : a > b }
        switch exSortKey {
        case .alpha:
            return fams.sorted { asc ? $0.base.localizedCaseInsensitiveCompare($1.base) == .orderedAscending
                                     : $0.base.localizedCaseInsensitiveCompare($1.base) == .orderedDescending }
        case .recent:
            return fams.sorted { cmp(store.familyLastUsed($0), store.familyLastUsed($1)) }
        case .sessions:
            return fams.sorted { cmp(store.familySessionCount($0), store.familySessionCount($1)) }
        }
    }

    private func familyList(_ fams: [Store.ExFamily]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(fams) { f in
                    familyRow(f)
                    if f.id != fams.last?.id { Rectangle().fill(Theme.brd).frame(height: 1) }
                }
            }
        }
        .frame(maxHeight: 260)
        .chrome()
    }

    private func browseByCategory(_ fams: [Store.ExFamily]) -> some View {
        let byCat = Dictionary(grouping: fams) { $0.category }
        let cats = MuscleGroup.allCases.filter { byCat[$0.rawValue]?.isEmpty == false }
        return VStack(spacing: 8) {
            if fams.isEmpty {
                Text(t("st.maxes_hint")).font(.ui(12)).foregroundColor(Theme.sub).padding(.vertical, 8)
            }
            ForEach(cats) { mg in
                let group = byCat[mg.rawValue] ?? []
                VStack(spacing: 0) {
                    Button { tap(); browseCat = (browseCat == mg.rawValue) ? nil : mg.rawValue } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill").font(.ui(10)).foregroundColor(Color(hex: mg.color))
                            Text(t(mg.labelKey).uppercased()).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.txt)
                            Text("\(group.count)").font(.ui(10)).foregroundColor(Theme.sub)
                            Spacer()
                            Image(systemName: browseCat == mg.rawValue ? "chevron.up" : "chevron.down")
                                .font(.ui(11)).foregroundColor(Theme.sub)
                        }
                        .padding(.vertical, 11).padding(.horizontal, 12)
                    }.buttonStyle(PressableStyle())
                    if browseCat == mg.rawValue {
                        ForEach(group) { f in
                            Rectangle().fill(Theme.brd).frame(height: 1)
                            familyRow(f)
                        }
                    }
                }
                .chrome()
            }
        }
    }

    private func familyRow(_ f: Store.ExFamily) -> some View {
        let mg = MuscleGroup(rawValue: f.category) ?? .other
        return Button { tap(); selEx = f.base; selVariant = nil; exSearch = "" } label: {
            HStack {
                Circle().fill(Color(hex: mg.color)).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.base).font(.ui(13, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                    if f.names.count > 1 {
                        Text("\(f.names.count) \(t("st.variants"))").font(.ui(10)).foregroundColor(Theme.sub)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.ui(11)).foregroundColor(Theme.sub)
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
        }.buttonStyle(PressableStyle())
    }
}

// MARK: - Exercise family editor
/// Identifiable wrapper so a family base string can drive `.sheet(item:)`.
struct FamilyEdit: Identifiable { let id = UUID(); let base: String }

/// Reassign each variant in a movement family: change its muscle group, or retype
/// its family so it merges with another movement (or splits into its own). This is
/// the manual control behind the "explicit base + variant" model.
struct ExerciseFamilyEditor: View {
    @Environment(Store.self) var store
    @Environment(\.dismiss) private var dismiss
    let base: String

    struct Row: Identifiable { let id = UUID(); let name: String; var base: String; var category: String }
    @State private var rows: [Row] = []
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(t("st.edit_family").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        }
                    }
                    .padding(.top, 18)
                    Text(t("st.family_hint")).font(.ui(11)).foregroundColor(Theme.sub).lineSpacing(2)

                    ForEach($rows) { $row in
                        Card {
                            Text(row.name).font(.ui(14, weight: .semibold)).foregroundColor(Theme.txt)
                                .padding(.bottom, 10)
                            FieldLabel(t("st.family"))
                            InputField(placeholder: base, text: $row.base, keyboard: .default).padding(.bottom, 10)
                            HStack {
                                Text(t("st.muscle").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                                Spacer()
                                Menu {
                                    ForEach(MuscleGroup.allCases) { mg in
                                        Button(t(mg.labelKey)) { row.category = mg.rawValue }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(t("mg." + row.category)).font(.ui(12, weight: .semibold)).foregroundColor(Theme.txt)
                                        Image(systemName: "chevron.down").font(.ui(10)).foregroundColor(Theme.sub)
                                    }
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .chrome(8)
                                }
                            }
                        }
                    }

                    BigButton(title: t("save")) { save() }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let names = store.exerciseFamilies().first { $0.base == base }?.names ?? [base]
            rows = names.map { Row(name: $0, base: store.exerciseBase($0), category: store.exerciseCategory($0)) }
        }
    }

    private func save() {
        for r in rows { store.setExerciseFamily(r.name, base: r.base, category: r.category) }
        haptic(.success)
        dismiss()
    }
}

// MARK: - Manage exercises (rename · merge similar · delete from history)
/// A single screen to clean up the exercise list: merge accidental duplicates
/// (same name up to case/spacing/accents), rename an exercise across the whole
/// history, or delete one entirely. Every action rewrites past sessions, plans
/// and the library through the Store, so PRs and progress recompute on close.
struct ExerciseManagerView: View {
    @Environment(Store.self) var store
    @Environment(ToastCenter.self) var toast
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var renaming: ManageTarget?     // rename sheet
    @State private var merging: MergeTarget?       // merge sheet (pick which name wins)
    @State private var confirmDelete: ManageTarget?

    struct ManageTarget: Identifiable { let id = UUID(); let name: String }
    struct MergeTarget: Identifiable { let id = UUID(); let names: [String] }

    private var allNames: [String] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let names = store.allExerciseNames().map { $0.name }
        let filtered = q.isEmpty ? names : names.filter { $0.localizedCaseInsensitiveContains(q) }
        return filtered.sorted { store.sessionCount(forExercise: $0) > store.sessionCount(forExercise: $1) }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Text(t("st.manage_hint")).font(.ui(11)).foregroundColor(Theme.sub).lineSpacing(2)

                    let dupes = store.similarExerciseGroups()
                    if !dupes.isEmpty && search.isEmpty {
                        Card(accent: Theme.acc2) {
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.stars").font(.ui(12)).foregroundColor(Theme.acc2)
                                Lbl(text: t("st.dupes"), color: Theme.acc2)
                            }
                            .padding(.bottom, 8)
                            ForEach(dupes.indices, id: \.self) { i in
                                dupeRow(dupes[i])
                                if i != dupes.count - 1 { Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 4) }
                            }
                        }
                    }

                    Card {
                        Lbl(text: t("st.all_exercises")).padding(.bottom, 8)
                        InputField(placeholder: t("st.search_ex"), text: $search, keyboard: .default).padding(.bottom, 8)
                        if allNames.isEmpty {
                            Text(t("st.maxes_hint")).font(.ui(12)).foregroundColor(Theme.sub).padding(.vertical, 8)
                        }
                        ForEach(allNames, id: \.self) { name in
                            exerciseRow(name)
                            if name != allNames.last { Rectangle().fill(Theme.brd).frame(height: 1) }
                        }
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
        .sheet(item: $renaming) { tgt in
            RenameExerciseSheet(oldName: tgt.name) { newName in
                let merged = store.exerciseItems.contains { $0.name == newName }
                    || store.sessionCount(forExercise: newName) > 0
                store.renameExercise(from: tgt.name, to: newName)
                haptic(.success)
                toast.show(merged ? t("st.merged") : t("st.renamed"))
            }
        }
        .sheet(item: $merging) { tgt in
            MergeExerciseSheet(names: tgt.names) { keep, others in
                for o in others { store.renameExercise(from: o, to: keep) }
                haptic(.success)
                toast.show(t("st.merged"))
            }
        }
        .confirmationDialog(t("st.delete_q"), isPresented: Binding(
            get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
            titleVisibility: .visible) {
            if let tgt = confirmDelete {
                Button("\(t("st.delete")) \"\(tgt.name)\"", role: .destructive) {
                    store.deleteExercise(tgt.name); haptic(.warning); toast.show(t("st.deleted"))
                }
            }
            Button(t("cancel"), role: .cancel) {}
        } message: {
            if let tgt = confirmDelete {
                Text("\(store.sessionCount(forExercise: tgt.name)) \(t("st.sessions_affected"))")
            }
        }
    }

    private var header: some View {
        HStack {
            Text(t("st.manage").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            }
        }
        .padding(.top, 18)
    }

    /// A suggested-duplicate group: tap to open the merge picker.
    private func dupeRow(_ names: [String]) -> some View {
        Button { tap(); merging = MergeTarget(names: names) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(names.joined(separator: "  ·  ")).font(.ui(13, weight: .semibold))
                        .foregroundColor(Theme.txt).lineLimit(2).multilineTextAlignment(.leading)
                    Text("\(names.count) \(t("st.variants_similar"))").font(.ui(10)).foregroundColor(Theme.sub)
                }
                Spacer()
                Text(t("st.merge")).font(.head(10, .bold)).tracking(0.5).foregroundColor(Theme.bg)
                    .padding(.vertical, 6).padding(.horizontal, 12).background(Theme.acc2).clipShape(Capsule())
            }
            .padding(.vertical, 6)
        }.buttonStyle(PressableStyle())
    }

    private func exerciseRow(_ name: String) -> some View {
        let n = store.sessionCount(forExercise: name)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.ui(13, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                Text(n == 1 ? "1 \(t("st.session_one"))" : "\(n) \(t("st.sessions_n"))")
                    .font(.ui(10)).foregroundColor(Theme.sub)
            }
            Spacer()
            Button { tap(); renaming = ManageTarget(name: name) } label: {
                Image(systemName: "pencil").accessibilityLabel(t("a11y.edit")).font(.ui(13)).foregroundColor(Theme.blue).frame(width: 34, height: 34)
            }.buttonStyle(PressableStyle())
            Button { tap(); confirmDelete = ManageTarget(name: name) } label: {
                Image(systemName: "trash").accessibilityLabel(t("delete")).font(.ui(13)).foregroundColor(Theme.red.opacity(0.7)).frame(width: 34, height: 34)
            }.buttonStyle(PressableStyle())
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Rename / merge-into sheet
/// Rename an exercise. If the typed name already exists, the Store merges the two
/// histories — the sheet surfaces that with a live hint so it's never a surprise.
struct RenameExerciseSheet: View {
    @Environment(Store.self) var store
    @Environment(\.dismiss) private var dismiss
    let oldName: String
    var onConfirm: (String) -> Void
    @State private var text = ""

    private var willMerge: Bool {
        let n = text.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, n != oldName else { return false }
        return store.exerciseItems.contains { $0.name == n } || store.sessionCount(forExercise: n) > 0
            || store.plans.contains { $0.exercises.contains { $0.name == n } }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(t("st.rename").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget) }
                }
                .padding(.top, 18)
                Text("\(t("st.rename_from")) \"\(oldName)\"").font(.ui(12)).foregroundColor(Theme.sub)
                InputField(placeholder: oldName, text: $text, keyboard: .default)
                if willMerge {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.merge").font(.ui(11)).foregroundColor(Theme.acc2)
                        Text(t("st.merge_warn")).font(.ui(11)).foregroundColor(Theme.acc2)
                    }
                }
                BigButton(title: willMerge ? t("st.merge") : t("st.rename"),
                          color: willMerge ? Theme.acc2 : Theme.acc) {
                    let n = text.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    onConfirm(n); dismiss()
                }
                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
        .onAppear { text = oldName }
    }
}

// MARK: - Merge picker (choose which name to keep)
/// Pick which of several similar names survives; the rest are rewritten into it.
struct MergeExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let names: [String]
    var onMerge: (_ keep: String, _ others: [String]) -> Void
    @State private var keep: String = ""

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(t("st.merge").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget) }
                }
                .padding(.top, 18)
                Text(t("st.merge_pick")).font(.ui(12)).foregroundColor(Theme.sub)
                VStack(spacing: 0) {
                    ForEach(names, id: \.self) { n in
                        Button { tap(); keep = n } label: {
                            HStack {
                                Image(systemName: keep == n ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(keep == n ? Theme.acc : Theme.sub)
                                Text(n).font(.ui(14, weight: .semibold)).foregroundColor(Theme.txt)
                                Spacer()
                            }
                            .padding(.vertical, 12).padding(.horizontal, 4)
                        }.buttonStyle(PressableStyle())
                        if n != names.last { Rectangle().fill(Theme.brd).frame(height: 1) }
                    }
                }
                .padding(.horizontal, 10)
                .chrome()

                BigButton(title: t("st.merge_into"), color: Theme.acc2) {
                    guard !keep.isEmpty else { return }
                    onMerge(keep, names.filter { $0 != keep }); dismiss()
                }
                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
        .onAppear { keep = names.first ?? "" }
    }
}

// MARK: - A group of cards that folds away
/// A titled group of Stats cards. Open or closed is remembered per section, so the
/// page shows what the person looks at instead of one long column.
struct StatsSection<Content: View>: View {
    let title: String
    private let content: Content
    @AppStorage private var open: Bool

    init(id: String, title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        _open = AppStorage(wrappedValue: true, "stats.section.\(id)")
    }

    var body: some View {
        VStack(spacing: 11) {
            Button { tap(); open.toggle() } label: {
                HStack {
                    Text(title.uppercased()).font(.head(12, .semibold)).tracking(1).foregroundColor(Theme.txt)
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.ui(11, weight: .semibold))
                        .foregroundColor(Theme.sub)
                }
                .frame(minHeight: Theme.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? t("a11y.expanded") : t("a11y.collapsed"))
            if open { content }
        }
    }
}
