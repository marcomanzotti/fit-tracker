import SwiftUI
import Charts
import UniformTypeIdentifiers

struct BodyView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter

    @State private var weightInput = ""
    @State private var sleepInput = ""
    @State private var bfInput = ""
    @State private var measInputs: [String: String] = [:]
    @State private var shareURL: IdentURL?
    @State private var importing = false
    // Nutrition & recovery inputs
    @State private var kcalInput = ""
    @State private var proteinInput = ""
    @State private var carbsInput = ""
    @State private var fatInput = ""
    @State private var stepsInput = ""
    @State private var rmssdInput = ""
    @State private var restHRInput = ""

    var body: some View {
        let lw = store.lastWeight
        let bmi = store.bmi(lw)
        let cat = store.bmiCategory(bmi)
        let bl = store.bodyLatest
        let navy = store.bfNavy(waist: bl?.waist, neck: bl?.neck)
        let bf = bl?.bfManual ?? navy
        let lean = bf.map { ((lw * (1 - $0 / 100)) * 10).rounded() / 10 }
        let fat = bf.map { ((lw * $0 / 100) * 10).rounded() / 10 }

        checkInCard
        nutritionRecoveryCard
        analysisCard(lw: lw, bmi: bmi, cat: cat, bl: bl, navy: navy, bf: bf, lean: lean, fat: fat)
        measurementsCard(bl: bl)
        chartsSection
        backupCard
    }

    // MARK: Nutrition & recovery (feeds the energy + readiness engines)
    private var nutritionRecoveryCard: some View {
        Card {
            Lbl(text: t("nut.intake_today"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                field("KCAL", "2400", $kcalInput)
                field("\(t("nut.protein")) (g)", "180", $proteinInput)
            }.padding(.bottom, 10)
            HStack(spacing: 10) {
                field("\(t("nut.carbs")) (g)", "250", $carbsInput)
                field("\(t("nut.fat")) (g)", "70", $fatInput)
            }.padding(.bottom, 10)
            HStack(spacing: 10) {
                field("STEPS", "8000", $stepsInput)
                field("\(t("wk.rmssd"))", "65", $rmssdInput)
            }.padding(.bottom, 10)
            HStack(spacing: 10) {
                field("\(t("ob.rest_hr"))", "58", $restHRInput)
                Spacer().frame(maxWidth: .infinity)
            }.padding(.bottom, 10)
            FilledButton(title: t("save")) {
                store.saveDailyExtras(
                    kcal: Int(kcalInput), protein: dOrNil(proteinInput), carbs: dOrNil(carbsInput),
                    fat: dOrNil(fatInput), steps: Int(stepsInput), rmssd: dOrNil(rmssdInput), restHR: Int(restHRInput))
                kcalInput = ""; proteinInput = ""; carbsInput = ""; fatInput = ""
                stepsInput = ""; rmssdInput = ""; restHRInput = ""
                toast.show(t("save"))
            }
        }
    }

    private func dOrNil(_ s: String) -> Double? { s.isEmpty ? nil : pf(s) }

    // MARK: Check-in
    private var checkInCard: some View {
        Card {
            Lbl(text: "\(t("home.checkin")) · \(today())", color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                field("\(t("home.weight")) (KG)", "87,5", $weightInput)
                if store.prefs.sleepEnabled {
                    field("\(t("home.sleep")) (0-100)", "78", $sleepInput)
                }
            }.padding(.bottom, 10)
            FilledButton(title: t("home.save_checkin")) {
                let w = pf(weightInput), s = pf(sleepInput)
                let hasW = w >= 30 && w <= 250, hasS = s > 0 && s <= 100
                guard hasW || hasS else { return }
                store.saveCheckIn(weight: hasW ? w : nil, sleep: hasS ? Int(s.rounded()) : nil)
                weightInput = ""; sleepInput = ""; toast.show(t("home.checkin_saved"))
            }
        }
    }

    // MARK: Body analysis
    private func analysisCard(lw: Double, bmi: Double, cat: (String, Color),
                              bl: BodyEntry?, navy: Double?, bf: Double?,
                              lean: Double?, fat: Double?) -> some View {
        Card {
            Lbl(text: t("body.analysis"), color: Theme.acc2).padding(.bottom, 12)
            HStack(spacing: 9) {
                StatTile(label: "BMI", value: trimNum(bmi), valueColor: cat.1, note: cat.0, info: "bmi")
                StatTile(label: t("body.fat"), value: bf.map(trimNum) ?? "—", unit: bf != nil ? "%" : nil,
                         valueColor: Theme.red, note: bf != nil ? "\(t("body.goal")) \(trimNum(store.prefs.goalBF))%" : "—", info: "bodyfat")
                StatTile(label: t("body.lean"), value: lean.map(trimNum) ?? "—", unit: lean != nil ? "kg" : nil,
                         valueColor: Theme.blue, note: fat != nil ? "\(trimNum(fat!))kg \(t("body.fat"))" : "—", info: "bodyfat")
            }
            .padding(.bottom, 12)

            if let bf, let lean, let fat {
                VStack(spacing: 6) {
                    HStack {
                        Text("\(t("body.fat")) \(trimNum(fat)) kg").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                        Spacer()
                        Text("\(t("body.lean")) \(trimNum(lean)) kg").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                    }
                    Bar(value: min(1, bf / 100), gradient: [Theme.red, Theme.acc2], height: 9)
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
                    store.saveBodyFat(v); bfInput = ""; toast.show(t("body.fat_saved"))
                }
                .frame(width: 90)
            }
            if let navy {
                Text("Navy: \(trimNum(navy))% · \(t("body.neck")) \(bl?.neck.map(trimNum) ?? "?") · \(t("body.waist")) \(bl?.waist.map(trimNum) ?? "?") cm")
                    .font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 8)
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
                    let v = pf(measInputs[m.key] ?? "")
                    if v > 0 { vals[m.key] = v }
                }
                guard !vals.isEmpty else { return }
                store.saveMeasurements(vals)
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
                if cur != nil { Text("cm").font(.system(size: 10)).foregroundColor(Theme.sub) }
            }
            .padding(.bottom, 8)
            TextField("", text: binding(for: m.key),
                      prompt: Text(cur.map(trimNum) ?? "–").foregroundColor(Theme.sub))
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .medium)).foregroundColor(Theme.txt)
                .padding(.vertical, 9).padding(.horizontal, 11)
                .background(Theme.c1).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            if let cur {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(trimNum(cur)).font(.num(26)).foregroundColor(Theme.txt)
                    Text("cm").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
                .padding(.top, 7)
                if let diff {
                    Text(diff == 0 ? t("body.stable") : "\(diff > 0 ? "+" : "")\(trimNum(diff)) cm")
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
                                         y: .value("cm", e.value(for: m.key) ?? 0),
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
                            LineMark(x: .value("g", fmtShort(e.date)), y: .value("cm", e.value(for: m.key) ?? 0))
                                .foregroundStyle(Color(hex: m.color)).interpolationMethod(.catmullRom)
                            AreaMark(x: .value("g", fmtShort(e.date)), y: .value("cm", e.value(for: m.key) ?? 0))
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
            Text(label).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
            InputField(placeholder: ph, text: binding)
        }
    }
}
