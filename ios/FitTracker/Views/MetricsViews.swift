import SwiftUI

// MARK: - Phase 3 metric cards (Stats overview)
// Read-only insight cards built on the Store metrics in Metrics.swift. Each shows
// only when it has data, so an empty profile never sees a wall of dashes.

// MARK: Weekly sets per muscle group
struct MuscleVolumeCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let vols = store.weeklyMuscleVolume()
        let maxSets = max(1, vols.map { $0.sets }.max() ?? 1)
        return Group {
            if !vols.isEmpty {
                Card {
                    InfoLbl(text: t("metric.muscle_vol"), info: "muscle_vol", color: Theme.acc2).padding(.bottom, 10)
                    VStack(spacing: 8) {
                        ForEach(vols) { v in
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: v.group.color)).frame(width: 8, height: 8)
                                Text(t(v.group.labelKey)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.txt)
                                    .frame(width: 92, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.c2).frame(height: 7)
                                        Capsule().fill(Color(hex: v.group.color))
                                            .frame(width: max(7, geo.size.width * CGFloat(v.sets) / CGFloat(maxSets)), height: 7)
                                    }
                                }
                                .frame(height: 7)
                                Text("\(v.sets)").font(.num(14)).foregroundColor(Theme.txt).frame(width: 24, alignment: .trailing)
                            }
                        }
                    }
                    Text(t("metric.muscle_vol_hint")).font(.system(size: 9)).foregroundColor(Theme.sub).padding(.top, 8)
                }
            }
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
                            Text("mL/kg·min").font(.system(size: 9, weight: .semibold)).foregroundColor(Theme.sub)
                            if vo2.estimated {
                                Text(t("metric.estimated")).font(.head(8, .semibold)).tracking(0.5).foregroundColor(Theme.acc2)
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    .background(Theme.acc2.opacity(0.14)).clipShape(Capsule())
                            }
                        }
                    }
                    if !zones.isEmpty {
                        Spacer().frame(height: 12)
                        Text(t("metric.hr_zones").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
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
