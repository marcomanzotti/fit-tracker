import Charts
import MapKit
import SwiftUI

// MARK: - What the device measured, editable
/// Every extra metric of a session, measured or typed. A typed value wins and
/// survives every sync; clearing it brings the device's back. Brand scores are
/// listed apart: each maker computes them its own way.
struct DeviceMetricsCard: View {
    @Binding var session: WorkoutSession
    @State private var added: [WorkoutMetric] = []

    private var rows: [WorkoutMetric] {
        let shown = session.shownMetrics
        return shown + added.filter { !shown.contains($0) }
    }

    var body: some View {
        let rows = rows
        let missing = WorkoutMetric.allCases.filter { !rows.contains($0) }
        Card {
            HStack {
                Lbl(text: t("dev.title"), color: Theme.acc2)
                Spacer()
                if let src = session.source {
                    Text(src).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub).lineLimit(1)
                }
            }
            .padding(.bottom, 6)
            Text(t(rows.isEmpty ? "dev.empty" : "dev.note")).font(.system(size: 11)).foregroundColor(Theme.sub)
                .padding(.bottom, 10)
            ForEach(rows.filter { !$0.isDeviceScore }) { MetricRow(session: $session, metric: $0) }
            let scores = rows.filter(\.isDeviceScore)
            if !scores.isEmpty {
                Lbl(text: t("dev.scores")).padding(.top, 12)
                Text(t("dev.scores_note")).font(.system(size: 10)).foregroundColor(Theme.sub).padding(.vertical, 4)
                ForEach(scores) { MetricRow(session: $session, metric: $0) }
            }
            if !missing.isEmpty {
                Menu {
                    ForEach(missing) { m in Button(t(m.labelKey)) { added.append(m) } }
                } label: {
                    Label(t("dev.add"), systemImage: "plus").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.sub).padding(.vertical, 8).padding(.horizontal, 14)
                        .frame(minHeight: 38).chrome(9)
                }
                .padding(.top, 10)
            }
        }
    }
}

private struct MetricRow: View {
    @Binding var session: WorkoutSession
    let metric: WorkoutMetric
    @State private var text = ""
    /// What the box showed on opening: setting it is not an edit.
    @State private var initial: String?

    private var device: Double? { session.deviceMetric(metric) }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t(metric.labelKey)).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.txt)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(provenance).font(.system(size: 10)).foregroundColor(text.isEmpty ? Theme.sub : Theme.acc2)
            }
            Spacer(minLength: 4)
            TextField("", text: $text, prompt: Text(device.map(metric.format) ?? "—").foregroundColor(Theme.sub))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .foregroundColor(Theme.txt).font(.system(size: 15, weight: .medium))
                .padding(.vertical, 8).padding(.horizontal, 10)
                .frame(width: 92).chrome(9)
            Text(metric.unit).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
                .frame(width: 54, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
            Button { tap(); text = "" } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.sub).frame(width: 28, height: Theme.minTapTarget)
            }
            .accessibilityLabel(t("dev.reset"))
            .opacity(text.isEmpty ? 0 : 1).disabled(text.isEmpty)
        }
        .onAppear {
            guard initial == nil else { return }
            let shown = session.metricOverrides?[metric.rawValue].map(metric.format) ?? ""
            initial = shown
            text = shown
        }
        .onChange(of: text) { new in
            guard new != initial else { return }
            initial = nil
            if new.isEmpty { session.setTyped(metric, nil); return }
            // Half-typed input ("1.", "-") keeps the last valid value.
            if let v = Double(new.replacingOccurrences(of: ",", with: ".")), v.isFinite { session.setTyped(metric, v) }
        }
    }

    private var provenance: String {
        if text.isEmpty { return device == nil ? t("dev.none") : t("dev.measured") }
        return device.map { "\(t("dev.typed")) · \(t("dev.device")) \(metric.format($0))" } ?? t("dev.typed")
    }
}

