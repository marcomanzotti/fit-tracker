import SwiftUI
import Charts

// MARK: - Training cards
// Form (fitness − fatigue), recovery time, weekly intensity and relative
// strength. Each card hides itself until there is data behind it. Colors were
// checked with the data-viz validator on the dark card surface (#141417):
// fitness / fatigue pair and the one-hue zone ramp both pass.
enum TrainingColors {
    static let fitness = Color(hex: "3987e5")
    static let fatigue = Color(hex: "d95926")
    /// Z1 … Z5, one hue from dim to bright (ordinal ramp).
    static let zones = ["184f95", "256abf", "3987e5", "6da7ec", "9ec5f4"].map { Color(hex: $0) }
}

/// The status of a value on its scale, as a colored label: never color alone.
struct BandLabel: View {
    let scale: InfoScale
    let value: Double
    var body: some View {
        let b = scale.bands[scale.bandIndex(of: value)]
        Text(t("band." + b.key).uppercased())
            .font(.head(10, .semibold)).tracking(0.5)
            .lineLimit(1).minimumScaleFactor(0.7)
            .foregroundColor(b.tone.color)
            .padding(.vertical, 3).padding(.horizontal, 7)
            .background(b.tone.color.opacity(0.14)).clipShape(Capsule())
    }
}

// MARK: Form
struct FormCard: View {
    @Environment(Store.self) var store

    var body: some View {
        let series = store.loadDataStatus().reliable ? store.formSeries() : []
        Group {
            if let today = series.last, let percent = store.formPercent(), let scale = store.infoScale(.form) {
                Card {
                    HStack(spacing: 4) {
                        InfoLbl(text: t("form.title"), info: .form, color: Theme.acc2)
                        Spacer()
                        BandLabel(scale: scale, value: percent)
                    }
                    .padding(.bottom, 10)
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(signed(percent) + "%").font(.num(34)).foregroundColor(Theme.txt)
                        metric(t("form.fitness"), today.fitness, TrainingColors.fitness)
                        metric(t("form.fatigue"), today.fatigue, TrainingColors.fatigue)
                        Spacer(minLength: 0)
                    }
                    RangeBar(scale: scale, value: percent).padding(.vertical, 8)
                    Text(t("form.chart_fitness").uppercased()).font(.head(10, .semibold)).tracking(1)
                        .foregroundColor(Theme.sub).padding(.top, 6)
                    fitnessChart(series)
                    Text(t("form.chart_form").uppercased()).font(.head(10, .semibold)).tracking(1)
                        .foregroundColor(Theme.sub).padding(.top, 12)
                    formChart(series)
                }
            }
        }
    }

    private func metric(_ label: String, _ v: Double, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.ui(11, weight: .medium)).foregroundColor(Theme.sub)
            Text("\(Int(v.rounded()))").font(.num(15)).foregroundColor(Theme.txt)
        }
    }

    /// Fitness and fatigue share one unit (load per day), so one axis.
    private func fitnessChart(_ s: [FormPoint]) -> some View {
        let fitness = t("form.fitness"), fatigue = t("form.fatigue")
        return Chart(s) { p in
            LineMark(x: .value(t("chart.date"), p.day, unit: .day), y: .value(t("chart.value"), p.fitness), series: .value("s", fitness))
                .foregroundStyle(by: .value("s", fitness))
                .lineStyle(StrokeStyle(lineWidth: 2))
            LineMark(x: .value(t("chart.date"), p.day, unit: .day), y: .value(t("chart.value"), p.fatigue), series: .value("s", fatigue))
                .foregroundStyle(by: .value("s", fatigue))
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartForegroundStyleScale(domain: [fitness, fatigue], range: [TrainingColors.fitness, TrainingColors.fatigue])
        .chartLegend(position: .top, alignment: .leading, spacing: 6)
        .dateAxes(s.map(\.day))
        .frame(height: 140)
    }

    /// Form around zero: fresh above, loaded below, on its own axis.
    private func formChart(_ s: [FormPoint]) -> some View {
        Chart(s) { p in
            BarMark(x: .value(t("chart.date"), p.day, unit: .day), y: .value("f", p.form))
                .foregroundStyle(p.form >= 0 ? TrainingColors.fitness : TrainingColors.fatigue)
            RuleMark(y: .value("zero", 0)).foregroundStyle(Theme.sub.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1))
        }
        .dateAxes(s.map(\.day))
        .frame(height: 90)
    }

    private func signed(_ v: Double) -> String {
        let n = Int(v.rounded())
        return n > 0 ? "+\(n)" : "\(n)"
    }
}

