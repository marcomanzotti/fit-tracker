import SwiftUI
import Charts

/// A daily metric whose overview chart defaults to a readable weekly average
/// (last 2 months) and is expandable into a larger horizontally-scrollable view
/// with a day/week/month/year toggle. Tap a point/bar to see the exact value.
struct MetricChartCard: View {
    @EnvironmentObject var store: Store

    let title: String
    var info: String? = nil
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
                            Text(fmtTooltipValue(sel.value))
                                .font(.num(13)).foregroundColor(color)
                            Text("·").foregroundColor(Theme.sub).font(.system(size: 11))
                            Text(sel.date).font(.system(size: 11)).foregroundColor(Theme.sub)
                        }
                        Button { tap(); expanded = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                                .frame(width: 28, height: 28)
                                .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }.buttonStyle(PressableStyle())
                    }
                    .padding(.bottom, 8)
                    InteractiveMetricPlot(data: data, color: color, kind: kind,
                                          showPoints: false, selected: $selected)
                        .styledAxes().chartY(yDomain).frame(height: 150)
                }
                .sheet(isPresented: $expanded) {
                    ExpandedChartSheet(title: title, color: color, kind: kind,
                                       yDomain: yDomain, unit: unit, value: value)
                }
            }
        }
    }

    private func fmtTooltipValue(_ v: Double) -> String {
        if !unit.isEmpty { return "\(trimNum(v)) \(unit)" }
        if v >= 1000 { return "\(Int(v.rounded()))" }
        return trimNum(v)
    }
}

/// Interactive chart with tap/drag selection. Shows a vertical rule + dot on the
/// selected bucket; the parent card header displays the selected date + value.
struct InteractiveMetricPlot: View {
    let data: [Store.WeekPoint]
    let color: Color
    let kind: MetricChartCard.Kind
    var showPoints: Bool
    @Binding var selected: Store.WeekPoint?

    var body: some View {
        Chart(data) { p in
            let isSelected = selected?.id == p.id
            if kind == .bar {
                BarMark(x: .value("g", p.date), y: .value("v", p.value))
                    .foregroundStyle(isSelected ? color : color.opacity(0.55))
                    .cornerRadius(4)
            } else {
                LineMark(x: .value("g", p.date), y: .value("v", p.value))
                    .interpolationMethod(.catmullRom).foregroundStyle(color)
                AreaMark(x: .value("g", p.date), y: .value("v", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.22), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                if let sel = selected, sel.id == p.id {
                    RuleMark(x: .value("g", p.date))
                        .foregroundStyle(color.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    PointMark(x: .value("g", p.date), y: .value("v", p.value))
                        .foregroundStyle(color).symbolSize(36)
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                // A plain tap selects the nearest bucket (toggle off if re-tapped).
                // For scrubbing we require a deliberate long-press FIRST, then drag —
                // this lets a normal vertical scroll pass straight through the chart
                // instead of being captured the instant a finger touches it.
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onTapGesture { loc in
                        let x = loc.x - geo[proxy.plotAreaFrame].origin.x
                        if let date: String = proxy.value(atX: x) {
                            let pt = closestPoint(to: date)
                            if selected?.id == pt?.id { selected = nil } else { selected = pt }
                        }
                    }
                    .gesture(
                        LongPressGesture(minimumDuration: 0.18)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                if case .second(true, let drag?) = value {
                                    let x = drag.location.x - geo[proxy.plotAreaFrame].origin.x
                                    if let date: String = proxy.value(atX: x) {
                                        selected = closestPoint(to: date)
                                    }
                                }
                            }
                    )
            }
        }
    }

    private func closestPoint(to label: String) -> Store.WeekPoint? {
        // find the bucket whose label string is lexicographically closest
        data.min(by: { abs($0.date.compare(label).rawValue) < abs($1.date.compare(label).rawValue) })
    }
}

extension View {
    @ViewBuilder func chartY(_ domain: ClosedRange<Double>?) -> some View {
        if let domain { self.chartYScale(domain: domain) }
        else { self.chartYScale(domain: .automatic(includesZero: false)) }
    }
}

/// Full-screen expanded chart: day/week/month/year toggle + horizontally scrollable
/// plot with its own tap selection. Opened from a MetricChartCard.
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
                            HStack(spacing: 6) {
                                Text(fmtTooltipValue(sel.value))
                                    .font(.num(15)).foregroundColor(color)
                                Text("·").foregroundColor(Theme.sub)
                                Text(sel.date).font(.system(size: 12)).foregroundColor(Theme.sub)
                            }
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: 34, height: 34)
                    }
                }
                .padding(.top, 18)

                HStack(spacing: 6) {
                    ForEach(Store.ChartGranularity.allCases) { g in
                        let active = gran == g
                        Button { tap(); gran = g; selected = nil } label: {
                            Text(t("chart.gran." + g.rawValue).uppercased())
                                .font(.head(10, .semibold)).tracking(0.5)
                                .foregroundColor(active ? Theme.bg : Theme.sub)
                                .padding(.vertical, 7).padding(.horizontal, 14)
                                .background(active ? Theme.acc : Theme.c2)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(active ? Theme.acc : Theme.brd, lineWidth: 1))
                        }.buttonStyle(PressableStyle())
                    }
                }

                let data = store.metricSeries(value, granularity: gran)
                if data.count > 1 {
                    ScrollView(.horizontal, showsIndicators: true) {
                        InteractiveMetricPlot(data: data, color: color, kind: kind,
                                              showPoints: kind == .area, selected: $selected)
                            .styledAxes()
                            .chartY(yDomain)
                            .frame(width: max(UIScreen.main.bounds.width - 36,
                                              CGFloat(data.count) * 46),
                                   height: 320)
                            .padding(.trailing, 12)
                    }
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

    private func fmtTooltipValue(_ v: Double) -> String {
        if !unit.isEmpty { return "\(trimNum(v)) \(unit)" }
        if v >= 1000 { return "\(Int(v.rounded()))" }
        return trimNum(v)
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
                    InfoLbl(text: t("metric.muscle_vol"), info: "muscle_vol", color: Theme.acc2).padding(.bottom, 10)
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
        let show = rhr.status != "none" || hrv.status != "none"
        return Group {
            if show {
                Card {
                    InfoLbl(text: t("metric.vitals"), info: "vitals", color: Theme.red).padding(.bottom, 10)
                    if rhr.status != "none" { vitalRow(t("hk.cat.restHR"), rhr, unit: "bpm") }
                    if hrv.status != "none" {
                        Spacer().frame(height: 8)
                        vitalRow("HRV", hrv, unit: "ms")
                    }
                }
            }
        }
    }

    private func vitalRow(_ label: String, _ tr: Store.VitalTrend, unit: String) -> some View {
        let (icon, color) = statusStyle(tr.status)
        return HStack(spacing: 10) {
            Text(label.uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                .frame(width: 70, alignment: .leading)
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
        return Group {
            if vo2 != nil || !zones.isEmpty {
                Card {
                    InfoLbl(text: t("metric.fitness"), info: "fitness", color: Theme.good).padding(.bottom, 10)
                    if let vo2 {
                        HStack {
                            Text("VO₂max").font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                            Spacer()
                            Text("\(trimNum(vo2.value))").font(.num(20)).foregroundColor(Theme.good)
                            Text("mL/kg·min").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                            if vo2.estimated {
                                Text(t("metric.estimated")).font(.head(10, .semibold)).tracking(0.5).foregroundColor(Theme.acc2)
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    .background(Theme.acc2.opacity(0.14)).clipShape(Capsule())
                            }
                        }
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
