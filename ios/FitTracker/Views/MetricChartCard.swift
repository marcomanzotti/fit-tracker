import SwiftUI
import Charts

/// A daily metric whose overview chart shows weekly averages over the last 2
/// months and expands into a larger view with a day/week/month/year toggle. Tap
/// a point/bar to see the exact value.
struct MetricChartCard: View {
    @EnvironmentObject var store: Store

    let title: String
    var info: InfoTopic? = nil
    let color: Color
    var kind: Kind = .area
    var yDomain: ClosedRange<Double>? = nil
    var unit: String = ""
    let value: (DailyEntry) -> Double?

    enum Kind { case area, bar }

    @State private var expanded = false
    @State private var selected: Store.WeekPoint? = nil

    var body: some View {
        let data = store.metricSeries(value, granularity: .week, months: 2)
        return Group {
            if data.count > 1 {
                Card {
                    HStack(spacing: 4) {
                        Lbl(text: title)
                        if let info { InfoButton(id: info) }
                        Spacer()
                        if let sel = selected {
                            SelectedValue(value: chartValue(sel.value, unit: unit), day: sel.day,
                                          granularity: .week, color: color)
                        }
                        Button { tap(); expanded = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                                .frame(width: 28, height: 28)
                                .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .hitArea((Theme.minTapTarget - 28) / 2)
                        .accessibilityLabel(t("a11y.expand"))
                    }
                    .padding(.bottom, 8)
                    InteractiveMetricPlot(data: data, color: color, kind: kind, granularity: .week,
                                          yDomain: yDomain, selected: $selected)
                        .frame(height: 150)
                }
                .sheet(isPresented: $expanded) {
                    ExpandedChartSheet(title: title, color: color, kind: kind,
                                       yDomain: yDomain, unit: unit, value: value)
                }
            }
        }
    }
}

/// "72.4 kg · 14 Oct" in a chart header, for the point the user tapped.
private struct SelectedValue: View {
    let value: String
    let day: Date
    let granularity: Store.ChartGranularity
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(value).font(.num(13)).foregroundColor(color)
            Text("·").foregroundColor(Theme.sub).font(.system(size: 11))
            Text(pointDate(day, granularity)).font(.system(size: 11)).foregroundColor(Theme.sub)
        }
    }
}

private func chartValue(_ v: Double, unit: String) -> String {
    if !unit.isEmpty { return "\(trimNum(v)) \(unit)" }
    if v >= 1000 { return "\(Int(v.rounded()))" }
    return trimNum(v)
}

/// The tapped bucket's date: the day for day/week buckets, else month or year.
private func pointDate(_ d: Date, _ g: Store.ChartGranularity) -> String {
    let format: String
    switch g {
    case .day, .week: format = "d MMM yyyy"
    case .month:      format = "MMMM yyyy"
    case .year:       format = "yyyy"
    }
    return cachedFormatter(format, locale: L.lang == "en" ? "en_US" : "it_IT").string(from: d)
}

/// Interactive chart with tap/drag selection. Shows a vertical rule + dot on the
/// selected bucket; the parent card header displays the selected date + value.
struct InteractiveMetricPlot: View {
    let data: [Store.WeekPoint]
    let color: Color
    let kind: MetricChartCard.Kind
    let granularity: Store.ChartGranularity
    var yDomain: ClosedRange<Double>? = nil
    var showPoints = false
    @Binding var selected: Store.WeekPoint?

