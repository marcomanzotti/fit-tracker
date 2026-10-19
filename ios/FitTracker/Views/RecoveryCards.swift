import SwiftUI
import Charts

// MARK: - Recovery cards (Body tab)
// The night behind the sleep score, and the overnight vitals against the user's
// own normal range. Both read one day, the one picked at the top of Body.

/// Everything recorded about one night: the stage chart, stage totals, score,
/// efficiency, regularity, bed and wake times, HRV when the device measures it,
/// and the last seven nights. Shown when the sleep card is expanded.
struct SleepNightDetail: View {
    @Environment(Store.self) var store
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let timeline = entry.sleepTimeline, timeline.count >= 3 {
                Hypnogram(day: chartDay(entry.date), timeline: timeline)
            }
            if let stages = stages {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        Text(t("sleep.stages").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                        InfoButton(id: .sleepStages, size: 18)
                    }
                    StageBar(stages: stages)
                    FlowLayout(spacing: 10) {
                        ForEach(stages.filter { $0.minutes > 0 }, id: \.key) { s in
                            HStack(spacing: 4) {
                                Circle().fill(s.color).frame(width: 7, height: 7)
                                Text("\(t("sleep." + s.key)) \(fmtMinutes(s.minutes))")
                                    .font(.ui(11, weight: .semibold)).foregroundColor(Theme.sub)
                            }
                        }
                    }
                }
            }
            if let score = entry.sleep, let scale = store.infoScale(.sleep) {
                VStack(alignment: .leading, spacing: 6) {
                    InfoLbl(text: t("sleep.score_scale"), info: .sleep)
                    RangeBar(scale: scale, value: Double(score))
                }
            }
            HStack(spacing: 9) {
                if let eff = entry.efficiency {
                    StatTile(label: t("sleep.efficiency"), value: "\(Int(eff.rounded()))", unit: "%",
                             valueColor: tone(.sleepEff, eff), info: .sleepEff)
                }
                if let reg = store.sleepRegularity(endingOn: entry.date) {
                    StatTile(label: t("sleep.regularity"), value: "±\(Int(reg.rounded()))", unit: "min",
                             valueColor: tone(.sleepReg, reg), info: .sleepReg)
                }
            }
            HStack(spacing: 9) {
                if let start = entry.sleepStartMin, let end = entry.sleepEndMin {
                    StatTile(label: t("sleep.times"), value: clock(start), valueColor: Theme.txt, note: "→ \(clock(end))")
                }
                if let bed = entry.inBedHours {
                    StatTile(label: t("sleep.in_bed"), value: fmtMinutes(Int((bed * 60).rounded())), valueColor: Theme.txt)
                }
                // Only the devices that measure HRV asleep (Apple Watch) have it.
                if let hrv = entry.hrvSleep, hrv > 0 {
                    StatTile(label: "HRV", value: trimNum(hrv.rounded()), unit: "ms", valueColor: Theme.blue, info: .hrv)
                }
            }
            let debt = store.sleepDebt(), jetLag = store.socialJetLag()
            if debt != nil || jetLag != nil {
                HStack(spacing: 9) {
                    if let debt {
                        StatTile(label: t("sleep.debt"), value: fmtMinutes(Int((debt * 60).rounded())),
                                 valueColor: tone(.sleepDebt, debt), note: t("sleep.debt_note"), info: .sleepDebt)
                    }
                    if let jetLag {
                        StatTile(label: t("sleep.jetlag"), value: fmtMinutes(Int(jetLag.rounded())),
                                 valueColor: tone(.jetLag, jetLag), info: .jetLag)
                    }
                }
            }
            WeekSleepChart(endingOn: entry.date)
        }
    }

    private var stages: [StageBar.Stage]? {
        guard let deep = entry.sleepDeepMin, let rem = entry.sleepREMMin, let core = entry.sleepCoreMin,
              deep + rem + core > 0 else { return nil }
        return [StageBar.Stage(key: "deep", minutes: deep, color: SleepColors.deep),
                StageBar.Stage(key: "core", minutes: core, color: SleepColors.core),
                StageBar.Stage(key: "rem", minutes: rem, color: SleepColors.rem),
                StageBar.Stage(key: "awake", minutes: entry.sleepAwakeMin ?? 0, color: SleepColors.awake)]
    }

    private func tone(_ topic: InfoTopic, _ v: Double) -> Color {
        guard let s = store.infoScale(topic) else { return Theme.txt }
        return s.bands[s.bandIndex(of: v)].tone.color
    }
}

/// Minutes from the wake day's midnight as a clock time ("-60" is 23:00).
func clock(_ minutes: Int) -> String {
    let m = (minutes % 1440 + 1440) % 1440
    return String(format: "%d:%02d", m / 60, m % 60)
}

