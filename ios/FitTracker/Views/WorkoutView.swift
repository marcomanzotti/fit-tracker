import SwiftUI
import UIKit

struct WorkoutView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter

    @State private var activePlanId: String?
    @State private var log: [LoggedExercise] = []
    @State private var editing: WorkoutPlan?
    @State private var isNew = false
    @State private var editingSession: WorkoutSession?
    @State private var loggingCardio: CardioType?
    @State private var editingCardio: CardioType?
    @State private var isNewCardio = false

    var body: some View {
        if let pid = activePlanId, let plan = store.plan(pid) {
            LiveWorkoutView(
                plan: plan,
                log: $log,
                onBack: { endWorkout() },
                onSaved: { endWorkout() }
            )
        } else if let _ = editing {
            PlanEditorView(
                plan: Binding(get: { editing! }, set: { editing = $0 }),
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
        let cols = [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)]
        return VStack(spacing: 11) {
            HStack(spacing: 8) {
                Lbl(text: t("wk.select_day"))
                Spacer()
                Button { tap(); newPlan() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(t("wk.new_day").uppercased()).font(.head(10, .semibold)).tracking(1)
                    }
                    .foregroundColor(Theme.acc)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(Theme.acc.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.acc, lineWidth: 1))
                }
            }

            LazyVGrid(columns: cols, spacing: 11) {
                ForEach(store.plans) { p in
                    dayCard(p)
                }
                addCard
            }

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
        let cols = [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)]
        return VStack(spacing: 11) {
            HStack(spacing: 8) {
                Lbl(text: t("wk.cardio_types"))
                Spacer()
                Button { tap(); newCardio() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(t("wk.add_cardio").uppercased()).font(.head(10, .semibold)).tracking(1)
                    }
                    .foregroundColor(Theme.blue)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(Theme.blue.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.blue, lineWidth: 1))
                }
            }
            LazyVGrid(columns: cols, spacing: 11) {
                ForEach(store.cardioTypes) { ct in cardioTile(ct) }
                addCardioTile
            }
        }
    }

    private func cardioTile(_ ct: CardioType) -> some View {
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
                    Text(ct.sportType.label).font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 15).padding(.horizontal, 14)
                .background(Theme.c1)
                .overlay(alignment: .leading) { Rectangle().fill(Color(hex: ct.color)).frame(width: 3) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button { tap(); editCardio(ct) } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13))
                    .foregroundColor(Theme.sub).frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    private var addCardioTile: some View {
        Button { tap(); newCardio() } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 24)).foregroundColor(Theme.sub)
                Text(t("wk.new_cardio")).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.sub)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
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
        // The whole card starts the workout; the edit control is a sibling (not nested)
        // so its tap doesn't also trigger the start action.
        ZStack(alignment: .topTrailing) {
            Button { tap(); start(p) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(t("wk.day").uppercased()).font(.head(10, .semibold)).tracking(2)
                        .foregroundColor(Color(hex: p.color))
                        .padding(.bottom, 5).padding(.trailing, 30)
                    Text(p.name.uppercased()).font(.head(18, .bold)).tracking(0.5)
                        .foregroundColor(Theme.txt).lineLimit(1).padding(.bottom, 3)
                    Text(p.sub).font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(1)
                    Divider().overlay(Theme.brd).padding(.top, 11).padding(.bottom, 8)
                    Text("\(p.exercises.count) \(t("wk.exercises_n"))".uppercased()).font(.head(9, .semibold)).tracking(1.5)
                        .foregroundColor(Theme.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 15).padding(.horizontal, 14)
                .background(Theme.c1)
                .overlay(alignment: .leading) { Rectangle().fill(Color(hex: p.color)).frame(width: 3) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button { tap(); editPlan(p) } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13))
                    .foregroundColor(Theme.sub).frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    private var addCard: some View {
        Button { tap(); newPlan() } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 26)).foregroundColor(Theme.sub)
                Text(t("wk.create_day")).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.sub)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Theme.c1.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundColor(Theme.brd2))
        }
        .buttonStyle(.plain)
    }

    private var recentSessions: some View {
        let recent = store.sessions.sorted { $0.date > $1.date }.prefix(5)
        return Group {
            if !recent.isEmpty {
                Card {
                    Lbl(text: t("wk.recent")).padding(.bottom, 4)
                    ForEach(Array(recent)) { s in
                        Button { tap(); editingSession = s } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(s.planName)".uppercased()).font(.head(14, .semibold)).tracking(0.5)
                                        .foregroundColor(Color(hex: s.planColor))
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
        if let d = s.durationMin { parts.append("\(d) min") }
        if let km = s.distanceKm { parts.append("\(trimNum(km)) km") }
        return parts.isEmpty ? s.sportType.label : parts.joined(separator: " · ")
    }

    // MARK: Actions
    private func start(_ plan: WorkoutPlan) {
        log = plan.exercises.map { ex in
            LoggedExercise(name: ex.name,
                           sets: (0..<max(1, ex.sets)).map { _ in SetEntry() },
                           notes: "",
                           target: "\(ex.sets)×\(ex.reps)",
                           supersetGroup: ex.supersetGroup,
                           method: ex.method)
        }
        UIApplication.shared.isIdleTimerDisabled = true
        activePlanId = plan.id
    }

    private func endWorkout() {
        UIApplication.shared.isIdleTimerDisabled = false
        activePlanId = nil
        log = []
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
        editing = nil
        toast.show(isNew ? t("wk.day_created") : t("wk.day_updated"))
    }

    private func deletePlan() {
        guard let p = editing else { return }
        store.plans.removeAll { $0.id == p.id }
        editing = nil
        toast.show(t("wk.day_deleted"))
    }
}