// MARK: Weekly intensity (time in zones)
struct IntensityCard: View {
    @Environment(Store.self) var store

    private struct Slice: Identifiable {
        let week: Date
        let zone: Int
        let hours: Double
        var id: String { "\(week.timeIntervalSince1970)-\(zone)" }
    }

    var body: some View {
        let weeks = store.intensityWeeks()
        Group {
            if !weeks.isEmpty, let scale = store.infoScale(.intensity), let easy = store.infoValue(.intensity) {
                let recent = Array(weeks.suffix(4))
                let total = recent.reduce(0) { $0 + $1.total }
                let hard = total > 0 ? recent.reduce(0) { $0 + $1.zoneSeconds[3] + $1.zoneSeconds[4] } / total * 100 : 0
                Card {
                    HStack(spacing: 4) {
                        InfoLbl(text: t("intensity.title"), info: .intensity, color: Theme.acc2)
                        Spacer()
                        BandLabel(scale: scale, value: easy)
                    }
                    .padding(.bottom, 10)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(easy.rounded()))%").font(.num(28)).foregroundColor(Theme.txt)
                        Text(t("intensity.easy")).font(.ui(12)).foregroundColor(Theme.sub)
                        Text("·").foregroundColor(Theme.sub)
                        Text("\(Int(hard.rounded()))%").font(.num(20)).foregroundColor(Theme.txt)
                        Text(t("intensity.hard")).font(.ui(12)).foregroundColor(Theme.sub)
                        Spacer()
                    }
                    RangeBar(scale: scale, value: easy).padding(.vertical, 8)
                    zoneChart(weeks)
                }
            }
        }
    }

    private func zoneChart(_ weeks: [IntensityWeek]) -> some View {
        let slices = weeks.flatMap { w in (0..<5).map { Slice(week: w.start, zone: $0, hours: w.zoneSeconds[$0] / 3600) } }
        let names = (1...5).map { t("intensity.zone", $0) }
        return Chart(slices) { s in
            BarMark(x: .value("w", s.week, unit: .weekOfYear), y: .value("h", s.hours))
                .foregroundStyle(by: .value("z", names[s.zone]))
        }
        .chartForegroundStyleScale(domain: names, range: TrainingColors.zones)
        .chartLegend(position: .top, alignment: .leading, spacing: 6)
        .dateAxes(weeks.map(\.start))
        .frame(height: 150)
    }
}

// MARK: Relative strength
struct StrengthCard: View {
    @Environment(Store.self) var store

    var body: some View {
        let lifts = store.relativeStrength()
        Group {
            if !lifts.isEmpty {
                Card {
                    InfoLbl(text: t("strength.title"), info: .strength, color: Theme.acc2).padding(.bottom, 12)
                    VStack(spacing: 14) {
                        ForEach(lifts) { l in row(l) }
                    }
                }
            }
        }
    }

    private func row(_ l: Store.LiftStrength) -> some View {
        let scale = store.strengthScale(l.lift)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(t("lift." + l.lift.rawValue)).font(.ui(13, weight: .semibold)).foregroundColor(Theme.txt)
                Text("\(trimNum(l.e1RM)) kg").font(.ui(11)).foregroundColor(Theme.sub)
                Spacer()
                Text("\(String(format: "%.2f", l.ratio))×").font(.num(15)).foregroundColor(Theme.txt)
                BandLabel(scale: scale, value: l.ratio)
            }
            RangeBar(scale: scale, value: l.ratio, height: 6)
        }
        .accessibilityElement(children: .combine)
    }
}
