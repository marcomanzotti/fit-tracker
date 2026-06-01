import SwiftUI

// MARK: - Activity picker (strength plans + cardio activities synced from phone)
struct ActivityPickerView: View {
    @EnvironmentObject var link: WatchLink
    @EnvironmentObject var workout: WorkoutManager

    private var strength: [WatchActivity] { link.activities.filter { $0.kindValue == .strength } }
    private var cardio: [WatchActivity] { link.activities.filter { $0.kindValue == .cardio } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                titleRow

                if link.activities.isEmpty {
                    emptyState
                } else {
                    if !strength.isEmpty {
                        sectionLabel(wt("strength"))
                        ForEach(strength) { row($0) }
                    }
                    if !cardio.isEmpty {
                        sectionLabel(wt("cardio")).padding(.top, 4)
                        ForEach(cardio) { row($0) }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 0) {
            Text("FIT TR").foregroundColor(T.txt)
            Text("A").foregroundColor(T.acc)
            Text("CKER").foregroundColor(T.txt)
        }
        .font(.head(15, .bold)).tracking(0.5)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(T.sub)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen2").font(.system(size: 26)).foregroundColor(T.sub)
            Text(link.hasContext ? wt("no_act") : wt("waiting"))
                .font(.system(size: 12)).foregroundColor(T.sub).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private func row(_ a: WatchActivity) -> some View {
        Button {
            wkTap()
            Task { await workout.start(a) }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: watchIcon(for: a))
                    .font(.system(size: 16, weight: .bold)).foregroundColor(T.bg)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: a.color))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(a.name).font(.system(size: 15, weight: .semibold)).foregroundColor(T.txt)
                        .lineLimit(1)
                    if !a.sub.isEmpty {
                        Text(a.sub).font(.system(size: 10)).foregroundColor(T.sub).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.c1)
            .clipShape(RoundedRectangle(cornerRadius: T.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: T.radius, style: .continuous).stroke(T.brd, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live workout (paged: metrics / controls)
struct LiveWorkoutView: View {
    @EnvironmentObject var workout: WorkoutManager

    private var accent: Color { Color(hex: workout.result?.color ?? "ffe000") }

    var body: some View {
        TabView {
            metricsPage
            controlsPage
        }
        .tabViewStyle(.verticalPage)
    }

    private var metricsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(wkClock(Int(workout.elapsed)))
                    .font(.num(34)).foregroundColor(T.acc)
                    .frame(maxWidth: .infinity, alignment: .leading)

                metric(icon: "heart.fill", color: T.red,
                       value: workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "—", unit: wt("bpm"))
                metric(icon: "flame.fill", color: T.acc2,
                       value: "\(Int(workout.activeCalories.rounded()))", unit: wt("kcal"))
                if workout.distanceMeters > 0 {
                    metric(icon: "location.fill", color: T.good,
                           value: trimKm(workout.distanceMeters / 1000), unit: wt("km"))
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func metric(icon: String, color: Color, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
                .frame(width: 18)
            Text(value).font(.num(26)).foregroundColor(T.txt)
            Text(unit).font(.system(size: 11, weight: .semibold)).foregroundColor(T.sub)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(T.c1)
        .clipShape(RoundedRectangle(cornerRadius: T.radius, style: .continuous))
    }

    private var controlsPage: some View {
        VStack(spacing: 12) {
            Button {
                wkTap(); workout.togglePause()
            } label: {
                Label(workout.paused ? wt("resume") : wt("pause"),
                      systemImage: workout.paused ? "play.fill" : "pause.fill")
                    .font(.head(15, .bold)).foregroundColor(T.bg)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(T.acc)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                wkSuccess(); workout.end()
            } label: {
                Label(wt("end"), systemImage: "stop.fill")
                    .font(.head(15, .bold)).foregroundColor(T.red)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(T.red.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(T.red.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }

    private func trimKm(_ v: Double) -> String { String(format: "%.2f", v) }
}

// MARK: - Summary (auto-sends to the phone, then dismisses)
struct SummaryView: View {
    @EnvironmentObject var workout: WorkoutManager
    @State private var sent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(wt("summary").uppercased()).font(.head(12, .semibold)).tracking(1.5).foregroundColor(T.sub)
                    .frame(maxWidth: .infinity)

                if let r = workout.result {
                    Text(r.name).font(.head(16, .bold)).foregroundColor(Color(hex: r.color))
                        .frame(maxWidth: .infinity)

                    stat(wt("time"), wkClock(r.durationSec), T.acc)
                    if let hr = r.avgHR { stat("\(wt("hr")) \(wt("avg"))", "\(hr) \(wt("bpm"))", T.red) }
                    if let mx = r.maxHR { stat("\(wt("hr")) \(wt("max"))", "\(mx) \(wt("bpm"))", T.red) }
                    if let k = r.activeKcal { stat(wt("cal"), "\(k) \(wt("kcal"))", T.acc2) }
                    if let km = r.distanceKm { stat(wt("dist"), String(format: "%.2f %@", km, wt("km")), T.good) }
                }

                if sent {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(T.good)
                        Text(wt("saved")).font(.system(size: 12, weight: .semibold)).foregroundColor(T.good)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 4)
                }

                Button {
                    wkTap(); workout.reset()
                } label: {
                    Text((sent ? wt("end") : wt("save")).uppercased())
                        .font(.head(14, .bold)).tracking(1).foregroundColor(T.bg)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(T.acc)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, 6).padding(.bottom, 8)
        }
        .onAppear {
            // Send once, automatically, as soon as the summary is built.
            guard !sent else { return }
            workout.sendToPhone()
            sent = true
            wkSuccess()
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label.uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(T.sub)
            Spacer()
            Text(value).font(.num(16)).foregroundColor(color)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(T.c1)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
