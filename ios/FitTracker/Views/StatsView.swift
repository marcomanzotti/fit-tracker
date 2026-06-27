import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: Store

    @State private var statsTab = "overview"
    @State private var selEx = ""          // selected movement family (base)
    @State private var exSearch = ""
    @State private var browseCat: String?  // expanded muscle group in the browser
    @State private var editingFam: FamilyEdit?
    @State private var selVariant: String?  // chosen variant within the selected family
    @State private var exSortKey: ExSortKey = .recent
    @State private var exSortAsc = false
    @State private var showManage = false

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
    // Every daily-derived metric uses MetricChartCard: it defaults to a weekly
    // average over the last 3 months (so the x-axis never crowds) and carries an
    // expand button → a larger, horizontally-scrollable view with a
    // day/week/month/year toggle.
    private var overview: some View {
        let ws = store.sortedDaily
        let withW = ws.filter { $0.weight != nil }
        let bf = store.currentBF
        return Group {
            MetricChartCard(title: t("home.weight"), color: Theme.acc) {
                $0.weight.map { Units.wOut($0) }
            }
            MetricChartCard(title: t("st.sleep"), info: "sleep", color: Theme.blue, yDomain: 0...100) {
                $0.sleep.map(Double.init)
            }
            MetricChartCard(title: t("st.steps_time"), color: Color(hex: "ff9500"), kind: .bar) {
                $0.steps.map(Double.init)
            }
            MetricChartCard(title: t("st.vo2_time"), color: Theme.good) {
                $0.vo2max
            }
            MetricChartCard(title: t("st.bmi_time"), color: Color(hex: "b08fff")) {
                e in e.weight.map { store.bmi($0) }
            }
            if withW.count > 1 {
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
                                    .foregroundStyle(Theme.fat).interpolationMethod(.catmullRom)
                            }
                        }
                        .chartForegroundStyleScale(domain: [t("st.lean"), t("st.fat")], range: [Theme.blue, Theme.fat])
                        .chartLegend(position: .bottom, spacing: 8)
                        .chartYScale(domain: .automatic(includesZero: false)).styledAxes().frame(height: 155)
                    }
                }
            }
            if withW.count < 2 {
                Card { EmptyBox(title: t("st.no_data"), text: t("st.charts_hint")) }
            }
            MuscleVolumeCard()
            VitalsTrendCard()
            FitnessCard()
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
                            Image(systemName: "slider.horizontal.3").font(.system(size: 11, weight: .bold))
                            Text(t("st.manage")).font(.head(10, .semibold)).tracking(0.5)
                        }
                        .foregroundColor(Theme.sub)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Theme.c2).clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.brd, lineWidth: 1))
                    }.buttonStyle(.plain)
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
                let data = selVariant.map { store.exerciseHistory($0) } ?? store.exerciseHistory(family: selEx)
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
            Text(selEx).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.acc).lineLimit(1)
            Spacer()
            Button { tap(); editingFam = FamilyEdit(base: selEx) } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 12)).foregroundColor(Theme.sub).frame(width: 28, height: 28)
            }.buttonStyle(.plain)
            Button { tap(); selEx = ""; selVariant = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(Theme.sub)
            }.buttonStyle(.plain)
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
                Text(t("food.sort").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                ForEach(ExSortKey.allCases, id: \.self) { key in
                    let active = exSortKey == key
                    Button {
                        tap()
                        if exSortKey == key { exSortAsc.toggle() } else { exSortKey = key; exSortAsc = false }
                    } label: {
                        HStack(spacing: 3) {
                            Text(key.label).font(.head(10, .semibold)).tracking(0.5)
                            if active { Image(systemName: exSortAsc ? "arrow.up" : "arrow.down").font(.system(size: 9, weight: .bold)) }
                        }
                        .foregroundColor(active ? Theme.bg : Theme.sub)
                        .padding(.vertical, 5).padding(.horizontal, 9)
                        .background(active ? Theme.acc : Theme.c2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(active ? Theme.acc : Theme.brd, lineWidth: 1))
                    }.buttonStyle(.plain)
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
        }.buttonStyle(.plain)
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
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
    }

    private func browseByCategory(_ fams: [Store.ExFamily]) -> some View {
        let byCat = Dictionary(grouping: fams) { $0.category }
        let cats = MuscleGroup.allCases.filter { byCat[$0.rawValue]?.isEmpty == false }
        return VStack(spacing: 8) {
            if fams.isEmpty {
                Text(t("st.maxes_hint")).font(.system(size: 12)).foregroundColor(Theme.sub).padding(.vertical, 8)
            }
            ForEach(cats) { mg in
                let group = byCat[mg.rawValue] ?? []
                VStack(spacing: 0) {
                    Button { tap(); browseCat = (browseCat == mg.rawValue) ? nil : mg.rawValue } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill").font(.system(size: 8)).foregroundColor(Color(hex: mg.color))
                            Text(t(mg.labelKey).uppercased()).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.txt)
                            Text("\(group.count)").font(.system(size: 10)).foregroundColor(Theme.sub)
                            Spacer()
                            Image(systemName: browseCat == mg.rawValue ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11)).foregroundColor(Theme.sub)
                        }
                        .padding(.vertical, 11).padding(.horizontal, 12)
                    }.buttonStyle(.plain)
                    if browseCat == mg.rawValue {
                        ForEach(group) { f in
                            Rectangle().fill(Theme.brd).frame(height: 1)
                            familyRow(f)
                        }
                    }
                }
                .background(Theme.c2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
        }
    }

    private func familyRow(_ f: Store.ExFamily) -> some View {
        let mg = MuscleGroup(rawValue: f.category) ?? .other
        return Button { tap(); selEx = f.base; selVariant = nil; exSearch = "" } label: {
            HStack {
                Circle().fill(Color(hex: mg.color)).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.base).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                    if f.names.count > 1 {
                        Text("\(f.names.count) \(t("st.variants"))").font(.system(size: 10)).foregroundColor(Theme.sub)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(Theme.sub)
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
        }.buttonStyle(.plain)
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

// MARK: - Exercise family editor
/// Identifiable wrapper so a family base string can drive `.sheet(item:)`.
struct FamilyEdit: Identifiable { let id = UUID(); let base: String }

/// Reassign each variant in a movement family: change its muscle group, or retype
/// its family so it merges with another movement (or splits into its own). This is
/// the manual control behind the "explicit base + variant" model.
struct ExerciseFamilyEditor: View {
    @EnvironmentObject var store: Store
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
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)
                    Text(t("st.family_hint")).font(.system(size: 11)).foregroundColor(Theme.sub).lineSpacing(2)

                    ForEach($rows) { $row in
                        Card {
                            Text(row.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                                .padding(.bottom, 10)
                            FieldLabel(t("st.family"))
                            InputField(placeholder: base, text: $row.base, keyboard: .default).padding(.bottom, 10)
                            HStack {
                                Text(t("st.muscle").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                                Spacer()
                                Menu {
                                    ForEach(MuscleGroup.allCases) { mg in
                                        Button(t(mg.labelKey)) { row.category = mg.rawValue }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(t("mg." + row.category)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.txt)
                                        Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(Theme.sub)
                                    }
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
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
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
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
                    Text(t("st.manage_hint")).font(.system(size: 11)).foregroundColor(Theme.sub).lineSpacing(2)

                    let dupes = store.similarExerciseGroups()
                    if !dupes.isEmpty && search.isEmpty {
                        Card(accent: Theme.acc2) {
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.stars").font(.system(size: 12)).foregroundColor(Theme.acc2)
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
                            Text(t("st.maxes_hint")).font(.system(size: 12)).foregroundColor(Theme.sub).padding(.vertical, 8)
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
            Button { tap(); dismiss() } label: {
                Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 18)
    }

    /// A suggested-duplicate group: tap to open the merge picker.
    private func dupeRow(_ names: [String]) -> some View {
        Button { tap(); merging = MergeTarget(names: names) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(names.joined(separator: "  ·  ")).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.txt).lineLimit(2).multilineTextAlignment(.leading)
                    Text("\(names.count) \(t("st.variants_similar"))").font(.system(size: 10)).foregroundColor(Theme.sub)
                }
                Spacer()
                Text(t("st.merge")).font(.head(10, .bold)).tracking(0.5).foregroundColor(Theme.bg)
                    .padding(.vertical, 6).padding(.horizontal, 12).background(Theme.acc2).clipShape(Capsule())
            }
            .padding(.vertical, 6)
        }.buttonStyle(.plain)
    }

    private func exerciseRow(_ name: String) -> some View {
        let n = store.sessionCount(forExercise: name)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                Text(n == 1 ? "1 \(t("st.session_one"))" : "\(n) \(t("st.sessions_n"))")
                    .font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            Spacer()
            Button { tap(); renaming = ManageTarget(name: name) } label: {
                Image(systemName: "pencil").font(.system(size: 13)).foregroundColor(Theme.blue).frame(width: 34, height: 34)
            }.buttonStyle(.plain)
            Button { tap(); confirmDelete = ManageTarget(name: name) } label: {
                Image(systemName: "trash").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.7)).frame(width: 34, height: 34)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Rename / merge-into sheet
/// Rename an exercise. If the typed name already exists, the Store merges the two
/// histories — the sheet surfaces that with a live hint so it's never a surprise.
struct RenameExerciseSheet: View {
    @EnvironmentObject var store: Store
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
                    Button { tap(); dismiss() } label: { Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34) }
                }
                .padding(.top, 18)
                Text("\(t("st.rename_from")) \"\(oldName)\"").font(.system(size: 12)).foregroundColor(Theme.sub)
                InputField(placeholder: oldName, text: $text, keyboard: .default)
                if willMerge {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.merge").font(.system(size: 11)).foregroundColor(Theme.acc2)
                        Text(t("st.merge_warn")).font(.system(size: 11)).foregroundColor(Theme.acc2)
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
                    Button { tap(); dismiss() } label: { Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34) }
                }
                .padding(.top, 18)
                Text(t("st.merge_pick")).font(.system(size: 12)).foregroundColor(Theme.sub)
                VStack(spacing: 0) {
                    ForEach(names, id: \.self) { n in
                        Button { tap(); keep = n } label: {
                            HStack {
                                Image(systemName: keep == n ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(keep == n ? Theme.acc : Theme.sub)
                                Text(n).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                                Spacer()
                            }
                            .padding(.vertical, 12).padding(.horizontal, 4)
                        }.buttonStyle(.plain)
                        if n != names.last { Rectangle().fill(Theme.brd).frame(height: 1) }
                    }
                }
                .padding(.horizontal, 10)
                .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))

                BigButton(title: t("st.merge_into"), color: Theme.acc2) {
                    guard !keep.isEmpty else { return }
                    onMerge(keep, names.filter { $0 != keep }); dismiss()
                }
                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
        .onAppear { keep = names.first ?? "" }
    }
}