    var body: some View {
        let unit = granularity.unit
        // Bars start at zero; a line gets a range around its own values, and its
        // area fills down to that floor (an area to 0 would flatten 80 → 79 kg).
        let range = yDomain ?? (kind == .bar ? 0...max(1, (data.map(\.value).max() ?? 1) * 1.1) : chartRange(data.map(\.value)))
        Chart(data) { p in
            let isSelected = selected?.id == p.id
            if kind == .bar {
                BarMark(x: .value("d", p.day, unit: unit), y: .value("v", p.value))
                    .foregroundStyle(isSelected ? color : color.opacity(0.55))
                    .cornerRadius(3)
            } else {
                LineMark(x: .value("d", p.day, unit: unit), y: .value("v", p.value))
                    .interpolationMethod(.catmullRom).foregroundStyle(color)
                AreaMark(x: .value("d", p.day, unit: unit), yStart: .value("v", range.lowerBound), yEnd: .value("v", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.22), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                if showPoints || isSelected {
                    PointMark(x: .value("d", p.day, unit: unit), y: .value("v", p.value))
                        .foregroundStyle(color).symbolSize(isSelected ? 36 : 14)
                }
                if isSelected {
                    RuleMark(x: .value("d", p.day, unit: unit))
                        .foregroundStyle(color.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
        }
        .chartYScale(domain: range)
        .dateAxes(data.map(\.day))
        .chartOverlay { proxy in
            GeometryReader { geo in
                // A plain tap selects the nearest bucket (toggle off if re-tapped).
                // For scrubbing we require a deliberate long-press FIRST, then drag —
                // this lets a normal vertical scroll pass straight through the chart
                // instead of being captured the instant a finger touches it.
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onTapGesture { loc in
                        let pt = closestPoint(atX: loc.x - plotOriginX(geo, proxy), proxy)
                        selected = selected?.id == pt?.id ? nil : pt
                    }
                    .gesture(
                        LongPressGesture(minimumDuration: 0.18)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                if case .second(true, let drag?) = value {
                                    selected = closestPoint(atX: drag.location.x - plotOriginX(geo, proxy), proxy)
                                }
                            }
                    )
            }
        }
    }

    private func plotOriginX(_ geo: GeometryProxy, _ proxy: ChartProxy) -> CGFloat {
        proxy.plotFrame.map { geo[$0].origin.x } ?? 0
    }

    private func closestPoint(atX x: CGFloat, _ proxy: ChartProxy) -> Store.WeekPoint? {
        guard let date: Date = proxy.value(atX: x) else { return nil }
        return data.min { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) }
    }
}

/// A y range around a series with some air above and below, so a line chart shows
/// how the values move instead of hugging the top of a 0-based axis.
func chartRange(_ values: [Double]) -> ClosedRange<Double> {
    guard let lo = values.min(), let hi = values.max() else { return 0...1 }
    let pad = max((hi - lo) * 0.2, abs(hi) * 0.01, 0.5)
    return (lo - pad)...(hi + pad)
}

/// A row of capsule chips to pick one option (chart granularity, time window).
struct ChipPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { o in
                let active = selection == o
                Button { tap(); selection = o } label: {
                    Text(label(o).uppercased())
                        .font(.head(10, .semibold)).tracking(0.5)
                        .foregroundColor(active ? Theme.bg : Theme.sub)
                        .padding(.vertical, 7).padding(.horizontal, 12)
                        .background(active ? Theme.acc : Theme.c2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(active ? Theme.acc : Theme.brd, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
    }
}

/// 1M / 3M / 6M / 1Y / All above a chart that would otherwise plot every day ever logged.
struct ChartWindowPicker: View {
    @Binding var window: ChartWindow
    var body: some View {
        ChipPicker(options: ChartWindow.allCases, selection: $window) { $0.label }
    }
}

/// Full-screen expanded chart: day/week/month/year toggle and the whole period
/// on screen, with its own tap selection. Opened from a MetricChartCard.
struct ExpandedChartSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let title: String
    let color: Color
    let kind: MetricChartCard.Kind
    let yDomain: ClosedRange<Double>?
    var unit: String = ""
    let value: (DailyEntry) -> Double?

    @State private var gran: Store.ChartGranularity = .week
    @State private var selected: Store.WeekPoint? = nil

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.uppercased())
                            .font(.head(18, .bold)).tracking(1).foregroundColor(Theme.txt)
                        if let sel = selected {
                            SelectedValue(value: chartValue(sel.value, unit: unit), day: sel.day,
                                          granularity: gran, color: color)
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub)
                            .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    }
                }
                .padding(.top, 18)

                ChipPicker(options: Store.ChartGranularity.allCases, selection: $gran) { t("chart.gran." + $0.rawValue) }
                    .onChange(of: gran) { selected = nil }

                let data = store.metricSeries(value, granularity: gran)
                if data.count > 1 {
                    InteractiveMetricPlot(data: data, color: color, kind: kind, granularity: gran, yDomain: yDomain,
                                          showPoints: kind == .area && data.count <= 40, selected: $selected)
                        .frame(height: 320)
                } else {
                    Spacer()
                    Text(t("st.no_data")).font(.system(size: 13)).foregroundColor(Theme.sub)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
    }
}

