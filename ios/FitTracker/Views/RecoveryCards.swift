import SwiftUI

// MARK: - Recovery cards (Body tab)
// The night behind the sleep score, and the overnight vitals against the user's
// own normal range. Both read one day, the one picked at the top of Body.

/// Stages, efficiency, regularity and bed / wake times of one night.
struct SleepNightDetail: View {
    @EnvironmentObject var store: Store
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let score = entry.sleep, let scale = store.infoScale(.sleep) {
                RangeBar(scale: scale, value: Double(score))
            }
            if let stages = stages {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        Text(t("sleep.stages").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                        InfoButton(id: .sleepStages, size: 18)
                    }
                    StageBar(stages: stages)
                    HStack(spacing: 10) {
                        ForEach(stages, id: \.key) { s in
                            HStack(spacing: 4) {
                                Circle().fill(s.color).frame(width: 7, height: 7)
                                Text("\(t("sleep." + s.key)) \(fmtMinutes(s.minutes))")
                                    .font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                    }
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
                if let start = entry.sleepStartMin, let end = entry.sleepEndMin {
                    StatTile(label: t("sleep.times"), value: clock(start), valueColor: Theme.txt, note: "→ \(clock(end))")
                }
            }
        }
    }

    private var stages: [StageBar.Stage]? {
        guard let deep = entry.sleepDeepMin, let rem = entry.sleepREMMin, let core = entry.sleepCoreMin,
              deep + rem + core > 0 else { return nil }
        return [StageBar.Stage(key: "deep", minutes: deep, color: Theme.blue),
                StageBar.Stage(key: "core", minutes: core, color: Theme.blue.opacity(0.45)),
                StageBar.Stage(key: "rem", minutes: rem, color: Color(hex: "b08fff")),
                StageBar.Stage(key: "awake", minutes: entry.sleepAwakeMin ?? 0, color: Theme.acc2)]
    }

    private func tone(_ topic: InfoTopic, _ v: Double) -> Color {
        guard let s = store.infoScale(topic) else { return Theme.txt }
        return s.bands[s.bandIndex(of: v)].tone.color
    }

    /// Minutes from the wake day's midnight as a clock time ("-60" is 23:00).
    private func clock(_ minutes: Int) -> String {
        let m = (minutes % 1440 + 1440) % 1440
        return String(format: "%d:%02d", m / 60, m % 60)
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
    @EnvironmentObject var store: Store
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
                Image(systemName: spec.icon).font(.system(size: 11)).foregroundColor(Theme.sub).frame(width: 16)
                Text(t(spec.name)).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.txt)
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
