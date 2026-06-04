import SwiftUI

// Wrapper so a plain date string can drive .sheet(item:).
struct IdentDate: Identifiable { let id = UUID(); let date: String }

// MARK: - Shared rest-day chip (identical look on week strip, plan and calendar)
struct RestChip: View {
    var size: CGFloat = 13
    var body: some View {
        Image(systemName: Theme.restIcon).font(.system(size: size, weight: .bold)).foregroundColor(Theme.bg)
    }
}

// MARK: - Day action picker
// Tapping an empty day on the "this week" strip or the calendar opens this sheet
// to log, after the fact, what was done that day: a strength day, a cardio
// activity, or rest. Picking a workout pre-fills it from the last time and hands
// back the created session so the caller can open the editor to fine-tune it.
struct DayPickerSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let date: String
    /// Called with the created session (to edit) or nil for rest / clear.
    var onPicked: (WorkoutSession?) -> Void

    // Apple Health workouts recorded that day but not yet in the app — offered
    // for manual import when automatic matching missed them.
    @State private var importable: [HealthWorkout] = []
    @State private var healthState: HealthState = .idle

    enum HealthState { case idle, loading, loaded, unavailable }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("day.title").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                            Text(prettyDate).font(.system(size: 11)).foregroundColor(Theme.sub)
                        }
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    Text(t("day.hint")).font(.system(size: 12)).foregroundColor(Theme.sub).lineSpacing(3)

                    // Workouts already logged on this day — tap to open the editor.
                    // Shown first so a day that already has sessions still gives
                    // access to the Health-import list below (instead of jumping
                    // straight into one session's editor).
                    let logged = store.sessions.filter { $0.date == date }.sorted { $0.planName < $1.planName }
                    if !logged.isEmpty {
                        Lbl(text: t("day.logged"))
                        Card {
                            ForEach(logged) { s in
                                loggedRow(s)
                                if s.id != logged.last?.id { divider }
                            }
                        }
                    }

                    // Rest toggle
                    Card {
                        Button { tap(); store.toggleRestDay(date); finish(nil) } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.restFill).frame(width: 38, height: 38)
                                    RestChip(size: 16)
                                }
                                Text(store.isRestDay(date) ? t("day.clear_rest") : t("day.mark_rest"))
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.txt)
                                Spacer()
                                Image(systemName: store.isRestDay(date) ? "checkmark.circle.fill" : "chevron.right")
                                    .foregroundColor(store.isRestDay(date) ? Theme.good : Theme.sub)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Apple Health import — ALWAYS shown so the action is findable.
                    // Tapping queries Health for that day's workouts (Apple Watch /
                    // Apple Fitness, Garmin, etc.) and lists any not yet in the app.
                    healthImportSection

                    if !store.plans.isEmpty {
                        Lbl(text: t("wk.select_day"))
                        Card {
                            ForEach(store.plans) { p in
                                pickRow(name: p.name, sub: p.sub, color: p.color, icon: "dumbbell.fill") {
                                    let s = store.quickInsertSession(plan: p, date: date); finish(s)
                                }
                                if p.id != store.plans.last?.id { divider }
                            }
                        }
                    }

                    if !store.cardioTypes.isEmpty {
                        Lbl(text: t("wk.cardio_types"))
                        Card {
                            ForEach(store.cardioTypes) { c in
                                pickRow(name: c.name, sub: c.sportType.label, color: c.color, icon: c.sportType.icon) {
                                    let s = store.quickInsertCardio(type: c, date: date); finish(s)
                                }
                                if c.id != store.cardioTypes.last?.id { divider }
                            }
                        }
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .onAppear {
            // Auto-query once on open so workouts usually appear without a tap.
            if healthState == .idle { loadHealth() }
        }
    }

    private func loadHealth() {
        guard HealthKitManager.shared.isAvailable else { healthState = .unavailable; return }
        healthState = .loading
        store.importableHealthWorkouts(onDate: date) { found in
            importable = found
            healthState = .loaded
        }
    }

    // MARK: Apple Health import section (always visible)
    @ViewBuilder private var healthImportSection: some View {
        let green = Color(hex: Theme.appleGreen)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill").font(.system(size: 11)).foregroundColor(green)
                Lbl(text: t("day.import_health"), color: green)
                Spacer()
                if healthState == .loaded {
                    Button { tap(); loadHealth() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                    }.buttonStyle(.plain)
                }
            }
            Card {
                switch healthState {
                case .idle, .loading:
                    HStack(spacing: 10) {
                        ProgressView().tint(green)
                        Text(t("day.health_loading")).font(.system(size: 13)).foregroundColor(Theme.sub)
                        Spacer()
                    }.padding(.vertical, 6)
                case .unavailable:
                    Text(t("day.health_unavailable")).font(.system(size: 12)).foregroundColor(Theme.sub).padding(.vertical, 6)
                case .loaded:
                    if importable.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(t("day.health_none")).font(.system(size: 13)).foregroundColor(Theme.sub)
                            Button { tap(); loadHealth() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .bold))
                                    Text(t("day.health_recheck")).font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(green)
                                .padding(.vertical, 7).padding(.horizontal, 12)
                                .background(green.opacity(0.10)).clipShape(Capsule())
                                .overlay(Capsule().stroke(green.opacity(0.4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 2)
                    } else {
                        ForEach(Array(importable.enumerated()), id: \.element.uuid) { _, w in
                            healthRow(w)
                            if w.uuid != importable.last?.uuid { divider }
                        }
                    }
                }
            }
        }
    }

    private var divider: some View { Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 2) }

    /// A workout already logged on this day. Tapping hands it back to the caller
    /// so the calendar opens its editor — same as tapping the day used to do.
    private func loggedRow(_ s: WorkoutSession) -> some View {
        Button { tap(); finish(s) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: s.planColor).opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: s.sportType.isCardio ? s.sportType.icon : "dumbbell.fill")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: s.planColor))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(s.planName).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                        if s.source != nil {
                            Image(systemName: "heart.fill").font(.system(size: 8)).foregroundColor(Theme.red)
                        }
                    }
                    Text(loggedSummary(s)).font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(1)
                }
                Spacer()
                Image(systemName: "slider.horizontal.3").foregroundColor(Theme.sub)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func loggedSummary(_ s: WorkoutSession) -> String {
        var parts: [String] = []
        if let sec = s.durationSeconds { parts.append(fmtDuration(sec)) }
        if s.sportType.isCardio {
            if let km = s.distanceKm, km > 0 { parts.append("\(dispDist(km)) \(Units.distLabel)") }
        } else {
            parts.append("\(s.exercises.count) \(t("wk.exercises_n"))")
        }
        parts.append("\(store.estimateCalories(s)) kcal")
        return parts.joined(separator: " · ")
    }

    /// A pickable Apple-Health workout: green accent, HK display name + a short
    /// metric summary; tapping imports it as a real session and opens its editor.
    private func healthRow(_ w: HealthWorkout) -> some View {
        let green = Color(hex: Theme.appleGreen)
        let icon = (Sport(rawValue: w.sport) ?? .other).icon
        return Button {
            tap()
            let s = store.importHealthWorkout(w)
            finish(s)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(green.opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(w.displayName).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                        Image(systemName: "heart.fill").font(.system(size: 8)).foregroundColor(Theme.red)
                    }
                    Text(healthSummary(w)).font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(1)
                }
                Spacer()
                Image(systemName: "square.and.arrow.down").foregroundColor(green)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func healthSummary(_ w: HealthWorkout) -> String {
        var parts: [String] = []
        if w.durationSec > 0 { parts.append(fmtDuration(w.durationSec)) }
        if let km = w.distanceKm, km > 0 { parts.append("\(dispDist(km)) \(Units.distLabel)") }
        if let hr = w.avgHR, hr > 0 { parts.append("\(hr) bpm") }
        if let k = w.kcal, k > 0 { parts.append("\(k) kcal") }
        if !w.sourceName.isEmpty { parts.append(w.sourceName) }
        return parts.isEmpty ? t("day.import_health") : parts.joined(separator: " · ")
    }

    private func pickRow(name: String, sub: String, color: String, icon: String, action: @escaping () -> Void) -> some View {
        Button { tap(); action() } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: color).opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: color))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                    if !sub.isEmpty { Text(sub).font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(1) }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Theme.sub)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func finish(_ s: WorkoutSession?) {
        onPicked(s)
        dismiss()
    }

    private var prettyDate: String {
        guard let d = isoFormatter.date(from: date) else { return date }
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "en" ? "en_US" : "it_IT")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: d).capitalized
    }
}