enum SleepColors {
    static let deep = Color(hex: "3a6df0")
    static let core = Color(hex: "4fb8c4")
    static let rem = Color(hex: "b08fff")
    static let awake = Theme.acc2
    static let asleep = Color(hex: "4fb8c4").opacity(0.7)
}

/// The night as a stage chart (hypnogram): one row per stage, awake on top and
/// deep at the bottom, time along the x axis, as in Health or Sleep Cycle.
struct Hypnogram: View {
    let day: Date
    let timeline: [Int]

    private struct Segment: Identifiable {
        let id: Int
        let start: Date
        let end: Date
        let code: Int
    }

    private static let rows: [(code: Int, key: String)] = [(0, "awake"), (3, "rem"), (1, "core"), (2, "deep")]

    var body: some View {
        let segments = stride(from: 0, to: timeline.count - 2, by: 3).map { i in
            Segment(id: i, start: day.addingTimeInterval(Double(timeline[i]) * 60),
                    end: day.addingTimeInterval(Double(timeline[i + 1]) * 60),
                    code: timeline[i + 2] == 4 ? 1 : timeline[i + 2])
        }
        let labels = Self.rows.map { t("sleep." + $0.key) }
        Chart(segments) { s in
            RectangleMark(xStart: .value("from", s.start), xEnd: .value("to", s.end),
                          y: .value("stage", label(s.code)), height: .ratio(0.82))
                .foregroundStyle(color(s.code))
                .cornerRadius(3)
        }
        .chartYScale(domain: labels)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                AxisGridLine().foregroundStyle(Theme.sub.opacity(0.15))
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(cachedFormatter("HH:mm").string(from: d)).font(.ui(10)).foregroundStyle(Theme.sub)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in AxisValueLabel().font(.ui(10)).foregroundStyle(Theme.sub) }
        }
        .padding(.trailing, 14)   // room for the last hour label
        .frame(height: 140)
        .accessibilityLabel(t("sleep.hypnogram"))
    }

    private func label(_ code: Int) -> String {
        t("sleep." + (Self.rows.first { $0.code == code }?.key ?? "core"))
    }

    private func color(_ code: Int) -> Color {
        switch code {
        case 0:  return SleepColors.awake
        case 2:  return SleepColors.deep
        case 3:  return SleepColors.rem
        default: return SleepColors.core
        }
    }
}

/// Hours asleep over the seven nights up to a day, against the 7–9 h band.
struct WeekSleepChart: View {
    @Environment(Store.self) var store
    let endingOn: String

    var body: some View {
        let days = (0..<7).reversed().compactMap { back -> (Date, Double)? in
            guard let end = isoFormatter.date(from: endingOn),
                  let d = Calendar.current.date(byAdding: .day, value: -back, to: end) else { return nil }
            return (d, store.dailyEntry(isoFormatter.string(from: d))?.sleepHours ?? 0)
        }
        let average = days.map(\.1).filter { $0 > 0 }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("sleep.week").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Spacer()
                if !average.isEmpty {
                    Text(t("sleep.week_avg", fmtMinutes(Int((average.reduce(0, +) / Double(average.count) * 60).rounded()))))
                        .font(.ui(11, weight: .semibold)).foregroundColor(Theme.sub)
                }
            }
            Chart {
                RectangleMark(yStart: .value("lo", 7), yEnd: .value("hi", 9))
                    .foregroundStyle(Theme.good.opacity(0.12))
                ForEach(days, id: \.0) { d, h in
                    BarMark(x: .value(t("chart.date"), d, unit: .day), y: .value("h", h))
                        .foregroundStyle(h >= 7 && h <= 9 ? Theme.good : Theme.acc2)
                        .cornerRadius(3)
                }
            }
            .chartYScale(domain: 0...max(10, (days.map(\.1).max() ?? 0) + 1))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(cachedFormatter("EEEEE", locale: L.lang == "en" ? "en_US" : "it_IT").string(from: d))
                                .font(.ui(10)).foregroundStyle(Theme.sub)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 4, 7, 9]) { _ in
                    AxisGridLine().foregroundStyle(Theme.mut)
                    AxisValueLabel().font(.ui(10)).foregroundStyle(Theme.sub)
                }
            }
            .frame(height: 110)
        }
    }
}

/// One horizontal bar split by sleep stage, in the order they make up the night.
struct StageBar: View {
    struct Stage { let key: String; let minutes: Int; let color: Color }
    let stages: [Stage]

    var body: some View {
        let total = max(1, stages.reduce(0) { $0 + $1.minutes })
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(stages.filter { $0.minutes > 0 }, id: \.key) { s in
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(s.color)
                        .frame(width: max(3, (geo.size.width - 6) * CGFloat(s.minutes) / CGFloat(total)))
                }
            }
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stages.map { "\(t("sleep." + $0.key)) \(fmtMinutes($0.minutes))" }.joined(separator: ", "))
    }
}

