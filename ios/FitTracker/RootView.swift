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
    @EnvironmentObject var activeCardio: ActiveCardio
    @State private var tab: Tab = .home
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Which floating strips are up; drives their shared enter/exit animation.
    private var stripsShown: [Bool] {
        [activeWorkout.isActive && (tab != .allena || activeWorkout.minimized),
         activeCardio.isActive && (tab != .allena || activeCardio.minimized),
         activeWorkout.isActive && tab == .allena && !activeWorkout.minimized,
         timer.active]
    }
    /// Height of everything pinned to the bottom, so the page can end above it.
    @State private var barsHeight: CGFloat = 0
    private static let barsBreathing: CGFloat = 16

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(tab: tab) { showSettings = true }
                // GeometryReader pins the scroll content to the exact viewport width,
                // so an over-wide child can never trigger horizontal rubber-banding.
                // (.scrollBounceBehavior(axes:) would be cleaner but needs iOS 16.4;
                // this works on the 16.0 deployment target.)
                GeometryReader { geo in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 11) {
                            switch tab {
                            case .home:   HomeView(tab: $tab)
                            case .allena: WorkoutView()
                            case .corpo:  BodyView()
                            case .nutri:  NutritionView()
                            case .stats:  StatsView()
                            }
                        }
                        .frame(width: geo.size.width - 32, alignment: .top)
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, barsHeight + Self.barsBreathing)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // A new scroll view per tab: each tab opens at its top instead
                    // of inheriting the previous tab's scroll position. A new text
                    // size redraws it too, since the sizes are read when drawn.
                    .id("\(tab.rawValue)-\(typeSize)")
                }
            }

            VStack(spacing: 8) {
                // "Workout in progress" strip — tapping it reopens the live view.
                // Shown whenever a workout is active but the live screen isn't
                // on-screen: either the user is on another tab, or they minimized
                // it while staying on the Train tab.
                if activeWorkout.isActive && (tab != .allena || activeWorkout.minimized) {
                    ActiveWorkoutStrip {
                        activeWorkout.minimized = false
                        tab = .allena
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                // Same floating strip for a running cardio session.
                if activeCardio.isActive && (tab != .allena || activeCardio.minimized) {
                    ActiveCardioStrip {
                        activeCardio.minimized = false
                        tab = .allena
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                // Time and Finish stay in reach while training.
                if activeWorkout.isActive && tab == .allena && !activeWorkout.minimized {
                    LiveWorkoutBar().transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if timer.active { TimerStrip().transition(.move(edge: .bottom).combined(with: .opacity)) }
                if case .saveFailed(let reason) = store.storageProblem { StorageBanner(reason: reason) }
                NavBar(tab: $tab)
            }
            .background(GeometryReader { Color.clear.preference(key: BarsHeightKey.self, value: $0.size.height) })
            .onPreferenceChange(BarsHeightKey.self) { barsHeight = $0 }
            // Strips slide up from the bar they sit on and leave the same way,
            // instead of popping in and shoving the layout.
            .animation(reduceMotion ? nil : Theme.settle, value: stripsShown)
        }
        .overlay(alignment: .top) {
            if let m = toast.message {
                ToastView(text: m, action: toast.action) { toast.runAction() }
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: toast.message)
        .sheet(isPresented: $showSettings) { SettingsView(store: store) }
        .onAppear {
            announceRestoredSession()
        }
        // A workout that sat untouched for hours is not silently resumed: it may be
        // one the user forgot to close, so they choose.
        .confirmationDialog(t("wk.stale_q"), isPresented: Binding(
            get: { activeWorkout.restored == .stale }, set: { if !$0 { activeWorkout.restored = nil } }),
            titleVisibility: .visible) {
            Button(t("wk.stale_resume")) { activeWorkout.restored = nil; tab = .allena }
            Button(t("wk.stale_save")) { saveRestoredWorkout() }
            Button(t("wk.discard_session"), role: .destructive) { timer.stop(); activeWorkout.end() }
        } message: {
            Text(t("wk.stale_body", activeWorkout.plan?.name ?? "",
                   activeWorkout.startDate.map { fmtDM(isoFormatter.string(from: $0)) } ?? ""))
        }
        // Re-sync Health (daily metrics + workouts from any paired watch) every
        // time the app returns to the foreground, so a session recorded on a
        // Garmin/Fitbit/etc. shows up without a manual refresh.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { store.refreshDay() }
            if phase == .active, store.prefs.healthKitEnabled { store.syncHealth(automatic: true, completion: healthToast) }
            // The autosave is debounced: write now, before the app can be suspended.
            if phase == .background { store.flushNow() }
        }
        .onChange(of: store.repairedNumbers) { announceRepairedNumbers() }
        // The Lock Screen activity opens the session that is running.
        .onOpenURL { url in
            guard url.scheme == "fittracker", url.host == "session" else { return }
            activeWorkout.minimized = false
            activeCardio.minimized = false
            tab = .allena
        }
    }

    /// Said once: a save met a number that was not a number and wrote it as 0.
    private func announceRepairedNumbers() {
        toast.show(t("store.repaired"), duration: ToastCenter.longDuration)
    }

    /// Tell the user a session was brought back, and take them to it.
    private func announceRestoredSession() {
        if activeWorkout.restored == .resumed {
            activeWorkout.restored = nil
            tab = .allena
            toast.show(t("wk.restored"), duration: ToastCenter.longDuration)
        }
        if activeCardio.restored {
            activeCardio.restored = false
            tab = .allena
            toast.show(t(activeCardio.paused ? "wk.restored_paused" : "wk.restored"),
                       duration: ToastCenter.longDuration)
        }
    }

    /// "Save as it is" for a workout found still open after hours.
    private func saveRestoredWorkout() {
        if let session = activeWorkout.finishedSession() {
            store.sessions.append(session)
            store.flushNow()        // before the draft is removed
            toast.show(t("wk.session_saved"))
        } else {
            toast.show(t("wk.nothing_save"))
        }
        timer.stop()
        activeWorkout.end()
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
                // One line whatever the text size: the logo shrinks instead of wrapping.
                (Text("FIT TR").foregroundColor(Theme.txt) + Text("A").foregroundColor(Theme.acc)
                    + Text("CKER").foregroundColor(Theme.txt))
                    .font(.head(23, .bold)).tracking(1)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(tab.sub.uppercased()).font(.ui(10, weight: .semibold)).tracking(1.5)
                    .foregroundColor(Theme.sub)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(d.full).font(.num(16)).foregroundColor(Theme.txt)
                Text(d.day.uppercased()).font(.ui(10, weight: .semibold)).tracking(1).foregroundColor(Theme.sub)
                Text("\(dispW(store.lastWeight)) \(Units.wLabel)").font(.num(15)).foregroundColor(Theme.acc)
            }
            Button { tap(); onSettings() } label: {
                Image(systemName: "gearshape.fill").accessibilityLabel(t("set.title")).foregroundColor(Theme.sub).font(.ui(18))
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
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
                            .font(.ui(20, weight: t == tab ? .semibold : .regular))
                            .foregroundColor(t == tab ? Theme.acc : Theme.sub)
                        Circle().fill(t == tab ? Theme.acc : .clear).frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .accessibilityLabel(t.label)
                }
                .accessibilityAddTraits(t == tab ? .isSelected : [])
            }
        }
        .padding(.vertical, 11)
        .padding(.bottom, 8)
        .background(Theme.c1.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(Theme.brd).frame(height: 1) }
    }
}

