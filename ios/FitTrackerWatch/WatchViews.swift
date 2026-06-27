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

// MARK: - Live workout router (strength logging vs. cardio metrics)
struct LiveWorkoutView: View {
    @EnvironmentObject var workout: WorkoutManager
    var body: some View {
        ZStack {
            if workout.exLogs.isEmpty {
                CardioLiveView()
            } else {
                StrengthLiveView()
            }
            if workout.locked { LockOverlay() }
        }
    }
}

// MARK: - Shared live metric pill
private func liveMetric(icon: String, color: Color, value: String, unit: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: icon).font(.system(size: 13)).foregroundColor(color).frame(width: 18)
        Text(value).font(.num(26)).foregroundColor(T.txt)
        Text(unit).font(.system(size: 11, weight: .semibold)).foregroundColor(T.sub)
        Spacer(minLength: 0)
    }
    .padding(.vertical, 8).padding(.horizontal, 10)
    .frame(maxWidth: .infinity)
    .background(T.c1)
    .clipShape(RoundedRectangle(cornerRadius: T.radius, style: .continuous))
}

// MARK: - Workout controls (pause/resume · lock · restart · end)
struct ControlsPage: View {
    @EnvironmentObject var workout: WorkoutManager
    @State private var confirmRestart = false
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button { wkTap(); workout.togglePause() } label: {
                    Label(workout.paused ? wt("resume") : wt("pause"),
                          systemImage: workout.paused ? "play.fill" : "pause.fill")
                        .font(.head(15, .bold)).foregroundColor(T.bg)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(T.acc)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    smallControl(wt("lock"), "lock.fill", T.blue) { wkTap(); workout.toggleLock() }
                    smallControl(wt("restart"), "arrow.counterclockwise", T.acc2) { wkTap(); confirmRestart = true }
                }

                Button { wkSuccess(); workout.end() } label: {
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
        .alert(wt("restart"), isPresented: $confirmRestart) {
            Button(wt("end"), role: .destructive) { workout.restart() }
            Button(wt("done"), role: .cancel) {}
        }
    }
    private func smallControl(_ title: String, _ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(color)
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundColor(T.sub)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(T.c1)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cardio live (paged: metrics / controls)
struct CardioLiveView: View {
    @EnvironmentObject var workout: WorkoutManager
    var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(wkClock(Int(workout.elapsed)))
                        .font(.num(34)).foregroundColor(workout.paused ? T.sub : T.acc)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    liveMetric(icon: "heart.fill", color: T.red,
                               value: workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "—", unit: wt("bpm"))
                    liveMetric(icon: "flame.fill", color: T.acc2,
                               value: "\(Int(workout.activeCalories.rounded()))", unit: wt("kcal"))
                    if workout.distanceMeters > 0 {
                        liveMetric(icon: "location.fill", color: T.good,
                                   value: String(format: "%.2f", workout.distanceMeters / 1000), unit: wt("km"))
                    }
                }
                .padding(.horizontal, 4)
            }
            ControlsPage()
        }
        .tabViewStyle(.page)
    }
}

// MARK: - Strength live (scroll exercises · tap a number · edit with the Crown)
struct StrengthLiveView: View {
    @EnvironmentObject var workout: WorkoutManager
    @State private var edit: EditTarget?
    @State private var hold: HoldTarget?