// MARK: - Phase 3 metric cards (Stats overview)
// Read-only insight cards built on the Store metrics in Metrics.swift. Each shows
// only when it has data, so an empty profile never sees a wall of dashes.

// MARK: Weekly sets per muscle group
struct MuscleVolumeCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let vols = store.weeklyMuscleVolume()
        // Scale bars against the highest of "most sets done" and "highest target", so
        // an under-trained group reads as short against its own goal rather than
        // filling the row just because nothing else was trained.
        let maxSets = max(1, vols.map { max($0.sets, $0.target) }.max() ?? 1)
        return Group {
            if !vols.isEmpty {
                Card {
                    InfoLbl(text: t("metric.muscle_vol"), info: .muscleVol, color: Theme.acc2).padding(.bottom, 10)
                    VStack(spacing: 10) {
                        ForEach(vols) { v in
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: v.group.color)).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t(v.group.labelKey)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.txt)
                                    if v.target > 0 {
                                        Text(t("st.vol_target", v.range.low, v.range.high))
                                            .font(.system(size: 10)).foregroundColor(Theme.sub)
                                    }
                                }
                                .frame(width: 92, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.c2).frame(height: 7)
                                        // Target marker: where the bar should reach.
                                        if v.target > 0 {
                                            Rectangle().fill(Theme.sub.opacity(0.6))
                                                .frame(width: 1.5, height: 13)
                                                .offset(x: geo.size.width * CGFloat(v.target) / CGFloat(maxSets))
                                        }
                                        Capsule().fill(Color(hex: v.group.color))
                                            .frame(width: max(7, geo.size.width * CGFloat(v.sets) / CGFloat(maxSets)), height: 7)
                                    }
                                }
                                .frame(height: 13)
                                Text("\(v.sets)").font(.num(14)).foregroundColor(Theme.txt).frame(width: 24, alignment: .trailing)
                                if v.target > 0 {
                                    Text(t("st.vol_" + v.status).uppercased())
                                        .font(.head(10, .semibold)).tracking(0.5)
                                        .foregroundColor(statusColor(v.status))
                                        .frame(width: 46, alignment: .leading)
                                }
                            }
                        }
                    }
                    Text(t("metric.muscle_vol_hint")).font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 8)
                }
            }
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "low":  return Theme.acc2
        case "high": return Theme.red
        default:     return Theme.good
        }
    }
}

// MARK: Resting HR & HRV trend
struct VitalsTrendCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let rhr = store.restingHRTrend()
        let hrv = store.hrvTrend()
        let stability = store.hrvStability()
        let show = rhr.status != "none" || hrv.status != "none" || stability != nil
        return Group {
            if show {
                Card {
                    InfoLbl(text: t("metric.vitals"), info: .vitals, color: Theme.red).padding(.bottom, 10)
                    if rhr.status != "none" { vitalRow(t("hk.cat.restHR"), rhr, unit: "bpm", info: .restingHR) }
                    if hrv.status != "none" {
                        Spacer().frame(height: 8)
                        vitalRow("HRV", hrv, unit: "ms", info: .hrv)
                    }
                    if let stability, let scale = store.infoScale(.hrvStability) {
                        Spacer().frame(height: 8)
                        HStack(spacing: 10) {
                            HStack(spacing: 2) {
                                Text(t("vit.stability").uppercased()).font(.head(10, .semibold)).tracking(1)
                                    .foregroundColor(Theme.sub).lineLimit(1).minimumScaleFactor(0.7)
                                InfoButton(id: .hrvStability, size: 16)
                            }
                            .frame(width: 96, alignment: .leading)
                            Text(String(format: "%.1f%%", stability)).font(.num(16)).foregroundColor(Theme.txt)
                            Spacer()
                            BandLabel(scale: scale, value: stability)
                        }
                    }
                }
            }
        }
    }

    private func vitalRow(_ label: String, _ tr: Store.VitalTrend, unit: String, info: InfoTopic) -> some View {
        let (icon, color) = statusStyle(tr.status)
        return HStack(spacing: 10) {
            HStack(spacing: 2) {
                Text(label.uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                    .lineLimit(1).minimumScaleFactor(0.7)
                InfoButton(id: info, size: 16)
            }
            .frame(width: 96, alignment: .leading)
            if let c = tr.current { Text("\(trimNum(c)) \(unit)").font(.num(16)).foregroundColor(Theme.txt) }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(t("trend." + tr.status)).font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(color)
        }
    }

    private func statusStyle(_ s: String) -> (String, Color) {
        switch s {
        case "improving": return ("arrow.up.right", Theme.good)
        case "declining": return ("arrow.down.right", Theme.red)
        default:          return ("equal", Theme.sub)
        }
    }
}