private struct BarsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Live workout bar (time and Finish, pinned while the workout is on screen)
struct LiveWorkoutBar: View {
    @EnvironmentObject var activeWorkout: ActiveWorkout

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(activeWorkout.plan.map { Color(hex: $0.color) } ?? Theme.acc).frame(width: 8, height: 8)
            ElapsedClock(startDate: activeWorkout.startDate)
            Spacer()
            Button { haptic(.success); activeWorkout.finishRequest = true } label: {
                Text(t("wk.finish").uppercased()).font(.head(13, .bold)).tracking(1).foregroundColor(Theme.bg)
                    .padding(.horizontal, 20).frame(minHeight: Theme.minTapTarget)
                    .background(Theme.acc).clipShape(Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.vertical, 4).padding(.leading, 16).padding(.trailing, 6)
        .chrome(18, stroke: Theme.acc.opacity(0.4))
        .padding(.horizontal, 16)
    }
}

// MARK: - Active workout strip (shown when a workout is running on another tab)
struct ActiveWorkoutStrip: View {
    @EnvironmentObject var activeWorkout: ActiveWorkout
    @EnvironmentObject var store: Store
    let onTap: () -> Void

    private var planColor: Color { activeWorkout.plan.map { Color(hex: $0.color) } ?? Theme.acc }
    private var planName: String { activeWorkout.plan?.name ?? "" }

