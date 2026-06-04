import SwiftUI

enum Tab: String, CaseIterable {
    case home, allena, corpo, nutri, stats
    var label: String {
        switch self {
        case .home: return t("nav.home"); case .allena: return t("nav.train")
        case .corpo: return t("nav.body"); case .nutri: return t("nav.nutrition")
        case .stats: return t("nav.stats")
        }
    }
    var sub: String {
        switch self {
        case .home: return t("sub.home"); case .allena: return t("sub.train")
        case .corpo: return t("sub.body"); case .nutri: return t("sub.nutrition")
        case .stats: return t("sub.stats")
        }
    }
    /// Bottom-bar glyph. Chosen so no icon is reused elsewhere in the app
    /// (section headers keep dumbbell.fill / fork.knife, which stay distinct).
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .allena: return "figure.strengthtraining.traditional"
        case .corpo: return "figure.arms.open"
        case .nutri: return "carrot.fill"
        case .stats: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var timer: RestTimer
    @EnvironmentObject var toast: ToastCenter
    @EnvironmentObject var activeWorkout: ActiveWorkout
    @State private var tab: Tab = .home
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(tab: tab) { showSettings = true }
                ScrollView(.vertical) {
                    VStack(spacing: 11) {
                        switch tab {
                        case .home:   HomeView(tab: $tab)
                        case .allena: WorkoutView()
                        case .corpo:  BodyView()
                        case .nutri:  NutritionView()
                        case .stats:  StatsView()
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 130)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            VStack(spacing: 8) {
                // "Workout in progress" strip — tapping it jumps to the Train tab
                // where LiveWorkoutView is already displayed. Shown whenever a
                // workout is active AND the user is not already on the Train tab.
                if activeWorkout.isActive && tab != .allena {
                    ActiveWorkoutStrip { tab = .allena }
                }
                if timer.active { TimerStrip() }
                NavBar(tab: $tab)
            }
        }
        .overlay(alignment: .top) {
            if let m = toast.message {
                ToastView(text: m)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toast.message)
        .sheet(isPresented: $showSettings) { SettingsView(store: store) }
        .onAppear { if store.prefs.healthKitEnabled { store.syncHealth(completion: healthToast) } }
        // Re-sync Health (daily metrics + workouts from any paired watch) every
        // time the app returns to the foreground, so a session recorded on a
        // Garmin/Fitbit/etc. shows up without a manual refresh.
        .onChange(of: scenePhase) { phase in
            if phase == .active, store.prefs.healthKitEnabled { store.syncHealth(completion: healthToast) }
        }
    }

    /// Quietly confirm only when new workouts actually came in from a watch, so
    /// a routine foreground sync with nothing new stays silent.
    private func healthToast(ok: Bool, imported: Int, sources: [String]) {
        guard ok, imported > 0 else { return }
        let src = sources.isEmpty ? "" : " · " + sources.joined(separator: ", ")
        toast.show("\(imported) \(t("hk.imported_n"))\(src)")
    }
}

// MARK: - Header
struct HeaderBar: View {
    @EnvironmentObject var store: Store
    let tab: Tab
    var onSettings: () -> Void = {}
    var body: some View {
        let d = headerDate()
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("FIT TR").foregroundColor(Theme.txt)
                    Text("A").foregroundColor(Theme.acc)
                    Text("CKER").foregroundColor(Theme.txt)
                }
                .font(.head(23, .bold)).tracking(1)
                Text(tab.sub.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.5)
                    .foregroundColor(Theme.sub)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(d.full).font(.num(16)).foregroundColor(Theme.txt)
                Text(d.day.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundColor(Theme.sub)
                Text("\(dispW(store.lastWeight)) \(Units.wLabel)").font(.num(15)).foregroundColor(Theme.acc)
            }
            Button { tap(); onSettings() } label: {
                Image(systemName: "gearshape.fill").foregroundColor(Theme.sub).font(.system(size: 18))
                    .frame(width: 38, height: 38)
            }
            .padding(.leading, 6)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 14)
        .background(Theme.bg.opacity(0.92))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
    }
}

// MARK: - Bottom navigation
struct NavBar: View {
    @Binding var tab: Tab
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    tap(); tab = t
                } label: {
                    // Icon-only navigation: the page name is conveyed by the glyph
                    // (labels removed to save space). The active dot keeps the
                    // current page legible at a glance.
                    VStack(spacing: 6) {
                        Image(systemName: t.icon)
                            .font(.system(size: 20, weight: t == tab ? .semibold : .regular))
                            .foregroundColor(t == tab ? Theme.acc : Theme.sub)
                        Circle().fill(t == tab ? Theme.acc : .clear).frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .accessibilityLabel(t.label)
                }
            }
        }
        .padding(.vertical, 11)
        .padding(.bottom, 8)
        .background(Theme.c1.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(Theme.brd).frame(height: 1) }
    }
}

// MARK: - Active workout strip (shown when a workout is running on another tab)
struct ActiveWorkoutStrip: View {
    @EnvironmentObject var activeWorkout: ActiveWorkout
    @EnvironmentObject var store: Store
    let onTap: () -> Void

    private var elapsed: String {
        guard let start = activeWorkout.startDate else { return "" }
        let sec = Int(Date().timeIntervalSince(start))
        let m = sec / 60, s = sec % 60
        return String(format: "%d:%02d", m, s)
    }

    private var planColor: Color {
        guard let pid = activeWorkout.planId, let plan = store.plan(pid) else { return Theme.acc }
        return Color(hex: plan.color)
    }

    private var planName: String {
        guard let pid = activeWorkout.planId, let plan = store.plan(pid) else { return "" }
        return plan.name
    }

    var body: some View {
        Button { tap(); onTap() } label: {
            HStack(spacing: 12) {
                // Pulsing dot indicates live session.
                Circle().fill(planColor).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(planColor.opacity(0.3), lineWidth: 4))

                VStack(alignment: .leading, spacing: 1) {
                    Text(t("wk.workout_live").uppercased())
                        .font(.head(8, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                    Text(planName.uppercased())
                        .font(.head(13, .bold)).tracking(0.5).foregroundColor(planColor).lineLimit(1)
                }

                Spacer()

                ElapsedClock(startDate: activeWorkout.startDate)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
            }
            .padding(.vertical, 11).padding(.horizontal, 16)
            .background(Theme.c2)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(planColor.opacity(0.4), lineWidth: 1))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

/// Live elapsed timer that re-draws every second.
private struct ElapsedClock: View {
    let startDate: Date?
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(label)
            .font(.num(22)).foregroundColor(Theme.txt)
            .onReceive(tick) { now = $0 }
    }

    private var label: String {
        guard let start = startDate else { return "0:00" }
        let sec = Int(now.timeIntervalSince(start))
        let m = sec / 60, s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Rest timer strip
struct TimerStrip: View {
    @EnvironmentObject var timer: RestTimer
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RECUPERO").font(.head(9, .semibold)).tracking(2).foregroundColor(Theme.sub)
                if timer.done {
                    Text("VAI").font(.head(13, .bold)).tracking(0.5).foregroundColor(Theme.acc)
                } else {
                    Text(timer.label).font(.num(32)).foregroundColor(Theme.acc)
                        .frame(minWidth: 56, alignment: .leading)
                }
            }
            Bar(value: timer.progress, height: 5).frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                Button { tap(); timer.reset() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Theme.sub).frame(width: 30, height: 30)
                }
                Button { tap(); timer.stop() } label: {
                    Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 30, height: 30)
                }
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 17)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.brd2, lineWidth: 1))
        .padding(.horizontal, 16)
    }
}
