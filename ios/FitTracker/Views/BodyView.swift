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
        analysisCard(lw: lw, bmi: bmi, cat: cat, bl: bl, navy: navy, bf: bf, lean: lean, fat: fat)
        measurementsCard(bl: bl)
        chartsSection
        backupCard
    }

    // MARK: Check-in
    private var checkInCard: some View {
        Card {
            Lbl(text: "Check-in · \(today())", color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                field("PESO (KG)", "87,5", $weightInput)
                field("SLEEP (0-100)", "78", $sleepInput)
            }.padding(.bottom, 10)
            FilledButton(title: "Salva check-in") {
                let w = pf(weightInput), s = pf(sleepInput)
                let hasW = w >= 30 && w <= 250, hasS = s > 0 && s <= 100
                guard hasW || hasS else { return }
                store.saveCheckIn(weight: hasW ? w : nil, sleep: hasS ? Int(s.rounded()) : nil)
                weightInput = ""; sleepInput = ""; toast.show("Check-in salvato")
            }
        }
    }

    // MARK: Body analysis
    private func analysisCard(lw: Double, bmi: Double, cat: (String, Color),
                              bl: BodyEntry?, navy: Double?, bf: Double?,
                              lean: Double?, fat: Double?) -> some View {
        Card {
            Lbl(text: "Analisi corporea", color: Theme.acc2).padding(.bottom, 12)
            HStack(spacing: 9) {
                StatTile(label: "BMI", value: trimNum(bmi), valueColor: cat.1, note: cat.0)
                StatTile(label: "Grasso", value: bf.map(trimNum) ?? "—", unit: bf != nil ? "%" : nil,
                         valueColor: Theme.red, note: bf != nil ? "goal \(trimNum(store.prefs.goalBF))%" : "—")
                StatTile(label: "Magra", value: lean.map(trimNum) ?? "—", unit: lean != nil ? "kg" : nil,
                         valueColor: Theme.blue, note: fat != nil ? "\(trimNum(fat!))kg grasso" : "—")
            }
            .padding(.bottom, 12)

            if let bf, let lean, let fat {
                VStack(spacing: 6) {
                    HStack {
                        Text("Grasso \(trimNum(fat)) kg").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                        Spacer()
                        Text("Magra \(trimNum(lean)) kg").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                    }
                    Bar(value: min(1, bf / 100), gradient: [Theme.red, Theme.acc2], height: 9)
                }
                .padding(.bottom, 12)
            }

            Text("GRASSO % · MANUALE O NAVY (COLLO + VITA)").font(.head(10, .semibold)).tracking(1)
                .foregroundColor(Theme.sub).padding(.bottom, 8)
            HStack(spacing: 10) {
                InputField(placeholder: navy != nil ? "Navy: \(trimNum(navy!))%" : "18,5", text: $bfInput)
                FilledButton(title: "Salva") {
                    let v = pf(bfInput)
                    guard v >= 1 && v <= 60 else { return }
                    store.saveBodyFat(v); bfInput = ""; toast.show("Grasso % salvato")
                }
                .frame(width: 90)
            }
            if let navy {
                Text("Navy: \(trimNum(navy))% · collo \(bl?.neck.map(trimNum) ?? "?") · vita \(bl?.waist.map(trimNum) ?? "?") cm")
                    .font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 8)
            }
        }
    }

    // MARK: Measurements
    private func measurementsCard(bl: BodyEntry?) -> some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return Card {
            Lbl(text: "Misurazioni settimanali", color: Theme.acc2).padding(.bottom, 10)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(measureFields) { m in
                    measureTile(m, bl: bl)
                }
            }
            .padding(.bottom, 10)
            FilledButton(title: "Salva misurazioni") {
                var vals: [String: Double] = [:]
                for m in measureFields {
                    let v = pf(measInputs[m.key] ?? "")
                    if v > 0 { vals[m.key] = v }
                }
                guard !vals.isEmpty else { return }
                store.saveMeasurements(vals)
                measInputs = [:]
                toast.show("Misurazioni salvate")
            }
        }
    }

    private func measureTile(_ m: MeasureField, bl: BodyEntry?) -> some View {
        let cur = bl?.value(for: m.key)
        let prev = store.bodyPrev?.value(for: m.key)
        let diff: Double? = (cur != nil && prev != nil) ? ((cur! - prev!) * 10).rounded() / 10 : nil
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(m.label.uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
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
                    Text(diff == 0 ? "stabile" : "\(diff > 0 ? "+" : "")\(trimNum(diff)) cm")
                        .font(.num(11)).foregroundColor(diff == 0 ? Theme.sub : (diff < 0 ? Theme.good : Theme.acc2))
                        .padding(.top, 4)
                }
            } else {
                Text("Nessun dato").font(.system(size: 11)).foregroundColor(Theme.sub).padding(.top, 8)
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
                    Lbl(text: "Tutte le misurazioni").padding(.bottom, 8)
                    Chart {
                        ForEach(measureFields) { m in
                            ForEach(bw.filter { $0.value(for: m.key) != nil }) { e in
                                LineMark(x: .value("g", fmtShort(e.date)),
                                         y: .value("cm", e.value(for: m.key) ?? 0),
                                         series: .value("p", m.label))
                                    .foregroundStyle(Color(hex: m.color))
                                    .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .chartForegroundStyleScale(domain: measureFields.map { $0.label },
                                               range: measureFields.map { Color(hex: $0.color) })
                    .chartLegend(position: .bottom, spacing: 8)
                    .styledAxes()
                    .frame(height: 205)
                }
                ForEach(measureFields.filter { f in bw.filter { $0.value(for: f.key) != nil }.count >= 2 }) { m in
                    Card {
                        Lbl(text: m.label, color: Color(hex: m.color)).padding(.bottom, 8)
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
            Lbl(text: "Backup dati").padding(.bottom, 10)
            HStack(spacing: 10) {
                GhostButton(title: "Esporta JSON") {
                    if let url = store.exportFile() { shareURL = IdentURL(url: url) }
                }
                GhostButton(title: "Importa JSON") { importing = true }
            }
        }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                toast.show(store.importFile(url) ? "Dati importati" : "File non valido")
            case .failure:
                toast.show("Importazione annullata")
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
