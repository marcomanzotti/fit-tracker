import SwiftUI
import UIKit

struct WorkoutView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @EnvironmentObject var activeWorkout: ActiveWorkout
    @EnvironmentObject var activeCardio: ActiveCardio

    @State private var editing: WorkoutPlan?
    @State private var isNew = false
    @State private var editingSession: WorkoutSession?
    @State private var loggingCardio: CardioType?
    @State private var editingCardio: CardioType?
    @State private var isNewCardio = false

    var body: some View {
        if let pid = activeWorkout.planId, let plan = store.plan(pid), !activeWorkout.minimized {
            LiveWorkoutView(
                plan: plan,
                log: $activeWorkout.log,
                onBack: { activeWorkout.minimized = true },   // minimize, keep running
                onSaved: { endWorkout() }                      // finish / discard ends it
            )
        } else if let cid = activeCardio.typeId, let ct = store.cardioType(cid), !activeCardio.minimized {
            LiveCardioView(
                type: ct,
                onBack: { activeCardio.minimized = true },     // minimize, keep running
                onSaved: { endCardio() }                        // finish / discard ends it
            )
        } else if editing != nil {
            // editing != nil is guaranteed here, but never force-unwrap: during
            // the teardown that follows save/delete (editing := nil) SwiftUI can
            // re-evaluate this binding's getter, and `editing!` would crash.
            PlanEditorView(
                plan: Binding(get: { editing ?? WorkoutPlan(name: "") }, set: { editing = $0 }),
                isNew: isNew,
                onSave: { commitPlan() },
                onDelete: { deletePlan() },
                onCancel: { editing = nil }
            )
        } else {
            grid
        }
    }

    // MARK: Grid of workout days
    private var grid: some View {
        VStack(spacing: 11) {
            // Helper text first, then the "Select day" label — the +New Day button
            // is gone; the trailing "+" card in the grid is the single way to add.
            Text(t("wk.edit_hint")).font(.system(size: 11)).foregroundColor(Theme.sub).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Lbl(text: t("wk.select_day"))
                Spacer()
            }

            // Static 2-column grid: every card is the same size, with a trailing
            // "+" card to add a day. (Drag-to-reorder was removed — it froze the
            // page and stole taps.)
            CardGrid(items: store.plans, rowHeight: 130,
                     card: { dayCard($0) }, addCell: { addCard })

            cardioSection
            CalendarCard()
            recentSessions
        }
        .sheet(item: $editingSession) { s in SessionEditorView(session: s) }
        .sheet(item: $loggingCardio) { ct in CardioLoggerView(type: ct) }
        .sheet(item: $editingCardio) { ct in CardioTypeEditorView(type: ct, isNew: isNewCardio) }
    }

    // MARK: Cardio activities (saveable, customizable like strength days)
    private var cardioSection: some View {
        VStack(spacing: 11) {
            HStack(spacing: 8) {
                Lbl(text: t("wk.cardio_types"))
                Spacer()
            }
            CardGrid(items: store.cardioTypes, rowHeight: 112,
                     card: { cardioTile($0) }, addCell: { addCardioTile })
        }
    }

    private func cardioTile(_ ct: CardioType) -> some View {
        // Card body → open the cardio logger. Circular Play (bottom-right) starts
        // the activity (on a paired watch too, when reachable) and opens the logger.
        ZStack(alignment: .topTrailing) {
            Button { tap(); loggingCardio = ct } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: ct.sportType.icon).font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(hex: ct.color))
                        Spacer()
                    }
                    .padding(.bottom, 10).padding(.trailing, 24)
                    Text(ct.name.uppercased()).font(.head(16, .bold)).tracking(0.5)
                        .foregroundColor(Theme.txt).lineLimit(1)
                    // Optional editable subtitle (mirrors strength days); falls back
                    // to the underlying sport label when the user hasn't set one.
                    Text((ct.sub?.isEmpty == false ? ct.sub! : ct.sportType.label))
                        .font(.system(size: 10)).foregroundColor(Theme.sub).lineLimit(1).padding(.top, 3)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.vertical, 15).padding(.horizontal, 14)
                .background(Theme.c1)
                .overlay(alignment: .leading) { Rectangle().fill(Color(hex: ct.color)).frame(width: 3) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Circular Play button — bottom-right, starts the cardio activity.
            PlayCircle(color: Color(hex: ct.color)) { tap(); startCardio(ct) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(10)

            Button { tap(); editCardio(ct) } label: {
                HStack(spacing: 3) {
                    Image(systemName: "pencil").font(.system(size: 10, weight: .bold))
                    Text(t("wk.edit").uppercased()).font(.head(8, .semibold)).tracking(0.5)
                }
                .foregroundColor(Theme.bg)
                .padding(.vertical, 4).padding(.horizontal, 7)
                .background(Color(hex: ct.color))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(7)
        }
    }

    /// Start a cardio activity for real: open the full live tracking screen
    /// (running clock + GPS distance/pace + live HR/calories) and, if an Apple
    /// Watch is paired and reachable, start the identical session there too so the
    /// two run in sync. Other wearables auto-import from Health afterwards.
    private func startCardio(_ ct: CardioType) {
        UIApplication.shared.isIdleTimerDisabled = true
        activeCardio.start(ct)
        if WatchSync.shared.watchReachable {
            WatchSync.shared.startOnWatch(activityId: "cardio-\(ct.id)")
            toast.show(t("wk.started_on_watch"))
        }
    }

    private func endCardio() {
        UIApplication.shared.isIdleTimerDisabled = false
        activeCardio.end()
    }

    private var addCardioTile: some View {
        Button { tap(); newCardio() } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 24)).foregroundColor(Theme.sub)
                Text(t("wk.new_cardio")).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.sub)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.c1.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundColor(Theme.brd2))
        }
        .buttonStyle(.plain)
    }

    private func newCardio() {
        isNewCardio = true
        editingCardio = CardioType(name: "", sport: "running", color: Theme.cardioColors.first!)
    }
    private func editCardio(_ ct: CardioType) {
        isNewCardio = false
        editingCardio = ct
    }

    private func dayCard(_ p: WorkoutPlan) -> some View {
        // Card body → edit/view plan. Circular Play button (bottom-right) → start.
        // Edit pill stays at top-right so the two actions are spatially distinct.
        ZStack(alignment: .topTrailing) {
            Button { tap(); editPlan(p) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(t("wk.day").uppercased()).font(.head(10, .semibold)).tracking(2)
                        .foregroundColor(Color(hex: p.color))
                        .padding(.bottom, 5).padding(.trailing, 30)
                    Text(p.name.uppercased()).font(.head(18, .bold)).tracking(0.5)
                        .foregroundColor(Theme.txt).lineLimit(1).padding(.bottom, 3)
                    Text(p.sub).font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(1)
                    Divider().overlay(Theme.brd).padding(.top, 11).padding(.bottom, 8)
                    HStack(alignment: .bottom) {
                        Text("\(p.exercises.count) \(t("wk.exercises_n"))".uppercased())
                            .font(.head(9, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                        Spacer()
                    }
                    // Reserve clear space below the count line so the Play circle,
                    // which sits in the bottom-right, never touches this text.
                    .padding(.trailing, 46)
                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.vertical, 15).padding(.horizontal, 14)
                .background(Theme.c1)
                .overlay(alignment: .leading) { Rectangle().fill(Color(hex: p.color)).frame(width: 3) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Circular Play button — bottom-right, plan color, starts the workout.
            // Sits a touch lower/right so it clears the exercise-count line above.
            PlayCircle(color: Color(hex: p.color)) { tap(); start(p) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 12).padding(.bottom, 10)
                .allowsHitTesting(true)

            // Edit pill (top-right) — separate from the card tap.
            Button { tap(); editPlan(p) } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.bg)
                    .frame(width: 26, height: 22)
                    .background(Color(hex: p.color).opacity(0.85)).clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    private var addCard: some View {
        Button { tap(); newPlan() } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 26)).foregroundColor(Theme.sub)
                Text(t("wk.create_day")).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.sub)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.c1.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundColor(Theme.brd2))
        }
        .buttonStyle(.plain)
    }

    private var recentSessions: some View {
        // Last 10 only here; every older session stays saved and is still
        // openable/editable by tapping its day in the calendar above.
        let recent = store.sessions.sorted { $0.date > $1.date }.prefix(10)
        return Group {
            if !recent.isEmpty {
                Card {
                    Lbl(text: t("wk.recent")).padding(.bottom, 4)
                    ForEach(Array(recent)) { s in
                        Button { tap(); editingSession = s } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 5) {
                                        Text("\(s.planName)".uppercased()).font(.head(14, .semibold)).tracking(0.5)
                                            .foregroundColor(Color(hex: s.planColor))
                                        if s.source != nil {
                                            Image(systemName: "heart.fill").font(.system(size: 9))
                                                .foregroundColor(Theme.red)
                                        }
                                    }
                                    Text("\(s.date) · \(s.sportType.isCardio ? cardioSummary(s) : "\(s.exercises.count) \(t("wk.exercises_n"))") · \(store.estimateCalories(s)) kcal")
                                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                                }
                                Spacer()
                                Image(systemName: "slider.horizontal.3").font(.system(size: 12)).foregroundColor(Theme.sub)
                                Badge(text: s.sportType.isCardio ? s.sportType.label : "\(s.totalSets) \(t("wk.sets_n"))")
                            }
                            .padding(.vertical, 11)
                            .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func cardioSummary(_ s: WorkoutSession) -> String {
        var parts: [String] = []
        if let sec = s.durationSeconds { parts.append(fmtDuration(sec)) }
        if let km = s.distanceKm { parts.append("\(dispDist(km)) \(Units.distLabel)") }
        return parts.isEmpty ? s.sportType.label : parts.joined(separator: " · ")
    }

    // MARK: Actions
    private func start(_ plan: WorkoutPlan) {
        UIApplication.shared.isIdleTimerDisabled = true
        activeWorkout.start(plan: plan)
        // If an Apple Watch app is paired and reachable, start the identical
        // session there too so the two run in sync (the watch streams live data
        // back). Other wearables (Garmin/Polar/…) can't be started from iOS, but
        // their session is auto-imported from Health on the next foreground sync.
        if WatchSync.shared.watchReachable {
            WatchSync.shared.startOnWatch(activityId: plan.id)
            toast.show(t("wk.started_on_watch"))
        }
    }

    private func endWorkout() {
        UIApplication.shared.isIdleTimerDisabled = false
        activeWorkout.end()
    }

    private func newPlan() {
        editing = WorkoutPlan(name: "", sub: "", color: Theme.planColors.first!, exercises: [])
        isNew = true
    }

    private func editPlan(_ p: WorkoutPlan) {
        editing = p
        isNew = false
    }

    private func commitPlan() {
        guard var p = editing else { return }
        if p.name.trimmingCharacters(in: .whitespaces).isEmpty { p.name = t("wk.new_day") }
        if let idx = store.plans.firstIndex(where: { $0.id == p.id }) {
            store.plans[idx] = p
        } else {
            store.plans.append(p)
        }
        // Populate the exercise library (muscle group, bodyweight) so these
        // exercises stay recoverable in Progress and future plans.
        store.registerPlanExercises(p)
        let created = isNew
        // Tear the editor down on the next runloop tick: clearing `editing` (which
        // swaps PlanEditorView out for the grid) synchronously inside the Save
        // action mutates state mid-render and can crash the editor's bindings.
        DispatchQueue.main.async {
            editing = nil
            toast.show(created ? t("wk.day_created") : t("wk.day_updated"))
        }
    }

    private func deletePlan() {
        guard let p = editing else { return }
        store.plans.removeAll { $0.id == p.id }
        DispatchQueue.main.async {
            editing = nil
            toast.show(t("wk.day_deleted"))
        }
    }
}

// MARK: - Circular Play button (shared by strength & cardio cards)
// A filled circular play control in the card's accent color, sitting bottom-right.
// Native-feeling, distinct from the edit pill, and a generous tap target.
struct PlayCircle: View {
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color)
                    .frame(width: 38, height: 38)
                    .shadow(color: color.opacity(0.4), radius: 5, y: 2)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.bg)
                    .offset(x: 1)   // optical centering of the triangle
            }
        }
        .buttonStyle(.plain)
    }
}
