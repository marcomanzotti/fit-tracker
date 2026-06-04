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
                        }.buttonStyle(.plain)
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

/// Non-interactive chart body for use in expanded sheet (has its own selection).
struct MetricPlot: View {
    let data: [Store.WeekPoint]
    let color: Color
    let kind: MetricChartCard.Kind
    var showPoints = false

    var body: some View {
        Chart(data) { p in
            if kind == .bar {
                BarMark(x: .value("g", p.date), y: .value("v", p.value))
                    .foregroundStyle(color.opacity(0.65)).cornerRadius(4)
            } else {
                LineMark(x: .value("g", p.date), y: .value("v", p.value))
                    .interpolationMethod(.catmullRom).foregroundStyle(color)
                AreaMark(x: .value("g", p.date), y: .value("v", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.22), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                if showPoints {
                    PointMark(x: .value("g", p.date), y: .value("v", p.value))
                        .foregroundStyle(color).symbolSize(18)
                }
            }
        }
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
                    Button { tap(); dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
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
                        }.buttonStyle(.plain)
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
    }

    private func fmtTooltipValue(_ v: Double) -> String {
        if !unit.isEmpty { return "\(trimNum(v)) \(unit)" }
        if v >= 1000 { return "\(Int(v.rounded()))" }
        return trimNum(v)
    }
}