// MARK: VO2max estimate + HR zones
struct FitnessCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let vo2 = store.vo2maxEstimate()
        let zones = store.hrZones()
        let walking = store.infoValue(.walkingHR)
        let recovery = store.infoValue(.hrRecovery)
        return Group {
            if vo2 != nil || !zones.isEmpty {
                Card {
                    InfoLbl(text: t("metric.fitness"), info: .fitness, color: Theme.good).padding(.bottom, 10)
                    if let vo2, let scale = store.infoScale(.vo2max) {
                        let cls = scale.bands[scale.bandIndex(of: vo2.value)]
                        HStack(spacing: 4) {
                            Text("VO₂max").font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                            InfoButton(id: .vo2max, size: 18)
                            Spacer()
                            Text("\(trimNum(vo2.value))").font(.num(20)).foregroundColor(cls.tone.color)
                            Text("mL/kg·min").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                            if vo2.estimated {
                                Text(t("metric.estimated")).font(.head(10, .semibold)).tracking(0.5).foregroundColor(Theme.acc2)
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    .background(Theme.acc2.opacity(0.14)).clipShape(Capsule())
                            }
                        }
                        RangeBar(scale: scale, value: vo2.value).padding(.top, 6)
                        Text(t("band." + cls.key) + " · " + t("metric.vo2_norm"))
                            .font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 4)
                    }
                    let fitAge = store.fitnessAge()
                    let drift = store.lastDecoupling
                    if fitAge != nil || drift != nil {
                        HStack(spacing: 9) {
                            if let fitAge {
                                StatTile(label: t("metric.fitness_age"), value: "\(fitAge)", unit: t("metric.years"),
                                         valueColor: tone(.fitnessAge, Double(fitAge)), info: .fitnessAge)
                            }
                            if let drift {
                                StatTile(label: t("decoupling.title"), value: String(format: "%.1f", drift.value), unit: "%",
                                         valueColor: tone(.decoupling, drift.value), note: fmtDM(drift.date), info: .decoupling)
                            }
                        }
                        .padding(.top, 12)
                    }
                    if walking != nil || recovery != nil {
                        HStack(spacing: 9) {
                            if let walking {
                                StatTile(label: t("hk.cat.walkingHR"), value: "\(Int(walking.rounded()))", unit: "bpm",
                                         valueColor: Theme.txt, info: .walkingHR)
                            }
                            if let recovery {
                                StatTile(label: t("metric.hr_recovery"), value: "−\(Int(recovery.rounded()))", unit: "bpm",
                                         valueColor: tone(.hrRecovery, recovery), info: .hrRecovery)
                            }
                        }
                        .padding(.top, 12)
                    }
                    if !zones.isEmpty {
                        Spacer().frame(height: 12)
                        Text(t("metric.hr_zones").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 6)
                        VStack(spacing: 5) {
                            ForEach(zones) { z in
                                HStack(spacing: 8) {
                                    Text("Z\(z.index)").font(.head(10, .bold)).foregroundColor(zoneColor(z.index)).frame(width: 26, alignment: .leading)
                                    Capsule().fill(zoneColor(z.index)).frame(height: 6)
                                    Text("\(z.lower)–\(z.upper)").font(.num(12)).foregroundColor(Theme.txt).frame(width: 72, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func tone(_ topic: InfoTopic, _ v: Double) -> Color {
        guard let s = store.infoScale(topic) else { return Theme.txt }
        return s.bands[s.bandIndex(of: v)].tone.color
    }

    private func zoneColor(_ i: Int) -> Color {
        switch i {
        case 1: return Theme.blue
        case 2: return Theme.good
        case 3: return Theme.acc
        case 4: return Theme.acc2
        default: return Theme.red
        }
    }
}