    var body: some View {
        Button { tap(); onTap() } label: {
            HStack(spacing: 12) {
                // Pulsing dot indicates live session.
                Circle().fill(planColor).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(planColor.opacity(0.3), lineWidth: 4))

                VStack(alignment: .leading, spacing: 1) {
                    Text(t("wk.workout_live").uppercased())
                        .font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                    Text(planName.uppercased())
                        .font(.head(13, .bold)).tracking(0.5).foregroundColor(planColor).lineLimit(1)
                }

                Spacer()

                ElapsedClock(startDate: activeWorkout.startDate)

                Image(systemName: "chevron.right")
                    .font(.ui(11, weight: .semibold)).foregroundColor(Theme.sub)
            }
            .padding(.vertical, 11).padding(.horizontal, 16)
            .chrome(18, stroke: planColor.opacity(0.4))
            .padding(.horizontal, 16)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Active cardio strip (shown when a cardio session runs on another tab)
struct ActiveCardioStrip: View {
    @EnvironmentObject var activeCardio: ActiveCardio
    @EnvironmentObject var store: Store
    let onTap: () -> Void

    private var ct: CardioType? { activeCardio.type }
    private var color: Color { ct.map { Color(hex: $0.color) } ?? Theme.acc }

    var body: some View {
        Button { tap(); onTap() } label: {
            HStack(spacing: 12) {
                Circle().fill(color).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 4))
                VStack(alignment: .leading, spacing: 1) {
                    Text(t(activeCardio.paused ? "wk.paused" : "wk.workout_live").uppercased())
                        .font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                    Text((ct?.name ?? "").uppercased())
                        .font(.head(13, .bold)).tracking(0.5).foregroundColor(color).lineLimit(1)
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(fmtClock(activeCardio.elapsedSec(at: context.date)))
                        .font(.num(22)).foregroundColor(Theme.txt).monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.ui(11, weight: .semibold)).foregroundColor(Theme.sub)
            }
            .padding(.vertical, 11).padding(.horizontal, 16)
            .chrome(18, stroke: color.opacity(0.4))
            .padding(.horizontal, 16)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Time since `startDate`, redrawn every second. A view of its own so the tick
/// redraws these few digits and nothing around them.
struct ElapsedClock: View {
    let startDate: Date?
    var size: CGFloat = 22
    var format: (Int) -> String = fmtClock

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(format(max(0, Int(context.date.timeIntervalSince(startDate ?? context.date)))))
                .font(.num(size)).foregroundColor(Theme.txt).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Rest timer strip
struct TimerStrip: View {
    @EnvironmentObject var timer: RestTimer
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("wk.rest_label").uppercased()).font(.head(10, .semibold)).tracking(2).foregroundColor(Theme.sub)
                if timer.done {
                    Text(t("wk.go").uppercased()).font(.head(13, .bold)).tracking(0.5).foregroundColor(Theme.acc)
                } else {
                    Text(timer.label).font(.num(32)).foregroundColor(Theme.acc)
                        .frame(minWidth: 56, alignment: .leading)
                }
            }
            Bar(value: timer.progress, height: 5).frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                Button { tap(); timer.reset() } label: {
                    Image(systemName: "arrow.clockwise").accessibilityLabel(t("a11y.restart_rest"))
                        .foregroundColor(Theme.sub).frame(width: 30, height: 30)
                }
                .hitArea(7)
                Button { tap(); timer.stop() } label: {
                    Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                }
                .hitArea(7)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 17)
        .chrome(18, stroke: Theme.brd2)
        .padding(.horizontal, 16)
    }
}
