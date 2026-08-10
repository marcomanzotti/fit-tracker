import SwiftUI
import Charts
import UniformTypeIdentifiers

struct BodyView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter

    @State private var weightInput = ""
    @State private var bfInput = ""
    @State private var measInputs: [String: String] = [:]
    @State private var shareURL: IdentURL?
    @State private var importing = false
    @State private var stepsInput = ""
    // Manual sleep entry (shown when Health has no data for today)
    @State private var sleepHoursInput = ""
    @State private var sleepScoreInput = ""
    @State private var sleepHRVInput = ""
    @State private var sleepHRInput = ""
    @State private var showManualSleep = false
    // The day every entry card reads and writes. Defaults to today; stepping back
    // lets the user see and correct what Apple Health imported for a past day
    // (yesterday's steps, last week's sleep) instead of only ever seeing today.
    @State private var day = today()
    @State private var showHealthHistory = false

    private var isToday: Bool { day == today() }

    var body: some View {
        // Analysis follows the selected day when that day carries its own numbers,
        // otherwise it falls back to the most recent record — so stepping back never
        // shows an empty page, just the values that were true then.
        let lw = store.dailyEntry(day)?.weight ?? store.lastWeight
        let bmi = store.bmi(lw)
        let cat = store.bmiComment(weight: lw)
        let bl = store.body.first { $0.date == day } ?? store.bodyLatest
        let navy = store.bfNavy(waist: bl?.waist, neck: bl?.neck, hip: bl?.hips)
        let bf = bl?.bfManual ?? navy
        let lean = bf.map { ((lw * (1 - $0 / 100)) * 10).rounded() / 10 }
        let fat = bf.map { ((lw * $0 / 100) * 10).rounded() / 10 }

        dayBar
        checkInCard
        sleepCard
        stepsCard
        analysisCard(lw: lw, bmi: bmi, cat: cat, bl: bl, navy: navy, bf: bf, lean: lean, fat: fat)
        measurementsCard(bl: bl)
        chartsSection
        backupCard
    }

    // MARK: Day selector — drives every entry card below it
    private var dayBar: some View {
        Card(accent: isToday ? Theme.acc : Theme.blue) {
            HStack(spacing: 10) {
                Button { tap(); shiftDay(-1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.txt).frame(width: 34, height: 34)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }.buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prettyDay).font(.head(14, .bold)).tracking(0.5)
                        .foregroundColor(isToday ? Theme.acc : Theme.blue)
                    Text(isToday ? t("body.today") : t("body.past_day"))
                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                }
                Spacer()

                // Forward is disabled on today: there is nothing to log in the future.
                Button { tap(); shiftDay(1) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                        .foregroundColor(isToday ? Theme.mut : Theme.txt).frame(width: 34, height: 34)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isToday)

                Button { tap(); showHealthHistory = true } label: {
                    Image(systemName: "heart.text.square.fill").font(.system(size: 15))
                        .foregroundColor(Color(hex: Theme.appleGreen))
                        .frame(width: 34, height: 34)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showHealthHistory) { HealthHistoryView() }
        .onChange(of: day) { _ in
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

    private var prettyDay: String {
        guard let d = isoFormatter.date(from: day) else { return day }
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "en" ? "en_US" : "it_IT")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: d).capitalized
    }

    // MARK: Sleep card — shows Health data when available, otherwise a manual entry form.
    private var sleepCard: some View {
        let e = store.dailyEntry(day)
        let hrv = (e?.hrvSDNN ?? 0) > 0 ? e?.hrvSDNN : nil
        let score = (e?.sleep ?? 0) > 0 ? e?.sleep : nil
        let sHR = (e?.sleepHR ?? 0) > 0 ? e?.sleepHR : nil
        let hrs = (e?.sleepHours ?? 0) > 0 ? e?.sleepHours : nil
        let hasHealthData = score != nil || hrv != nil || sHR != nil || hrs != nil

        return Card {
            HStack(spacing: 6) {
                Lbl(text: t("body.sleep"), color: Theme.acc2)
                Spacer()
                if hasHealthData {
                    Text(t("hk.from_health").uppercased()).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
                }
                Button {
                    tap(); showManualSleep.toggle()
                    if showManualSleep { prefillManualSleep(e) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showManualSleep ? "chevron.up" : "pencil")
                            .font(.system(size: 10, weight: .semibold))
                        if !hasHealthData {
                            Text(t("body.sleep_manual").uppercased()).font(.head(8, .semibold)).tracking(1)
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
                         note: hrs.map { "\(trimNum($0)) h" } ?? "—", info: "sleep")
                StatTile(label: "HRV", value: hrv.map(trimNum) ?? "—", unit: hrv != nil ? "ms" : nil,
                         valueColor: Theme.blue, note: t("st.hrv_sdnn"), info: "hrv")
                StatTile(label: t("body.sleep_hr"), value: sHR.map { "\($0)" } ?? "—",
                         unit: sHR != nil ? "bpm" : nil, valueColor: Theme.red, note: t("hk.cat.sleepHR"))
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

    private func sleepField(_ label: String, _ ph: String, _ b: Binding<String>, _ kb: UIKeyboardType = .decimalPad) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.head(9, .semibold)).tracking(0.5).foregroundColor(Theme.sub)
            InputField(placeholder: ph, text: b, keyboard: kb)
        }
    }

    private func prefillManualSleep(_ e: DailyEntry?) {
        if let v = e?.sleepHours, v > 0 { sleepHoursInput = trimNum(v) }
        if let v = e?.sleep, v > 0 { sleepScoreInput = "\(v)" }
        if let v = e?.hrvSDNN, v > 0 { sleepHRVInput = trimNum(v) }
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
                Lbl(text: t("lbl.steps"), color: Theme.acc2)
                Spacer()
                Text(t("hk.from_health").uppercased()).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 10)
            HStack(spacing: 10) {
                InputField(placeholder: "8000", text: $stepsInput)
                FilledButton(title: t("save")) {
                    guard let v = Int(stepsInput), v > 0 else { return }
                    store.saveDailyExtras(date: day, steps: v)
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

    // MARK: Check-in
    // Body weight only — sleep score is imported from Apple Health and shown on
    // the Sleep card above, so the daily check-in stays a single quick field.
    private var checkInCard: some View {
        let saved = store.dailyEntry(day)?.weight
        return Card {
            Lbl(text: "\(t("home.checkin")) · \(day)", color: Theme.acc2).padding(.bottom, 10)
            field("\(t("home.weight")) (\(Units.wLabel.uppercased()))",
                  saved.map(dispW) ?? (Units.imperial ? "193" : "87,5"), $weightInput)
                .padding(.bottom, 12)
            FilledButton(title: t("home.save_checkin")) {
                let w = Units.wIn(pf(weightInput))
                guard w >= 30 && w <= 250 else { return }
                store.saveCheckIn(weight: w, sleep: nil, date: day)
                weightInput = ""; toast.show(t("home.checkin_saved"))
            }
        }
    }

    // MARK: Body analysis
    private func analysisCard(lw: Double, bmi: Double, cat: (text: String, color: Color),
                              bl: BodyEntry?, navy: Double?, bf: Double?,
                              lean: Double?, fat: Double?) -> some View {
        // Body-fat category (sex-specific) drives the BMI comment and the fat tile.
        let bfCat = bf.map { store.bfCategory($0, sex: store.prefs.sex_) }
        // FFMI is BMI's lean-mass counterpart: it needs the fat split, so it only
        // appears once a body-fat figure exists (manual or Navy-estimated). Built
        // from the SAME weight and body fat as the tiles above, so stepping to a
        // past day never shows two contradictory lean-mass numbers in one card.
        let ffmi = store.ffmi(weight: lw, bodyFat: bf)
        let ffmiCat = ffmi.map { store.ffmiCategory($0.normalized, sex: store.prefs.sex_) }
        return Card {
            Lbl(text: t("body.analysis"), color: Theme.acc2).padding(.bottom, 12)
            HStack(spacing: 9) {
                StatTile(label: "BMI", value: trimNum(bmi), valueColor: cat.color,
                         note: cat.text.replacingOccurrences(of: "BMI \(trimNum(bmi)) · ", with: ""), info: "bmi")
                StatTile(label: t("body.fat"), value: bf.map(trimNum) ?? "—", unit: bf != nil ? "%" : nil,
                         valueColor: Theme.fat,
                         note: bfCat.map { t($0.key) } ?? "\(t("body.goal")) \(trimNum(store.prefs.goalBF))%", info: "bodyfat")
                StatTile(label: t("body.lean"), value: lean.map(dispW) ?? "—", unit: lean != nil ? Units.wLabel : nil,
                         valueColor: Theme.blue, note: fat != nil ? "\(dispW(fat!))\(Units.wLabel) \(t("body.fat"))" : "—", info: "bodyfat")
            }
            .padding(.bottom, 9)

            // Second row: the lean-mass side of the same picture.
            HStack(spacing: 9) {
                StatTile(label: t("body.ffmi"), value: ffmi.map { trimNum($0.raw) } ?? "—",
                         valueColor: ffmiCat?.color ?? Theme.sub,
                         note: ffmiCat.map { t($0.key) } ?? t("body.ffmi_need_bf"), info: "ffmi")
                StatTile(label: t("body.ffmi_norm"), value: ffmi.map { trimNum($0.normalized) } ?? "—",
                         valueColor: ffmiCat?.color ?? Theme.sub,
                         note: "\(trimNum(Units.heightOut(store.prefs.height))) \(Units.heightLabel)", info: "ffmi")
                StatTile(label: t("st.lean"), value: ffmi.map { dispW($0.lean) } ?? "—",
                         unit: ffmi != nil ? Units.wLabel : nil, valueColor: Theme.blue,
                         note: t("body.lean"), info: "ffmi")
            }
            .padding(.bottom, 12)

            if let bf, let lean, let fat {
                VStack(spacing: 6) {
                    HStack {
                        Text("\(t("body.fat")) \(dispW(fat)) \(Units.wLabel)").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                        Spacer()
                        Text("\(t("body.lean")) \(dispW(lean)) \(Units.wLabel)").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                    }
                    Bar(value: min(1, bf / 100), gradient: [Theme.fat, Theme.fat.opacity(0.6)], height: 9)
                }
                .padding(.bottom, 12)
            }

            Text(t("body.fat_input").uppercased()).font(.head(10, .semibold)).tracking(1)
                .foregroundColor(Theme.sub).padding(.bottom, 8)
            HStack(spacing: 10) {
                InputField(placeholder: navy != nil ? "Navy: \(trimNum(navy!))%" : "18,5", text: $bfInput)
                FilledButton(title: t("save")) {
                    let v = pf(bfInput)
                    guard v >= 1 && v <= 60 else { return }
                    store.saveBodyFat(v, date: day); bfInput = ""; toast.show(t("body.fat_saved"))
                }
                .frame(width: 90)
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

    // MARK: Measurements
    private func measurementsCard(bl: BodyEntry?) -> some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return Card {
            Lbl(text: t("body.measures"), color: Theme.acc2).padding(.bottom, 10)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(measureFields) { m in
                    measureTile(m, bl: bl)
                }
            }
            .padding(.bottom, 10)
            FilledButton(title: t("body.save_measures")) {
                var vals: [String: Double] = [:]
                for m in measureFields {
                    let v = Units.lenIn(pf(measInputs[m.key] ?? ""))   // input → cm
                    if v > 0 { vals[m.key] = v }
                }
                guard !vals.isEmpty else { return }
                store.saveMeasurements(vals, date: day)
                measInputs = [:]
                toast.show(t("body.measures_saved"))
            }
        }
    }

    private func measureTile(_ m: MeasureField, bl: BodyEntry?) -> some View {
        let cur = bl?.value(for: m.key)
        let prev = store.bodyPrev?.value(for: m.key)
        let diff: Double? = (cur != nil && prev != nil) ? ((cur! - prev!) * 10).rounded() / 10 : nil
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(measLabel(m.key).uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                Spacer()
                if cur != nil { Text(Units.lenLabel).font(.system(size: 10)).foregroundColor(Theme.sub) }
            }
            .padding(.bottom, 8)
            TextField("", text: binding(for: m.key),
                      prompt: Text(cur.map(dispLen) ?? "–").foregroundColor(Theme.sub))
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .medium)).foregroundColor(Theme.txt)
                .padding(.vertical, 9).padding(.horizontal, 11)
                .background(Theme.c1).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            if let cur {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(dispLen(cur)).font(.num(26)).foregroundColor(Theme.txt)
                    Text(Units.lenLabel).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
                .padding(.top, 7)
                if let diff {
                    Text(diff == 0 ? t("body.stable") : "\(diff > 0 ? "+" : "")\(dispLen(diff)) \(Units.lenLabel)")
                        .font(.num(11)).foregroundColor(diff == 0 ? Theme.sub : (diff < 0 ? Theme.good : Theme.acc2))
                        .padding(.top, 4)
                }
            } else {
                Text(t("body.no_data")).font(.system(size: 11)).foregroundColor(Theme.sub).padding(.top, 8)
            }
        }
        .padding(.vertical, 13).padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { measInputs[key] ?? "" }, set: { measInputs[key] = $0 })
    }

    // MARK: Charts
    private var chartsSection: some View {
        let bw = store.body.sorted { $0.date < $1.date }
        return Group {
            if bw.count > 1 {
                Card {
                    Lbl(text: t("body.all_measures")).padding(.bottom, 8)
                    Chart {
                        ForEach(measureFields) { m in
                            ForEach(bw.filter { $0.value(for: m.key) != nil }) { e in
                                LineMark(x: .value("g", fmtShort(e.date)),
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
                    .styledAxes()
                    .frame(height: 205)
                }
                ForEach(measureFields.filter { f in bw.filter { $0.value(for: f.key) != nil }.count >= 2 }) { m in
                    Card {
                        Lbl(text: measLabel(m.key), color: Color(hex: m.color)).padding(.bottom, 8)
                        Chart(bw.filter { $0.value(for: m.key) != nil }) { e in
                            LineMark(x: .value("g", fmtShort(e.date)), y: .value("v", Units.lenOut(e.value(for: m.key) ?? 0)))
                                .foregroundStyle(Color(hex: m.color)).interpolationMethod(.catmullRom)
                            AreaMark(x: .value("g", fmtShort(e.date)), y: .value("v", Units.lenOut(e.value(for: m.key) ?? 0)))
                                .foregroundStyle(LinearGradient(colors: [Color(hex: m.color).opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .styledAxes()
                        .frame(height: 120)
                    }
                }
            }
        }
    }

    // MARK: Backup
    private var backupCard: some View {
        Card {
            Lbl(text: t("home.backup")).padding(.bottom, 10)
            HStack(spacing: 10) {
                GhostButton(title: t("home.export")) {
                    if let url = store.exportFile() { shareURL = IdentURL(url: url) }
                }
                GhostButton(title: t("home.import")) { importing = true }
            }
        }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                toast.show(store.importFile(url) ? t("body.imported") : t("body.invalid_file"))
            case .failure:
                toast.show(t("body.import_cancelled"))
            }
        }
    }

    private func field(_ label: String, _ ph: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            FieldLabel(label)
            InputField(placeholder: ph, text: binding)
        }
    }
}