    var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    metricsHeader
                    ForEach(workout.exLogs.indices, id: \.self) { ex in
                        exerciseCard(ex)
                    }
                }
                .padding(.horizontal, 4).padding(.bottom, 6)
            }
            ControlsPage()
        }
        .tabViewStyle(.page)
        .sheet(item: $edit) { target in
            NumberCrownEditor(
                title: "\(target.exName) · \(wt("set")) \(target.set + 1)",
                subtitle: target.field == .reps ? wt("reps") : "\(wt("weight")) (kg)",
                value: target.current,
                step: target.field == .reps ? 1 : 0.5
            ) { v in
                if target.field == .reps { workout.setReps(target.ex, target.set, v) }
                else { workout.setWeight(target.ex, target.set, v) }
            }
        }
        // Countdown timer for an isometric hold: counts DOWN from the set's target
        // seconds and writes the actual hold back on stop.
        .sheet(item: $hold) { target in
            HoldTimerSheet(
                title: "\(target.exName) · \(wt("set")) \(target.set + 1)",
                seconds: target.current
            ) { actual in
                workout.setSeconds(target.ex, target.set, actual)
            }
        }
    }

    private var metricsHeader: some View {
        HStack(spacing: 8) {
            Text(wkClock(Int(workout.elapsed))).font(.num(20)).foregroundColor(workout.paused ? T.sub : T.acc)
            Spacer()
            Image(systemName: "heart.fill").font(.system(size: 11)).foregroundColor(T.red)
            Text(workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "—").font(.num(16)).foregroundColor(T.txt)
            Image(systemName: "flame.fill").font(.system(size: 11)).foregroundColor(T.acc2)
            Text("\(Int(workout.activeCalories.rounded()))").font(.num(16)).foregroundColor(T.txt)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(T.c1).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func exerciseCard(_ ex: Int) -> some View {
        let log = workout.exLogs[ex]
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                if log.timed { Image(systemName: "timer").font(.system(size: 11, weight: .bold)).foregroundColor(T.acc2) }
                Text(log.name).font(.system(size: 14, weight: .bold)).foregroundColor(T.txt).lineLimit(2)
            }
            if log.timed {
                ForEach(log.setSeconds.indices, id: \.self) { s in timedRow(ex, s, log.name) }
            } else {
                ForEach(log.setReps.indices, id: \.self) { s in repsRow(ex, s, log.name) }
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.c1)
        .clipShape(RoundedRectangle(cornerRadius: T.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: T.radius, style: .continuous).stroke(T.brd, lineWidth: 1))
    }

    // Classic reps × weight row.
    private func repsRow(_ ex: Int, _ s: Int, _ name: String) -> some View {
        HStack(spacing: 6) {
            Text("\(s + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(T.sub).frame(width: 16)
            numberPill(value: workout.effReps(ex, s), entered: workout.isRepsEntered(ex, s)) {
                edit = EditTarget(ex: ex, set: s, field: .reps, exName: name, current: workout.effReps(ex, s))
            }
            Text("×").font(.system(size: 13)).foregroundColor(T.sub)
            numberPill(value: workout.effWeight(ex, s), entered: workout.isWeightEntered(ex, s)) {
                edit = EditTarget(ex: ex, set: s, field: .weight, exName: name, current: workout.effWeight(ex, s))
            }
            Text("kg").font(.system(size: 10)).foregroundColor(T.sub)
            Spacer(minLength: 0)
        }
    }

    // Isometric hold row: tap the time pill to run a countdown timer for that set.
    private func timedRow(_ ex: Int, _ s: Int, _ name: String) -> some View {
        let entered = workout.isSecondsEntered(ex, s)
        return HStack(spacing: 6) {
            Text("\(s + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(T.sub).frame(width: 16)
            Button { wkTap(); hold = HoldTarget(ex: ex, set: s, exName: name, current: workout.effSeconds(ex, s)) } label: {
                HStack(spacing: 4) {
                    Image(systemName: entered ? "checkmark" : "play.fill").font(.system(size: 11, weight: .bold))
                    Text("\(fmtNum(workout.effSeconds(ex, s)))s").font(.num(17))
                }
                .foregroundColor(entered ? T.txt : T.acc2)
                .frame(minWidth: 76, minHeight: 34)
                .background(entered ? T.acc.opacity(0.14) : T.c2)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(entered ? T.acc : T.brd, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }

    private func numberPill(value: Double, entered: Bool, _ tapAction: @escaping () -> Void) -> some View {
        Button { wkTap(); tapAction() } label: {
            Text(fmtNum(value))
                .font(.num(17)).foregroundColor(entered ? T.txt : T.sub)
                .frame(minWidth: 44, minHeight: 34)
                .background(entered ? T.acc.opacity(0.14) : T.c2)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(entered ? T.acc : T.brd, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Crown number editor (sheet)
enum EditField { case reps, weight }
struct EditTarget: Identifiable {
    let id = UUID()
    let ex: Int; let set: Int; let field: EditField
    let exName: String; let current: Double
}

struct NumberCrownEditor: View {
    let title: String
    let subtitle: String
    @State var value: Double
    let step: Double
    var onDone: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(T.sub)
                .multilineTextAlignment(.center).lineLimit(2)
            Text(subtitle.uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(T.sub)
            Text(fmtNum(value)).font(.num(44)).foregroundColor(T.acc)
                .focusable(true)
                .digitalCrownRotation($value, from: 0, through: 2000, by: step,
                                      sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            HStack(spacing: 10) {
                stepButton("minus") { value = max(0, value - step) }
                stepButton("plus") { value += step }
            }
            Button { wkSuccess(); onDone(value); dismiss() } label: {
                Text(wt("done").uppercased()).font(.head(13, .bold)).tracking(1).foregroundColor(T.bg)
                    .frame(maxWidth: .infinity, minHeight: 42).background(T.acc)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button { wkTap(); action() } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(T.txt)
                .frame(width: 52, height: 40).background(T.c2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Isometric hold countdown timer
/// Target for the hold sheet: which set, and its starting (target) seconds.
struct HoldTarget: Identifiable {
    let id = UUID()
    let ex: Int; let set: Int
    let exName: String; let current: Double
}

/// A countdown stopwatch for an isometric hold (plank, wall sit). It counts DOWN
/// from the set's target seconds with a big ring; the crown lets you adjust the
/// target before starting. A short haptic ticks the last 3 seconds and a success
/// haptic fires at zero. Whatever time actually elapsed when the user stops (or
/// when the countdown completes) is written back as the logged hold.
struct HoldTimerSheet: View {
    let title: String
    @State var seconds: Double          // target / remaining bound to the crown before start
    var onStop: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var target: Double = 0
    @State private var remaining: Double = 0
    @State private var running = false
    @State private var finished = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsed: Double { max(0, target - remaining) }

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(T.sub)
                .multilineTextAlignment(.center).lineLimit(2)

            ZStack {
                Circle().stroke(T.c3, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: target > 0 ? CGFloat(remaining / target) : 0)
                    .stroke(finished ? T.good : T.acc2, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: remaining)
                VStack(spacing: 0) {
                    Text("\(Int(running || finished ? remaining : seconds))")
                        .font(.num(40)).foregroundColor(finished ? T.good : T.acc2)
                    Text("SEC").font(.head(9, .semibold)).tracking(2).foregroundColor(T.sub)
                }
            }
            .frame(width: 104, height: 104)
            .focusable(!running)
            .digitalCrownRotation($seconds, from: 5, through: 600, by: 5,
                                  sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .padding(.vertical, 2)

            if running {
                Button { wkTap(); stop(elapsed) } label: {
                    Text(wt("stop").uppercased()).font(.head(13, .bold)).tracking(1).foregroundColor(T.red)
                        .frame(maxWidth: .infinity, minHeight: 42).background(T.red.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }.buttonStyle(.plain)
            } else {
                Button { wkSuccess(); start() } label: {
                    Text((finished ? wt("save") : wt("start")).uppercased())
                        .font(.head(13, .bold)).tracking(1).foregroundColor(T.bg)
                        .frame(maxWidth: .infinity, minHeight: 42).background(finished ? T.good : T.acc)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .onReceive(tick) { _ in countdown() }
    }

    private func start() {
        if finished { onStop(target); dismiss(); return }
        target = max(1, seconds)
        remaining = target
        running = true
        finished = false
        wkSuccess()
    }

    private func countdown() {
        guard running else { return }
        remaining = max(0, remaining - 1)
        if remaining <= 3 && remaining > 0 { wkTap() }
        if remaining == 0 {
            running = false
            finished = true
            wkSuccess()
            // Auto-log the full target hold; the user can still hit Save to confirm.
            onStop(target)
        }
    }

    /// Stopped early: log the time actually held (at least 1s) and close.
    private func stop(_ held: Double) {
        running = false
        onStop(max(1, held.rounded()))
        dismiss()
    }
}

// MARK: - Lock overlay (swipe to unlock, Apple-Workout style)
struct LockOverlay: View {
    @EnvironmentObject var workout: WorkoutManager
    @State private var drag: CGFloat = 0
    var body: some View {
        ZStack {
            T.bg.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 30)).foregroundColor(T.acc)
                Text(wt("swipe_unlock")).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(T.sub).multilineTextAlignment(.center)
                Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold)).foregroundColor(T.acc2)
                    .offset(x: drag)
            }
            .padding()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in drag = max(0, min(90, v.translation.width)) }
                .onEnded { v in
                    if v.translation.width > 70 { wkSuccess(); workout.toggleLock() }
                    drag = 0
                }
        )
    }
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