// MARK: - Series read from Health
/// Heart rate over time, time in the app's zones, the route and per-kilometre
/// splits, read from Health when the session is opened. Zones are the app's own,
/// from the profile, so they compare across devices.
struct WorkoutSeriesCard: View {
    let uuid: String
    let zones: [Store.HRZone]
    let paceIsSpeed: Bool
    @State private var series: WorkoutSeries?
    @State private var loaded = false

    private static let zoneColors = [Theme.blue, Theme.good, Theme.acc, Theme.acc2, Theme.red]

    var body: some View {
        Card {
            Lbl(text: t("series.title"), color: Theme.acc2).padding(.bottom, 10)
            if !loaded {
                ProgressView().tint(Theme.sub).frame(maxWidth: .infinity)
            } else if let s = series, !s.isEmpty {
                content(s)
            } else {
                Text(t("series.none")).font(.system(size: 11)).foregroundColor(Theme.sub)
            }
        }
        .task(id: uuid) {
            series = await HealthKitManager.shared.workoutSeries(uuid: uuid)
            loaded = true
        }
    }

    @ViewBuilder
    private func content(_ s: WorkoutSeries) -> some View {
        if !s.heartRate.isEmpty {
            heartRateChart(s)
            zoneBars(s).padding(.top, 12)
        }
        if s.route.count > 1, #available(iOS 17.0, *) {
            RouteMap(route: s.route).padding(.top, 14)
        }
        if !s.splits.isEmpty { splitList(s.splits).padding(.top, 14) }
    }

    private func heartRateChart(_ s: WorkoutSeries) -> some View {
        let values = s.heartRate.map(\.value)
        let low = (values.min() ?? 60) - 5, high = (values.max() ?? 180) + 5
        return Chart(s.heartRate) { p in
            LineMark(x: .value("t", p.time), y: .value("bpm", p.value))
                .foregroundStyle(Theme.red).interpolationMethod(.monotone)
        }
        .chartYScale(domain: low...high)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.c3)
                AxisValueLabel(format: .dateTime.hour().minute()).foregroundStyle(Theme.sub)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Theme.c3)
                AxisValueLabel().foregroundStyle(Theme.sub)
            }
        }
        .frame(height: 140)
        .accessibilityLabel(t("series.hr"))
    }

    @ViewBuilder
    private func zoneBars(_ s: WorkoutSeries) -> some View {
        if zones.count == 5 {
            let bounds = zones.map(\.lower) + [zones[4].upper]
            let seconds = hrZoneSeconds(s.heartRate.map { ($0.time, $0.value) }, end: s.end, bounds: bounds)
            let total = max(1, seconds.reduce(0, +))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text("Z\(i + 1)").font(.num(11)).foregroundColor(Self.zoneColors[i]).frame(width: 22, alignment: .leading)
                        Bar(value: seconds[i] / total, gradient: [Self.zoneColors[i], Self.zoneColors[i]], height: 6)
                        Text(fmtClock(Int(seconds[i]))).font(.system(size: 10, weight: .medium)).foregroundColor(Theme.sub)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func splitList(_ splits: [WorkoutSplit]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Lbl(text: t("series.splits"))
            ForEach(splits) { split in
                HStack {
                    Text("\(split.index) km").font(.system(size: 12, weight: .medium)).foregroundColor(Theme.txt)
                        .frame(width: 52, alignment: .leading)
                    Text(paceIsSpeed ? "\(trimNum((3600 / split.seconds * 10).rounded() / 10)) km/h" : "\(fmtClock(Int(split.seconds))) /km")
                        .font(.num(13)).foregroundColor(Theme.acc)
                    Spacer()
                    if let hr = split.avgHR {
                        Text("\(Int(hr.rounded())) bpm").font(.system(size: 11)).foregroundColor(Theme.sub)
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
private struct RouteMap: View {
    let route: [(lat: Double, lon: Double)]

    var body: some View {
        let coordinates = route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        Map(initialPosition: .automatic) {
            MapPolyline(coordinates: coordinates).stroke(Theme.acc, lineWidth: 3)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .accessibilityLabel(t("series.route"))
    }
}
