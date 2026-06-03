import SwiftUI
import Charts

/// A daily metric whose overview chart should default to a readable weekly average
/// (last 3 months) and be expandable into a larger, horizontally-scrollable view
/// with a day/week/month/year toggle. Shared by every Overview metric so the
/// behaviour is identical everywhere a daily axis would otherwise crowd.
struct MetricChartCard: View {
    @EnvironmentObject var store: Store

    let title: String
    var info: String? = nil
    let color: Color
    var kind: Kind = .area
    /// 0 / 100-style fixed Y domain (e.g. sleep score); nil = auto, excludes zero.
    var yDomain: ClosedRange<Double>? = nil
    /// Pulls the metric out of a day (nil = no value that day).
    let value: (DailyEntry) -> Double?

    enum Kind { case area, bar }

    @State private var expanded = false

    var body: some View {
        // Overview default: weekly average over the last 3 months.
        let data = store.metricSeries(value, granularity: .week, months: 3)
        return Group {
            if data.count > 1 {
                Card {
                    HStack(spacing: 4) {
                        Lbl(text: title)
                        if let info { InfoButton(id: info) }
                        Spacer()
                        Button { tap(); expanded = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                                .frame(width: 28, height: 28)
                                .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)
                    MetricPlot(data: data, color: color, kind: kind, showPoints: false)
                        .styledAxes().chartY(yDomain).frame(height: 150)
                }
                .sheet(isPresented: $expanded) {
                    ExpandedChartSheet(title: title, color: color, kind: kind, yDomain: yDomain, value: value)
                }
            }
        }
    }
}

/// The chart body shared by the overview card and its expanded sheet — a line+area
/// or bar plot over time-bucketed points.
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

extension View {
    /// Apply a fixed Y domain when given, otherwise an auto domain that excludes zero
    /// (so flat trends still read as a band, not a line pinned to the axis).
    @ViewBuilder func chartY(_ domain: ClosedRange<Double>?) -> some View {
        if let domain { self.chartYScale(domain: domain) }
        else { self.chartYScale(domain: .automatic(includesZero: false)) }
    }
}

/// Full-screen expanded chart: a day/week/month/year toggle plus a horizontally
/// scrollable plot, so long histories stay legible. Opened from a MetricChartCard.
struct ExpandedChartSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let title: String
    let color: Color
    let kind: MetricChartCard.Kind
    let yDomain: ClosedRange<Double>?
    let value: (DailyEntry) -> Double?

    @State private var gran: Store.ChartGranularity = .week

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title.uppercased()).font(.head(18, .bold)).tracking(1).foregroundColor(Theme.txt)
                    Spacer()
                    Button { tap(); dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                    }
                }
                .padding(.top, 18)

                // Granularity toggle (day / week / month / year).
                HStack(spacing: 6) {
                    ForEach(Store.ChartGranularity.allCases) { g in
                        let active = gran == g
                        Button { tap(); gran = g } label: {
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
                    // Horizontal scroll: give each bucket a fixed width so a long
                    // history is pannable rather than crushed into the screen.
                    ScrollView(.horizontal, showsIndicators: true) {
                        MetricPlot(data: data, color: color, kind: kind, showPoints: kind == .area)
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
}
