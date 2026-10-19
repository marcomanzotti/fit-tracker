import Charts
import MapKit
import SwiftUI

// MARK: - What the device measured, editable
/// Every extra metric of a session, measured or typed. A typed value wins and
/// survives every sync; clearing it brings the device's back. Brand scores are
/// listed apart: each maker computes them its own way.
struct DeviceMetricsCard: View {
    @Binding var session: WorkoutSession
    @State private var added: [WorkoutMetric] = []

    private var rows: [WorkoutMetric] {
        let shown = session.shownMetrics
        return shown + added.filter { !shown.contains($0) }
    }

    var body: some View {
        let rows = rows
        let missing = WorkoutMetric.allCases.filter { !rows.contains($0) }
        Card {
            HStack {
                Lbl(text: t("dev.title"), color: Theme.acc2)
                Spacer()
                if let src = session.source {
                    Text(src).font(.ui(10, weight: .semibold)).foregroundColor(Theme.sub).lineLimit(1)
                }
            }
            .padding(.bottom, 6)
            Text(t(rows.isEmpty ? "dev.empty" : "dev.note")).font(.ui(11)).foregroundColor(Theme.sub)
                .padding(.bottom, 10)
            ForEach(rows.filter { !$0.isDeviceScore }) { MetricRow(session: $session, metric: $0) }
            let scores = rows.filter(\.isDeviceScore)
            if !scores.isEmpty {
                Lbl(text: t("dev.scores")).padding(.top, 12)
                Text(t("dev.scores_note")).font(.ui(10)).foregroundColor(Theme.sub).padding(.vertical, 4)
                ForEach(scores) { MetricRow(session: $session, metric: $0) }
            }
            if !missing.isEmpty {
                Menu {
                    ForEach(missing) { m in Button(t(m.labelKey)) { added.append(m) } }
                } label: {
                    Label(t("dev.add"), systemImage: "plus").font(.ui(12, weight: .semibold))
                        .foregroundColor(Theme.sub).padding(.vertical, 8).padding(.horizontal, 14)
                        .frame(minHeight: 38).chrome(9)
                }
                .padding(.top, 10)
            }
        }
    }
}

private struct MetricRow: View {
    @Binding var session: WorkoutSession
    let metric: WorkoutMetric
    @State private var text = ""
    /// What the box showed on opening: setting it is not an edit.
    @State private var initial: String?

    private var device: Double? { session.deviceMetric(metric) }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t(metric.labelKey)).font(.ui(13, weight: .medium)).foregroundColor(Theme.txt)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(provenance).font(.ui(10)).foregroundColor(text.isEmpty ? Theme.sub : Theme.acc2)
            }
            Spacer(minLength: 4)
            TextField("", text: $text, prompt: Text(device.map(metric.format) ?? "—").foregroundColor(Theme.sub))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .foregroundColor(Theme.txt).font(.ui(15, weight: .medium))
                .padding(.vertical, 8).padding(.horizontal, 10)
                .frame(width: 92).chrome(9)
            Text(metric.unit).font(.ui(10, weight: .semibold)).foregroundColor(Theme.sub)
                .frame(width: 54, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
            Button { tap(); text = "" } label: {
                Image(systemName: "arrow.uturn.backward").font(.ui(11, weight: .bold))
                    .foregroundColor(Theme.sub).frame(width: 28, height: Theme.minTapTarget)
            }
            .accessibilityLabel(t("dev.reset"))
            .opacity(text.isEmpty ? 0 : 1).disabled(text.isEmpty)
        }
        .onAppear {
            guard initial == nil else { return }
            let shown = session.metricOverrides?[metric.rawValue].map(metric.format) ?? ""
            initial = shown
            text = shown
        }
        .onChange(of: text) { _, new in
            guard new != initial else { return }
            initial = nil
            if new.isEmpty { session.setTyped(metric, nil); return }
            // Half-typed input ("1.", "-") keeps the last valid value.
            if let v = Double(new.replacingOccurrences(of: ",", with: ".")), v.isFinite { session.setTyped(metric, v) }
        }
    }

    private var provenance: String {
        if text.isEmpty { return device == nil ? t("dev.none") : t("dev.measured") }
        return device.map { "\(t("dev.typed")) · \(t("dev.device")) \(metric.format($0))" } ?? t("dev.typed")
    }
}

// MARK: - Series read from Health
/// Heart rate over time, time in the app's zones, the route and per-kilometre
/// splits, read from Health when the session is opened. Zones are the app's own,
/// from the profile, so they compare across devices.
struct WorkoutSeriesCard: View {
    let uuid: String
    let zones: [Store.HRZone]
    let paceIsSpeed: Bool
    @State private var series: WorkoutSeries?
    @State private var loaded = false

