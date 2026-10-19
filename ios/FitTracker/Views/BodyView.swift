import SwiftUI
import Charts
import UniformTypeIdentifiers

struct BodyView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter

    @State private var weightInput = ""
    @State private var bfInput = ""
    @State private var measInputs: [String: String] = [:]
    @State private var stepsInput = ""
    @State private var measWindow: ChartWindow = .all
    // Manual sleep entry (shown when Health has no data for today)
    @State private var sleepHoursInput = ""
    @State private var sleepScoreInput = ""
    @State private var sleepHRVInput = ""
    @State private var sleepHRInput = ""
    @State private var showManualSleep = false
    /// The full night (stage chart, totals, last 7 nights) under the sleep tiles:
    /// closed by default, the tiles above already answer "how did I sleep".
    @State private var showSleepDetail = false
    // The day every entry card reads and writes. Defaults to today; stepping back
    // lets the user see and correct what Apple Health imported for a past day
    // (yesterday's steps, last week's sleep) instead of only ever seeing today.
    @State private var day = today()
    @State private var showHealthHistory = false
    @State private var editingGoal = false

    private var isToday: Bool { day == store.currentDay }

    var body: some View {
        // Analysis follows the selected day when that day carries its own numbers,
        // otherwise it falls back to the most recent record — so stepping back never
        // shows an empty page, just the values that were true then.
        let lw = store.dailyEntry(day)?.weight ?? store.lastWeight
        let bmi = store.bmi(lw)
        let cat = store.bmiComment(weight: lw)
        let bl = store.bodyEntry(onOrBefore: day)
        let navy = store.bfNavy(waist: bl?.waist, neck: bl?.neck, hip: bl?.hips)
        let bf = bl?.bfManual ?? navy
        let lean = bf.map { ((lw * (1 - $0 / 100)) * 10).rounded() / 10 }
        let fat = bf.map { ((lw * $0 / 100) * 10).rounded() / 10 }

        dayBar
        if store.prefs.healthKitEnabled { HealthStatusRow().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4) }
        bodyLogCard(bl: bl)
        sleepCard
        NightVitalsCard(day: day)
        stepsCard
        analysisCard(lw: lw, bmi: bmi, cat: cat, bl: bl, navy: navy, bf: bf, lean: lean, fat: fat)
        goalsCard(lw: lw)
        chartsSection
    }

    // MARK: Day selector — drives every entry card below it
    private var dayBar: some View {
        Card(accent: isToday ? Theme.acc : Theme.blue) {
            HStack(spacing: 10) {
                Button { tap(); shiftDay(-1) } label: {
                    Image(systemName: "chevron.left").accessibilityLabel(t("a11y.prev_day")).font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.txt).frame(width: 34, height: 34)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }.buttonStyle(PressableStyle()).hitArea((Theme.minTapTarget - 34) / 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prettyDay(day)).font(.head(14, .bold)).tracking(0.5)
                        .foregroundColor(isToday ? Theme.acc : Theme.blue)
                    Text(isToday ? t("body.today") : t("body.past_day"))
                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                }
                Spacer()

                // Forward is disabled on today: there is nothing to log in the future.
                Button { tap(); shiftDay(1) } label: {
                    Image(systemName: "chevron.right").accessibilityLabel(t("a11y.next_day")).font(.system(size: 13, weight: .bold))
                        .foregroundColor(isToday ? Theme.brd2 : Theme.txt).frame(width: 34, height: 34)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .hitArea((Theme.minTapTarget - 34) / 2)
                .disabled(isToday)

                Button { tap(); showHealthHistory = true } label: {
                    Image(systemName: "heart.text.square.fill").accessibilityLabel(t("hk.history")).font(.system(size: 15))
                        .foregroundColor(Color(hex: Theme.appleGreen))
                        .frame(width: 34, height: 34)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }.buttonStyle(PressableStyle()).hitArea((Theme.minTapTarget - 34) / 2)
            }
        }
        .sheet(isPresented: $showHealthHistory) { HealthHistoryView() }
        // Left open on today past midnight: today is the new day, so the morning
        // weigh-in lands on it and not on yesterday.
        .onChange(of: store.currentDay) { old, new in if day == old { day = new } }
        .onChange(of: day) {
            // Every card prefills from the store, so clear typed-but-unsaved text
            // when the day changes — otherwise yesterday's draft leaks into today.
            weightInput = ""; bfInput = ""; measInputs = [:]
            showManualSleep = false
            prefillSteps()
        }
    }

    private func shiftDay(_ delta: Int) {
        guard let d = isoFormatter.date(from: day),
              let next = Calendar.current.date(byAdding: .day, value: delta, to: d) else { return }
        let ds = isoFormatter.string(from: next)
        guard ds <= today() else { return }
        day = ds
    }


    // MARK: Sleep card — shows Health data when available, otherwise a manual entry form.
    private var sleepCard: some View {
        let e = store.dailyEntry(day)
        let hrv = (e?.hrvSleep ?? 0) > 0 ? e?.hrvSleep : nil
        let score = (e?.sleep ?? 0) > 0 ? e?.sleep : nil
        let sHR = (e?.sleepHR ?? 0) > 0 ? e?.sleepHR : nil
        let hrs = (e?.sleepHours ?? 0) > 0 ? e?.sleepHours : nil
        let hasHealthData = score != nil || hrv != nil || sHR != nil || hrs != nil

        return Card {
            HStack(spacing: 6) {
                Lbl(text: t("body.sleep"), color: Theme.acc2)
                Spacer()
                if hasHealthData {
                    Text(t("hk.from_health").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                }
                Button {
                    tap(); withAnimation(Theme.settle) { showManualSleep.toggle() }
                    if showManualSleep { prefillManualSleep(e) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showManualSleep ? "chevron.up" : "pencil")
                            .font(.system(size: 10, weight: .semibold))
                        if !hasHealthData {
                            Text(t("body.sleep_manual").uppercased()).font(.head(10, .semibold)).tracking(1)
                        }
                    }
                    .foregroundColor(Theme.acc2)
                }
            }
            .padding(.bottom, 12)

            // Health tiles (always shown when data exists)
            HStack(spacing: 9) {
                StatTile(label: t("home.sleep"), value: score.map { "\($0)" } ?? "—",
                         unit: score != nil ? "/100" : nil, valueColor: Theme.acc2,
                         note: score.flatMap { sleepBand(Double($0)) } ?? "—", info: .sleep)
                // Time actually asleep: the number the watch or band shows first.
                StatTile(label: t("sleep.slept"), value: hrs.map { fmtMinutes(Int(($0 * 60).rounded())) } ?? "—",
                         valueColor: Theme.blue, note: t("sleep.slept_note"), info: .sleep)
                StatTile(label: t("body.sleep_hr_short"), value: sHR.map { "\($0)" } ?? "—",
                         unit: sHR != nil ? "bpm" : nil, valueColor: Theme.red, note: t("hrv.sleep_note"), info: .sleepHR)
            }
            if let e, hrs != nil {
                Button {
                    tap(); withAnimation(Theme.settle) { showSleepDetail.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill").font(.system(size: 12))
                        Text(t(showSleepDetail ? "sleep.hide_all" : "sleep.show_all")).font(.head(12, .semibold))
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                            .rotationEffect(.degrees(showSleepDetail ? 180 : 0))
                    }
                    .foregroundColor(Theme.blue)
                    .padding(.vertical, 11).padding(.horizontal, 12)
                    .frame(minHeight: Theme.minTapTarget)
                    .chrome(Theme.radiusS, fill: Theme.blue.opacity(0.08), stroke: Theme.blue.opacity(0.3))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 12)
                if showSleepDetail {
                    SleepNightDetail(entry: e)
                        .padding(.top, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Manual entry form (always accessible via pencil button)
            if showManualSleep {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().background(Theme.brd).padding(.vertical, 6)
                    HStack(spacing: 10) {
                        sleepField(t("body.sleep_hours"), "7.5", $sleepHoursInput)
                        sleepField(t("home.sleep") + " (0-100)", "82", $sleepScoreInput, .numberPad)
                    }
                    HStack(spacing: 10) {
                        sleepField("HRV SDNN (ms)", "55", $sleepHRVInput)
                        sleepField(t("body.sleep_hr") + " (bpm)", "52", $sleepHRInput, .numberPad)
                    }
                    FilledButton(title: t("save")) { saveManualSleep() }
                }
                .padding(.top, 4)
            }
        }
    }

    private func sleepBand(_ score: Double) -> String? {
        store.infoScale(.sleep).map { t("band." + $0.bands[$0.bandIndex(of: score)].key) }
    }

    private func sleepField(_ label: String, _ ph: String, _ b: Binding<String>, _ kb: UIKeyboardType = .decimalPad) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.head(10, .semibold)).tracking(0.5).foregroundColor(Theme.sub)
            InputField(placeholder: ph, text: b, keyboard: kb)
        }
    }

    private func prefillManualSleep(_ e: DailyEntry?) {
        if let v = e?.sleepHours, v > 0 { sleepHoursInput = trimNum(v) }
        if let v = e?.sleep, v > 0 { sleepScoreInput = "\(v)" }
        if let v = e?.hrvSleep, v > 0 { sleepHRVInput = trimNum(v) }
        if let v = e?.sleepHR, v > 0 { sleepHRInput = "\(v)" }
    }

    private func saveManualSleep() {
        let hours = pf(sleepHoursInput) > 0 ? pf(sleepHoursInput) : nil
        let score = Int(sleepScoreInput)
        let hrv = pf(sleepHRVInput) > 0 ? pf(sleepHRVInput) : nil
        let sHR = Int(sleepHRInput)
        store.saveManualSleep(hours: hours, score: score, hrv: hrv, sleepHR: sHR, date: day)
        sleepHoursInput = ""; sleepScoreInput = ""; sleepHRVInput = ""; sleepHRInput = ""
        showManualSleep = false
        toast.show(t("save"))
    }

    // MARK: Steps (its own card). Imported from Apple Health, but the field stays
    // user-overridable: until the user types a value it shows/keeps the Health
    // import; once typed and saved, the manual value wins for the day.
    private var stepsCard: some View {
        Card {
            HStack(spacing: 6) {
                InfoLbl(text: t("lbl.steps"), info: .steps, color: Theme.acc2)
                Spacer()
                Text(t("hk.from_health").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 10)
            HStack(spacing: 10) {
                InputField(placeholder: "8000", text: $stepsInput)
                FilledButton(title: t("save")) {
                    guard let v = Int(stepsInput), v > 0 else { haptic(.error); toast.show(t("body.steps_invalid")); return }
                    store.saveSteps(v, date: day)
                    toast.show(t("save"))
                }
                .frame(width: 90)
            }
        }
        .onAppear { prefillSteps() }
        .onReceive(store.$daily) { _ in prefillSteps() }
    }

    /// Keep the field showing the selected day's Health steps. For today they refresh
    /// on every foreground sync and only climb; for a past day this is simply what
    /// Health imported, editable. Once the user has manually overridden the count
    /// (`stepsManual`), we stop touching the field so their value stays put.
    private func prefillSteps() {
        guard let e = store.dailyEntry(day), let v = e.steps, v > 0 else {
            if store.dailyEntry(day)?.steps == nil { stepsInput = "" }
            return
        }
        if e.stepsManual == true {
            if stepsInput.isEmpty { stepsInput = "\(v)" }
            return
        }
        let shown = Int(stepsInput)
        if shown == nil || shown != v { stepsInput = "\(v)" }
    }

    // MARK: Unified body log
    // Weight, body fat and the six circumference values belong to one check-in.
    // Keeping them together removes the repeated tile chrome and makes the save
    // action match the user's mental model: one body update for one day.
    private func bodyLogCard(bl: BodyEntry?) -> some View {
        let savedWeight = store.dailyEntry(day)?.weight
        let navy = store.bfNavy(waist: bl?.waist, neck: bl?.neck, hip: bl?.hips)

        return Card(accent: isToday ? Theme.acc : Theme.blue) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Lbl(text: t("body.log"), color: Theme.acc2)
                    Text(prettyDay(day)).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.acc2)
            }
            .padding(.bottom, 14)

            HStack(spacing: 10) {
                bodyLogField(label: t("home.weight"), unit: Units.wLabel,
                             value: savedWeight.map(dispW) ?? (Units.imperial ? "193" : "87,5"),
                             text: $weightInput, keyboard: .decimalPad)
                bodyLogField(label: t("body.fat"), unit: "%",
                             value: bl?.bfManual.map(trimNum) ?? navy.map(trimNum) ?? "—",
                             text: $bfInput, keyboard: .decimalPad)
            }
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(t("body.measures").uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                    Spacer()
                    Text(Units.lenLabel).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                }
                ForEach(measureFields) { measure in
                    bodyMeasureRow(measure, bl: bl)
                }
            }

            FilledButton(title: t("body.save_all")) {
                saveBodyLog()
            }
            .padding(.top, 14)
        }
    }

    private func bodyLogField(label: String, unit: String, value: String,
                              text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.head(10, .semibold)).tracking(1.1).foregroundColor(Theme.sub)
            HStack(spacing: 4) {
                TextField("", text: text, prompt: Text(value).foregroundColor(Theme.sub))
                    .keyboardType(keyboard)
                    .font(.num(21)).foregroundColor(Theme.txt)
                    .lineLimit(1).minimumScaleFactor(0.65)
                Text(unit).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
            }
            .padding(.horizontal, 11).frame(height: 45)
            .chrome(9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodyMeasureRow(_ measure: MeasureField, bl: BodyEntry?) -> some View {
        let current = bl?.value(for: measure.key)
        // Compared with the record before this one, not with whatever is newest.
        let previous = bl.flatMap { store.bodyEntry(before: $0.date) }?.value(for: measure.key)
        let delta = current.flatMap { currentValue in
            previous.map { ((currentValue - $0) * 10).rounded() / 10 }
        }

        return HStack(spacing: 10) {
            Circle().fill(Color(hex: measure.color)).frame(width: 8, height: 8)
            Text(measLabel(measure.key)).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.txt)
            if let current {
                VStack(alignment: .leading, spacing: 1) {
                    Text(dispLen(current)).font(.num(15)).foregroundColor(Theme.txt)
                    if let delta {
                        Text(delta == 0 ? t("body.stable") : "\(delta > 0 ? "+" : "")\(dispLen(delta))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(delta == 0 ? Theme.sub : (delta < 0 ? Theme.good : Theme.acc2))
                    }
                }
                .frame(width: 62, alignment: .leading)
            } else {
                Text("—").font(.num(15)).foregroundColor(Theme.sub).frame(width: 62, alignment: .leading)
            }
            TextField(current.map(dispLen) ?? "", text: binding(for: measure.key), prompt: Text(t("body.add_measure")))
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .medium)).foregroundColor(Theme.txt)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 10).frame(height: 38)
                .chrome(8)
        }
        .padding(.vertical, 3)
    }

    /// Save whatever was typed. Each field is checked on its own: the valid ones are
    /// saved and cleared, the others stay in place and are named, so a typo is
    /// never silently dropped behind a "saved" message.
    private func saveBodyLog() {
        var rejected: [String] = []
        var saved = false
        func typed(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

        if typed(weightInput) {
            let weight = Units.wIn(pf(weightInput))
            if Store.plausibleWeightKg.contains(weight) {
                store.saveCheckIn(weight: weight, sleep: nil, date: day)
                weightInput = ""; saved = true
            } else { rejected.append(t("home.weight")) }
        }
        if typed(bfInput) {
            let bodyFat = pf(bfInput)
            if Store.plausibleBodyFat.contains(bodyFat) {
                store.saveBodyFat(bodyFat, date: day)
                bfInput = ""; saved = true
            } else { rejected.append(t("home.fat")) }
        }
        var measurements: [String: Double] = [:]
        for measure in measureFields where typed(measInputs[measure.key] ?? "") {
            let value = Units.lenIn(pf(measInputs[measure.key] ?? ""))
            if Store.plausibleLengthCm.contains(value) {
                measurements[measure.key] = value
                measInputs[measure.key] = nil
            } else { rejected.append(measLabel(measure.key)) }
        }
        if !measurements.isEmpty {
            store.saveMeasurements(measurements, date: day)
            saved = true
        }

        if !rejected.isEmpty {
            haptic(.error)
            toast.show(t("body.rejected", rejected.joined(separator: ", ")), duration: ToastCenter.longDuration)
        } else {
            toast.show(t(saved ? "body.saved" : "body.nothing_to_save"))
        }
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
            HStack(spacing: 2) {
                Lbl(text: t("home.goals"), color: Theme.acc2)
                InfoButton(id: .goal, color: Theme.acc2)
                Spacer()
                Button { tap(); editingGoal = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "target").font(.system(size: 10, weight: .bold))
                        Text(t("goal.change").uppercased()).font(.head(10, .semibold)).tracking(0.8)
                    }
                    .foregroundColor(Theme.acc)
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(Theme.acc.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.acc.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(.bottom, 12)
            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text(t("home.weight")).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                        Spacer()
                        Text("\(dispW(lw)) → \(dispW(p.goalWeight)) \(Units.wLabel)").font(.num(13)).foregroundColor(Theme.acc)
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
        .sheet(isPresented: $editingGoal) { GoalEditorView() }
    }

    // MARK: Body analysis
    private func analysisCard(lw: Double, bmi: Double, cat: (text: String, color: Color),
                              bl: BodyEntry?, navy: Double?, bf: Double?,
                              lean: Double?, fat: Double?) -> some View {
        // Body-fat category (sex-specific) drives the BMI comment and the fat tile.
        let bfCat = bf.flatMap { store.scaleBand(.bodyfat, $0) }
        // FFMI is BMI's lean-mass counterpart: it needs the fat split, so it only
        // appears once a body-fat figure exists (manual or Navy-estimated). Built
        // from the SAME weight and body fat as the tiles above, so stepping to a
        // past day never shows two contradictory lean-mass numbers in one card.
        let ffmi = store.ffmi(weight: lw, bodyFat: bf)
        let ffmiCat = ffmi.flatMap { store.scaleBand(.ffmi, $0.normalized) }
        return Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Lbl(text: t("body.analysis"), color: Theme.acc2)
                    Text(t("body.composition")).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.sub)
                }
                Spacer()
                InfoButton(id: .bodyfat, color: Theme.acc2)
            }
            .padding(.bottom, 14)

            HStack(spacing: 16) {
                compositionRing(bodyFat: bf)
                VStack(alignment: .leading, spacing: 9) {
                    Text(t("body.composition").uppercased()).font(.head(10, .semibold)).tracking(1.2).foregroundColor(Theme.sub)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(dispW(lw)).font(.num(28)).foregroundColor(Theme.txt)
                        Text(Units.wLabel).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                    }
                    Text(bfCat.map { t($0.key) } ?? t("body.ffmi_need_bf"))
                        .font(.system(size: 12, weight: .medium)).foregroundColor(bf == nil ? Theme.sub : Theme.fat)
                    if let bf {
                        Bar(value: min(1, bf / 100), gradient: [Theme.fat, Theme.acc2], height: 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 16)

            let metrics: [(String, String, String?, Color, String, InfoTopic)] = [
                ("BMI", trimNum(bmi), nil, cat.color, cat.text.replacingOccurrences(of: "BMI \(trimNum(bmi)) · ", with: ""), .bmi),
                (t("body.fat"), bf.map(trimNum) ?? "—", bf == nil ? nil : "%", Theme.fat,
                 bfCat.map { t($0.key) } ?? t("body.ffmi_need_bf"), .bodyfat),
                (t("body.fat_mass"), fat.map(dispW) ?? "—", fat == nil ? nil : Units.wLabel, Theme.acc2, t("body.fat_mass_note"), .bodyfat),
                (t("body.lean_mass"), lean.map(dispW) ?? "—", lean == nil ? nil : Units.wLabel, Theme.blue, t("body.lean_mass_note"), .ffmi),
                (t("body.ffmi"), ffmi.map { trimNum($0.raw) } ?? "—", nil, ffmiCat?.color ?? Theme.sub,
                 ffmiCat.map { t($0.key) } ?? t("body.ffmi_need_bf"), .ffmi),
                (t("body.ffmi_norm"), ffmi.map { trimNum($0.normalized) } ?? "—", nil, ffmiCat?.color ?? Theme.sub,
                 "\(trimNum(Units.heightOut(store.prefs.height))) \(Units.heightLabel)", .ffmi)
            ]
            let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    compositionMetric(label: metric.0, value: metric.1, unit: metric.2,
                                      color: metric.3, note: metric.4, info: metric.5)
                }
            }

            if let navy {
                let hipPart = store.prefs.sex_ == "f" ? " · \(t("body.hips")) \(bl?.hips.map(dispLen) ?? "?")" : ""
                Text("Navy: \(trimNum(navy))% · \(t("body.neck")) \(bl?.neck.map(dispLen) ?? "?") · \(t("body.waist")) \(bl?.waist.map(dispLen) ?? "?")\(hipPart) \(Units.lenLabel)")
                    .font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 8)
            } else if store.prefs.sex_ == "f", bl?.waist != nil, bl?.neck != nil, bl?.hips == nil {
                // Women's Navy estimate needs the hip measurement — tell the user.
                Text(t("body.navy_need_hips")).font(.system(size: 10)).foregroundColor(Theme.acc2).padding(.top, 8)
            }
        }
    }

    private func compositionRing(bodyFat: Double?) -> some View {
        ZStack {
            Circle().stroke(Theme.c3, lineWidth: 9)
            if let bodyFat {
                Circle().trim(from: 0, to: min(1, max(0, bodyFat / 100)))
                    .stroke(Theme.fat, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(bodyFat.map(trimNum) ?? "—").font(.num(22)).foregroundColor(Theme.fat)
                Text("% \(t("body.fat"))").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
            }
        }
        .frame(width: 92, height: 92)
    }

    private func compositionMetric(label: String, value: String, unit: String?,
                                   color: Color, note: String, info: InfoTopic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label.uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                InfoButton(id: info, size: 16)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.num(23)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.55)
                if let unit { Text(unit).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub) }
            }
            Text(note).font(.system(size: 10, weight: .medium)).foregroundColor(Theme.sub)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(.vertical, 11).padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .chrome()
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { measInputs[key] ?? "" }, set: { measInputs[key] = $0 })
    }

    // MARK: Charts
    private var chartsSection: some View {
        let all = store.body.sorted { $0.date < $1.date }
        let bw = all.filter { measWindow.contains($0.date) }
        let days = bw.map { chartDay($0.date) }
        return Group {
            if all.count > 1 {
                ChartWindowPicker(window: $measWindow)
                Card {
                    InfoLbl(text: t("body.all_measures"), info: .measures).padding(.bottom, 8)
                    Chart {
                        ForEach(measureFields) { m in
                            ForEach(bw.filter { $0.value(for: m.key) != nil }) { e in
                                LineMark(x: .value("d", chartDay(e.date), unit: .day),
                                         y: .value("v", Units.lenOut(e.value(for: m.key) ?? 0)),
                                         series: .value("p", measLabel(m.key)))
                                    .foregroundStyle(Color(hex: m.color))
                                    .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .chartForegroundStyleScale(domain: measureFields.map { measLabel($0.key) },
                                               range: measureFields.map { Color(hex: $0.color) })
                    .chartLegend(position: .bottom, spacing: 8)
                    .dateAxes(days)
                    .frame(height: 205)
                }
                ForEach(measureFields.filter { f in bw.filter { $0.value(for: f.key) != nil }.count >= 2 }) { m in
                    Card {
                        Lbl(text: measLabel(m.key), color: Color(hex: m.color)).padding(.bottom, 8)
                        let pts = bw.filter { $0.value(for: m.key) != nil }
                        let range = chartRange(pts.map { Units.lenOut($0.value(for: m.key) ?? 0) })
                        Chart(pts) { e in
                            LineMark(x: .value("d", chartDay(e.date), unit: .day), y: .value("v", Units.lenOut(e.value(for: m.key) ?? 0)))
                                .foregroundStyle(Color(hex: m.color)).interpolationMethod(.catmullRom)
                            AreaMark(x: .value("d", chartDay(e.date), unit: .day), yStart: .value("v", range.lowerBound),
                                     yEnd: .value("v", Units.lenOut(e.value(for: m.key) ?? 0)))
                                .foregroundStyle(LinearGradient(colors: [Color(hex: m.color).opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                        }
                        .chartYScale(domain: range)
                        .dateAxes(days)
                        .frame(height: 120)
                    }
                }
            }
        }
    }
}