func fmtMinutes(_ m: Int) -> String { m >= 60 ? "\(m / 60)h\(String(format: "%02d", m % 60))" : "\(m)′" }

/// HRV, sleeping HR, breathing, SpO₂ and wrist temperature of one night, each on
/// a bar of the user's usual range (60 days, ± 2 SD).
struct NightVitalsCard: View {
    @Environment(Store.self) var store
    let day: String

    var body: some View {
        let vitals = store.nightVitals(on: day)
        let out = vitals.filter { $0.status == "high" || $0.status == "low" }.count
        return Group {
            if !vitals.isEmpty {
                Card(accent: out > 0 ? Theme.acc2 : nil) {
                    HStack(spacing: 4) {
                        InfoLbl(text: t("vit.title"), info: .nightVitals, color: Theme.acc2)
                        Spacer()
                        Text(out == 0 ? t("vit.all_ok") : t("vit.out_count", out))
                            .font(.head(10, .semibold)).tracking(0.5)
                            .foregroundColor(out == 0 ? Theme.good : Theme.acc2)
                    }
                    .padding(.bottom, 10)
                    VStack(spacing: 14) {
                        ForEach(vitals) { v in row(v) }
                    }
                }
            }
        }
    }

    private func row(_ v: VitalReading) -> some View {
        let spec = Self.spec(v.field)
        let shown = v.field == .wristTemp ? v.value - (v.range?.mean ?? v.value) : v.value
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: spec.icon).font(.ui(11)).foregroundColor(Theme.sub).frame(width: 16)
                Text(t(spec.name)).font(.ui(13, weight: .semibold)).foregroundColor(Theme.txt)
                InfoButton(id: spec.topic, size: 18)
                Spacer()
                Text(valueText(shown, spec)).font(.num(15)).foregroundColor(Theme.txt).monospacedDigit()
                Text(t("vit." + v.status).uppercased()).font(.head(9, .semibold)).tracking(0.5)
                    .foregroundColor(statusColor(v.status))
                    .padding(.vertical, 3).padding(.horizontal, 6)
                    .background(statusColor(v.status).opacity(0.14)).clipShape(Capsule())
            }
            if let scale = scale(v, spec) { RangeBar(scale: scale, value: shown, height: 6) }
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "ok":          return Theme.good
        case "high", "low": return Theme.acc2
        default:            return Theme.sub
        }
    }

    private func valueText(_ v: Double, _ spec: Spec) -> String {
        // Rounded first, so a tiny negative deviation never prints as "-0.00".
        let step = pow(10, Double(spec.decimals))
        let r = (v * step).rounded() / step
        let n = String(format: "%.\(spec.decimals)f", r == 0 ? 0 : r)
        return spec.signed && r > 0 ? "+\(n) \(spec.unit)" : "\(n) \(spec.unit)"
    }

    /// The usual range drawn as a bar: below, usual, above. The wrist temperature
    /// is shown as its deviation, so its bar is centred on zero.
    private func scale(_ v: VitalReading, _ spec: Spec) -> InfoScale? {
        if v.field == .spo2 { return store.infoScale(.spo2) }
        guard let r = v.range else { return nil }
        let m = v.field == .wristTemp ? 0 : r.mean, b = v.band
        return InfoScale(from: m - 2 * b, bands: [InfoBand(upTo: m - b, key: "below_usual", tone: .fair),
                                                  InfoBand(upTo: m + b, key: "usual", tone: .great),
                                                  InfoBand(upTo: m + 2 * b, key: "above_usual", tone: .fair)],
                         unit: spec.unit, decimals: spec.decimals)
    }

    struct Spec { let name: String; let icon: String; let topic: InfoTopic; let unit: String; let decimals: Int; var signed = false }
    static func spec(_ f: HealthField) -> Spec {
        switch f {
        case .hrvSleep: return Spec(name: "vit.hrv", icon: "waveform.path.ecg", topic: .hrv, unit: "ms", decimals: 0)
        case .sleepHR:  return Spec(name: "vit.sleep_hr", icon: "heart.fill", topic: .sleepHR, unit: "bpm", decimals: 0)
        case .respRate: return Spec(name: "vit.resp_short", icon: "wind", topic: .respRate, unit: "/min", decimals: 1)
        case .spo2:     return Spec(name: "vit.spo2", icon: "drop.fill", topic: .spo2, unit: "%", decimals: 0)
        default:        return Spec(name: "vit.temp", icon: "thermometer.medium", topic: .wristTemp, unit: "°C",
                                    decimals: 2, signed: true)
        }
    }
}