    private static let zoneColors = [Theme.blue, Theme.good, Theme.acc, Theme.acc2, Theme.red]

    var body: some View {
        Card {
            Lbl(text: t("series.title"), color: Theme.acc2).padding(.bottom, 10)
            if !loaded {
                ProgressView().tint(Theme.sub).frame(maxWidth: .infinity)
            } else if let s = series, !s.isEmpty {
                content(s)
            } else {
                Text(t("series.none")).font(.ui(11)).foregroundColor(Theme.sub)
            }
        }
        .task(id: uuid) {
            series = await HealthKitManager.shared.workoutSeries(uuid: uuid)
            loaded = true
        }
    }

    @ViewBuilder
    private func content(_ s: WorkoutSeries) -> some View {
        if !s.heartRate.isEmpty {
            heartRateChart(s)
            zoneBars(s).padding(.top, 12)
        }
        if s.route.count > 1 {
            RouteMap(route: s.route).padding(.top, 14)
        }
        if !s.splits.isEmpty { splitList(s.splits).padding(.top, 14) }
    }

    private func heartRateChart(_ s: WorkoutSeries) -> some View {
        let values = s.heartRate.map(\.value)
        let low = (values.min() ?? 60) - 5, high = (values.max() ?? 180) + 5
        return Chart(s.heartRate) { p in
            LineMark(x: .value("t", p.time), y: .value("bpm", p.value))
                .foregroundStyle(Theme.red).interpolationMethod(.monotone)
        }
        .chartYScale(domain: low...high)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.c3)
                AxisValueLabel(format: .dateTime.hour().minute()).foregroundStyle(Theme.sub)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Theme.c3)
                AxisValueLabel().foregroundStyle(Theme.sub)
            }
        }
        .frame(height: 140)
        .accessibilityLabel(t("series.hr"))
    }

    @ViewBuilder
    private func zoneBars(_ s: WorkoutSeries) -> some View {
        if zones.count == 5 {
            let bounds = zones.map(\.lower) + [zones[4].upper]
            let seconds = hrZoneSeconds(s.heartRate.map { ($0.time, $0.value) }, end: s.end, bounds: bounds)
            let total = max(1, seconds.reduce(0, +))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text("Z\(i + 1)").font(.num(11)).foregroundColor(Self.zoneColors[i]).frame(width: 22, alignment: .leading)
                        Bar(value: seconds[i] / total, gradient: [Self.zoneColors[i], Self.zoneColors[i]], height: 6)
                        Text(fmtClock(Int(seconds[i]))).font(.ui(10, weight: .medium)).foregroundColor(Theme.sub)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func splitList(_ splits: [WorkoutSplit]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Lbl(text: t("series.splits"))
            ForEach(splits) { split in
                HStack {
                    Text("\(split.index) km").font(.ui(12, weight: .medium)).foregroundColor(Theme.txt)
                        .frame(width: 52, alignment: .leading)
                    Text(paceIsSpeed ? "\(trimNum((3600 / split.seconds * 10).rounded() / 10)) km/h" : "\(fmtClock(Int(split.seconds))) /km")
                        .font(.num(13)).foregroundColor(Theme.acc)
                    Spacer()
                    if let hr = split.avgHR {
                        Text("\(Int(hr.rounded())) bpm").font(.ui(11)).foregroundColor(Theme.sub)
                    }
                }
            }
        }
    }
}

private struct RouteMap: View {
    let route: [(lat: Double, lon: Double)]

    var body: some View {
        let coordinates = route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        Map(initialPosition: .automatic) {
            MapPolyline(coordinates: coordinates).stroke(Theme.acc, lineWidth: 3)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .accessibilityLabel(t("series.route"))
    }
}

// MARK: - Session editor (a saved or a new session)
struct SessionEditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @State var session: WorkoutSession
    @State private var confirmDelete = false
    @State private var confirmClose = false
    @State private var addName = ""
    /// The session as it was opened, to know whether closing would lose edits.
    @State private var original: WorkoutSession?
    /// Opened from the day picker for a day not logged yet: Save adds it.
    private var isNew: Bool { !store.sessions.contains { $0.id == session.id } }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("wk.edit_session").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                            Text("\(session.planName) · \(fmtDM(session.date))").font(.ui(11)).foregroundColor(Theme.sub)
                        }
                        Spacer()
                        Button { if isDirty { confirmClose = true } else { dismiss() } } label: {
                            Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        }
                    }
                    .padding(.top, 18)

                    // A strength session is mostly its exercises: they come first.
                    if !session.sportType.isCardio { exercisesSection }

                    // Session-level internal load fields (TRIMP from duration + avg HR)
                    Card {
                        InfoLbl(text: t("load.title"), info: .load).padding(.bottom, 12)
                        HMSField(label: t("wk.duration"), seconds: durationBinding)
                        Spacer().frame(height: 12)
                        HStack(alignment: .top, spacing: 10) {
                            metricField(t("wk.avg_hr"), intBinding(\.avgHR), info: .trimp)
                            metricField(t("wk.max_hr"), intBinding(\.maxHRSes))
                        }
                        if session.sportType.isCardio {
                            Spacer().frame(height: 12)
                            HStack(alignment: .top, spacing: 10) {
                                metricField("\(t("wk.distance")) (\(Units.distLabel))", distanceBinding, keyboard: .decimalPad)
                                metricField("\(t("wk.elevation")) (m)", elevationBinding)
                            }
                            Spacer().frame(height: 12)
                            PaceField(session: session, manual: $session.paceManual)
                        }
                        if let v = store.trimp(session) {
                            HStack(spacing: 6) {
                                Text("TRIMP").font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                                Text("\(Int(v.rounded()))").font(.num(16)).foregroundColor(Theme.acc2)
                                Spacer()
                                Text(t("load.trimp_hint")).font(.ui(10)).foregroundColor(Theme.sub)
                            }
                            .padding(.top, 12)
                        }
                        // HRV (recovery) is imported automatically from Apple Health
                        // / the watch — readiness uses it without manual entry.
                    }

                    // Calories burned (estimate from data; manual override wins).
                    Card(accent: Theme.acc) {
                        HStack(spacing: 2) {
                            Lbl(text: t("wk.calories"), color: Theme.acc2)
                            InfoButton(id: .calories, color: Theme.acc2)
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(store.estimateCalories(session))").font(.num(26)).foregroundColor(Theme.acc)
                                Text("kcal").font(.ui(11, weight: .semibold)).foregroundColor(Theme.sub)
                            }
                        }
                        .padding(.bottom, 10)
                        metricField(t("wk.cal_override"), intBinding(\.caloriesManual), keyboard: .numberPad)
                        // The app's own formula next to a device's figure: the
                        // number to compare across devices.
                        if session.caloriesManual != nil {
                            Text("\(t("wk.cal_app")): \(store.estimateCalories(appEstimateSession)) kcal")
                                .font(.ui(10)).foregroundColor(Theme.sub).padding(.top, 6)
                        }
                    }

                    DeviceMetricsCard(session: $session)
                    if let uuid = session.healthUUID {
                        WorkoutSeriesCard(uuid: uuid, zones: store.hrZones(), paceIsSpeed: session.paceIsSpeed)
                    }

                    if session.sportType.isCardio && !session.exercises.isEmpty { exercisesSection }

                    BigButton(title: t("save")) {
                        store.saveSession(session); haptic(.success); dismiss()
                    }
                    // Repeat this workout today: same exercises and weights, fresh
                    // ids, no heart rate or Health provenance carried over. Hidden
                    // when the session already IS today's.
                    if session.date != today() {
                        Button {
                            tap()
                            // Commit any open edits first: the copy is built from the
                            // STORED session, so unsaved changes would be lost.
                            store.saveSession(session)
                            store.duplicateSession(session.id)
                            haptic(.success); toast.show(t("wk.repeated")); dismiss()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.trianglehead.2.clockwise").font(.ui(13, weight: .bold))
                                Text(t("wk.repeat_today")).font(.head(13, .semibold))
                            }
                            .foregroundColor(Theme.blue)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .chrome(fill: Theme.blue.opacity(0.08), stroke: Theme.blue)
                        }
                    }
                    // Bring a deleted strength plan back as a Train-page card, rebuilt
                    // from this session's exercises. Only shown when the original plan
                    // is gone and this is a strength session with exercises.
                    if !session.sportType.isCardio, !session.exercises.isEmpty,
                       store.plan(session.planId) == nil {
                        Button { tap(); store.recreatePlan(from: session); haptic(.success); toast.show(t("wk.day_created")); dismiss() } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "plus.square.on.square").font(.ui(13, weight: .bold))
                                Text(t("wk.recreate_plan")).font(.head(13, .semibold))
                            }
                            .foregroundColor(Theme.acc)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .chrome(fill: Theme.acc.opacity(0.08), stroke: Theme.acc)
                        }
                    }
                    if !isNew {
                        Button { tap(); confirmDelete = true } label: {
                            Text(t("wk.del_session")).font(.head(13, .semibold)).foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
        .interactiveDismissDisabled(isDirty)
        .onAppear { if original == nil { original = session } }
        .confirmationDialog(t("set.unsaved_q"), isPresented: $confirmClose, titleVisibility: .visible) {
            Button(t("save")) { store.saveSession(session); haptic(.success); dismiss() }
            Button(t("set.unsaved_discard"), role: .destructive) { dismiss() }
            Button(t("cancel"), role: .cancel) {}
        }
        .alert(t("wk.del_session"), isPresented: $confirmDelete) {
            Button(t("cancel"), role: .cancel) {}
            Button(t("delete"), role: .destructive) { deleteSession() }
        } message: { Text(t("confirm_delete")) }
    }

    private var isDirty: Bool { original != nil && session != original }

    @ViewBuilder private var exercisesSection: some View {
        ForEach($session.exercises) { $ex in
            exerciseEditor($ex)
        }
        Card {
            Lbl(text: t("wk.add_ex")).padding(.bottom, 8)
            HStack(spacing: 9) {
                TextField("", text: $addName, prompt: Text(t("wk.add_ex_ph")).foregroundColor(Theme.sub))
                    .font(.ui(15, weight: .medium)).foregroundColor(Theme.txt)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .chrome()
                Button { addExercise() } label: {
                    Image(systemName: "plus").accessibilityLabel(t("wk.add_ex")).font(.ui(16, weight: .bold))
                        .foregroundColor(Theme.bg).frame(width: 50, height: 48).background(Theme.acc)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func addExercise() {
        let name = addName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        tap()
        var ex = LoggedExercise(name: name, sets: [SetEntry()], notes: "", target: "")
        ex.isBodyweight = store.isBodyweightExercise(name) ? true : nil
        session.exercises.append(ex)
        addName = ""
    }

    private func removeExercise(_ id: UUID) {
        afterKeyboardDismissed { session.exercises.removeAll { $0.id == id } }
    }

    private func deleteSession() {
        if let removed = store.deleteSession(session.id) {
            toast.showUndo(t("wk.session_deleted")) { [store] in store.restoreSession(removed.session, at: removed.index) }
        }
        dismiss()
    }

    private func exerciseEditor(_ exB: Binding<LoggedExercise>) -> some View {
        let ex = exB.wrappedValue
        let bw = ex.bodyweight
        let scale = ex.effortScale
        let cur = ex.trainMethod
        let isGrouped = cur == .superset || cur == .giant
        let kind = ex.exKind
        return Card {
            // Name + kind badge + bodyweight toggle
            HStack(spacing: 8) {
                Text(ex.name).font(.ui(14, weight: .semibold)).foregroundColor(Theme.txt)
                if kind != .reps {
                    Badge(text: t(kind.labelKey), color: Theme.acc2, bg: Theme.acc2.opacity(0.14))
                }
                Spacer()
                if kind == .reps { BodyweightChip(isBodyweight: exB.isBodyweight) }
                Menu {
                    Button(role: .destructive) { removeExercise(ex.id) } label: {
                        Label(t("wk.remove_ex"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis").accessibilityLabel(t("a11y.more")).font(.ui(14, weight: .bold))
                        .foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                }
            }
            .padding(.bottom, 10)

            // A hold or a HIIT block is logged in its own units — seconds, or rounds
            // of work and rest — so the editor draws the same blocks the live workout
            // does. Drawing reps × weight here used to make a plank's seconds
            // uncorrectable once the session was saved.
            switch kind {
            case .timed:
                TimedSetRows(exercise: exB, bodyweight: bw)
                if bw {
                    Text(t("wk.bw_hint")).font(.ui(10)).foregroundColor(Theme.sub).padding(.top, 4)
                }
                GhostButton(title: t("wk.add_set")) { exB.wrappedValue.sets.append(SetEntry()) }
                    .padding(.top, 10)
            case .interval:
                // Pull the prescription from the plan so the readout stays "done /
                // target" instead of collapsing to n/n against the logged value.
                IntervalSetBlock(exercise: exB,
                                 prescribedRounds: store.plan(session.planId)?.exercises
                                     .first { $0.name == ex.name }?.rounds)
            case .reps:
                repsEditor(exB, bw: bw, scale: scale, cur: cur, isGrouped: isGrouped)
            }
        }
    }

    /// Classic reps × weight editing, with the method/superset and effort controls
    /// that only make sense for it.
    @ViewBuilder
    private func repsEditor(_ exB: Binding<LoggedExercise>, bw: Bool, scale: EffortMode?,
                            cur: TrainMethod, isGrouped: Bool) -> some View {
        Group {
            // Training method (superset / drop / rest-pause / giant) + group
            HStack(spacing: 10) {
                Text(t("wk.method").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Menu {
                    ForEach(TrainMethod.allCases, id: \.self) { m in
                        Button(m.label) { tap(); exB.wrappedValue.method = m == .normal ? nil : m.rawValue }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(cur.label).font(.ui(12, weight: .semibold)).foregroundColor(Theme.txt)
                        Image(systemName: "chevron.down").font(.ui(10)).foregroundColor(Theme.sub)
                    }
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .chrome(8)
                }
                Spacer()
                if isGrouped {
                    Text(t("pe.group").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                    Button { tap(); let g = (exB.wrappedValue.supersetGroup ?? 1); exB.wrappedValue.supersetGroup = max(1, g - 1) } label: {
                        Image(systemName: "minus").font(.ui(10, weight: .bold)).foregroundColor(Theme.txt)
                            .frame(width: 24, height: 24).background(Theme.c3).clipShape(Circle())
                    }.buttonStyle(PressableStyle())
                    Text("\(exB.wrappedValue.supersetGroup ?? 1)").font(.num(15)).frame(minWidth: 14)
                    Button { tap(); exB.wrappedValue.supersetGroup = (exB.wrappedValue.supersetGroup ?? 0) + 1 } label: {
                        Image(systemName: "plus").font(.ui(10, weight: .bold)).foregroundColor(Theme.txt)
                            .frame(width: 24, height: 24).background(Theme.c3).clipShape(Circle())
                    }.buttonStyle(PressableStyle())
                }
            }
            .padding(.bottom, 10)

            // Effort scale chooser
            EffortModeSelector(effortMode: exB.effortMode).padding(.bottom, 10)

            // Per-set reps × weight (+ effort when a scale is set)
            ForEach(exB.sets) { $set in
                let n = (exB.wrappedValue.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                HStack(spacing: 10) {
                    // The set label is its menu, as in the live workout.
                    Menu {
                        Button(role: .destructive) {
                            let id = set.id
                            afterKeyboardDismissed { exB.wrappedValue.sets.removeAll { $0.id == id } }
                        } label: { Label(t("a11y.remove"), systemImage: "trash") }
                    } label: {
                        Text("\(t("wk.set")) \(n)").font(.ui(11)).foregroundColor(Theme.sub)
                            .frame(width: 54, height: Theme.minTapTarget, alignment: .leading)
                    }
                    SmallNumField(text: $set.reps, placeholder: t("wk.reps"))
                    Text("×").foregroundColor(Theme.sub)
                    SmallNumField(text: $set.weight, placeholder: bw ? "+kg" : "kg")
                    if let scale { EffortField(scale: scale, value: $set.effortVal) }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            if bw {
                Text(t("wk.bw_hint")).font(.ui(10)).foregroundColor(Theme.sub).padding(.top, 4)
            }
            GhostButton(title: t("wk.add_set")) { exB.wrappedValue.sets.append(SetEntry()) }
                .padding(.top, 10)
        }
    }

    private func metricField(_ label: String, _ binding: Binding<String>, info: InfoTopic? = nil,
                             keyboard: UIKeyboardType = .numberPad) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(label, info: info)
            InputField(placeholder: "—", text: binding, keyboard: keyboard)
        }
    }
    /// Total-seconds binding for the H/M/S field, migrating any legacy
    /// whole-minute value into the new seconds field on first edit.
    private var durationBinding: Binding<Int?> {
        Binding(get: { session.durationSeconds },
                set: { session.durationSec = $0; session.durationMin = nil })
    }
    private func intBinding(_ kp: WritableKeyPath<WorkoutSession, Int?>) -> Binding<String> {
        Binding(get: { session[keyPath: kp].map(String.init) ?? "" },
                set: { session[keyPath: kp] = Int($0) })
    }
    /// Distance binding that displays/parses in the user's distance unit (km stored).
    private var distanceBinding: Binding<String> {
        Binding(get: { session.distanceKm.map(dispDist) ?? "" },
                set: { session.distanceKm = $0.isEmpty ? nil : Units.distIn(pf($0)) })
    }
    private var elevationBinding: Binding<String> {
        Binding(get: { session.elevationM.map { trimNum($0.rounded()) } ?? "" },
                set: { session.elevationM = $0.isEmpty ? nil : pf($0) })
    }
    /// The session as the app's own formula sees it: no device calories.
    private var appEstimateSession: WorkoutSession {
        var s = session
        s.caloriesManual = nil
        return s
    }
}
