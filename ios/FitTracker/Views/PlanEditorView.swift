import SwiftUI

// MARK: - Exercise name field with autocomplete + title-case
// Shown inside each exercise row. As the user types, names from the exercise
// library that contain the typed text are shown in a dropdown below the field;
// tapping one fills the field exactly to avoid duplicate-name fragmentation.
private struct ExerciseNameField: View {
    @EnvironmentObject var store: Store
    @Binding var name: String
    var placeholder: String

    @State private var showSuggestions = false
    @State private var isFocused = false

    private var suggestions: [String] {
        let q = name.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        let all = store.allExerciseNames().map { $0.name }
        return Array(all
            .filter { $0.localizedCaseInsensitiveContains(q) && $0.lowercased() != q.lowercased() }
            .prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("", text: $name,
                      prompt: Text(placeholder).foregroundColor(Theme.sub))
                .font(.system(size: 14, weight: .medium)).foregroundColor(Theme.txt)
                .autocorrectionDisabled()
                .onChange(of: name) { newVal in
                    let titled = titleCased(newVal)
                    if titled != newVal { name = titled }
                    showSuggestions = !suggestions.isEmpty
                }
                .onSubmit { showSuggestions = false }

            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { s in
                        Button {
                            tap()
                            name = s
                            showSuggestions = false
                        } label: {
                            Text(s)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.txt)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 9).padding(.horizontal, 12)
                                .background(Theme.c3)
                        }
                        .buttonStyle(.plain)
                        if s != suggestions.last {
                            Divider().background(Theme.brd)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                    .stroke(Theme.brd, lineWidth: 1))
                .padding(.top, 4)
                .zIndex(10)
            }
        }
    }

}

struct PlanEditorView: View {
    @EnvironmentObject var store: Store
    @Binding var plan: WorkoutPlan
    var isNew: Bool
    var onSave: () -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    @State private var confirmDelete = false
    @State private var browsing = false

    var body: some View {
        VStack(spacing: 11) {
            // Back row
            HStack(spacing: 12) {
                GhostButton(title: "← \(t("cancel"))") { onCancel() }
                VStack(alignment: .leading, spacing: 2) {
                    Text((isNew ? t("wk.new_day") : t("wk.edit_day")).uppercased())
                        .font(.head(18, .bold)).tracking(0.5).foregroundColor(Color(hex: plan.color))
                    Text(t("pe.subtitle_hint"))
                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                }
                Spacer()
            }

            // Name + subtitle
            Card {
                Lbl(text: t("pe.day_name")).padding(.bottom, 8)
                InputField(placeholder: t("pe.day_name_ph"), text: $plan.name, keyboard: .default)
                    .onChange(of: plan.name) { v in let tc = titleCased(v); if tc != v { plan.name = tc } }
                    .padding(.bottom, 10)
                Lbl(text: t("pe.subtitle")).padding(.bottom, 8)
                InputField(placeholder: t("pe.subtitle_ph"), text: $plan.sub, keyboard: .default)
                    .padding(.bottom, 12)
                Lbl(text: t("pe.color")).padding(.bottom, 8)
                FlexWrap(Theme.sportColors, spacing: 10) { c in
                    Circle().fill(Color(hex: c))
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Theme.txt, lineWidth: plan.color == c ? 2 : 0))
                        .onTapGesture { tap(); plan.color = c }
                }
            }

            // Exercises
            Card {
                HStack {
                    Lbl(text: "\(t("pe.exercises")) (\(plan.exercises.count))")
                    Spacer()
                }
                .padding(.bottom, 10)

                if plan.exercises.isEmpty {
                    Text(t("pe.no_ex"))
                        .font(.system(size: 12)).foregroundColor(Theme.sub)
                        .padding(.vertical, 8)
                }

                // Iterate over element BINDINGS (not indices): a row never holds
                // an integer index into the published array, so removing/saving an
                // exercise can't leave a stale index that gets subscripted during
                // the SwiftUI diff — that was the out-of-bounds crash on save.
                ForEach($plan.exercises) { $ex in
                    exerciseRow($ex)
                }

                HStack(spacing: 9) {
                    // Browse the curated library by muscle group.
                    Button { tap(); browsing = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2")
                            Text(t("pe.browse")).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Theme.bg)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.acc)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                    }.buttonStyle(.plain)
                    // Add a blank exercise to fill in manually.
                    Button { tap(); plan.exercises.append(PlanExercise(name: "")) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text(t("pe.blank")).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Theme.acc)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.acc.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.acc.opacity(0.4), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                .padding(.top, 6)
            }

            BigButton(title: isNew ? t("wk.create_day") : t("pe.save_changes")) { onSave() }

            if !isNew {
                Button { tap(); confirmDelete = true } label: {
                    Text(t("pe.delete_day")).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.red)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.red.opacity(0.4), lineWidth: 1))
                }
                .padding(.top, 2)
                .confirmationDialog(t("pe.delete_day_q"), isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button(t("delete"), role: .destructive) { onDelete() }
                    Button(t("cancel"), role: .cancel) {}
                }
            }
        }
        .sheet(isPresented: $browsing) {
            ExercisePickerSheet { picked in
                plan.exercises.append(picked)
            }
        }
    }

    private func exerciseRow(_ ex: Binding<PlanExercise>) -> some View {
        // Reorder/remove resolve the live index at TAP time (when the array is
        // current), never capturing a stale index into the published array.
        let id = ex.wrappedValue.id
        let idx = plan.exercises.firstIndex(where: { $0.id == id })
        let kind = ex.wrappedValue.exKind
        return VStack(spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                ExerciseNameField(name: ex.name, placeholder: t("pe.ex_name_ph"))
                BodyweightChip(isBodyweight: ex.isBodyweight)
                Button { tap(); plan.exercises.removeAll { $0.id == id } } label: {
                    Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.7))
                        .frame(width: 30, height: 34)
                }.buttonStyle(.plain)
            }
            kindSelector(ex)
            // Parameter row depends on the exercise kind: sets×reps for classic,
            // sets×target-seconds for a hold, work/rest/rounds for HIIT.
            switch kind {
            case .reps, .timed: setsParamRow(ex, idx: idx, kind: kind)
            case .interval:     intervalParamRow(ex, idx: idx)
            }
            // Method/superset + effort only apply to the classic rep-based mode.
            if kind == .reps {
                methodRow(ex)
                EffortModeSelector(effortMode: ex.effortMode).padding(.top, 2)
            } else {
                muscleOnlyRow(ex)
            }
        }
        .padding(.vertical, 11).padding(.horizontal, 12)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
        .padding(.bottom, 8)
    }

    // MARK: Exercise-kind selector (reps / timed / interval)
    private func kindSelector(_ ex: Binding<PlanExercise>) -> some View {
        let cur = ex.wrappedValue.exKind
        return HStack(spacing: 6) {
            Text(t("pe.kind").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            ForEach(ExKind.allCases, id: \.self) { k in
                let active = cur == k
                Button {
                    tap()
                    ex.wrappedValue.kind = k == .reps ? nil : k.rawValue
                    // Seed sensible defaults when switching into interval mode.
                    if k == .interval {
                        if ex.wrappedValue.workSec == nil { ex.wrappedValue.workSec = 30 }
                        if ex.wrappedValue.restSec == nil { ex.wrappedValue.restSec = 15 }
                        if ex.wrappedValue.rounds == nil { ex.wrappedValue.rounds = 8 }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: k.icon).font(.system(size: 9, weight: .bold))
                        Text(t(k.labelKey)).font(.head(10, .semibold)).tracking(0.5)
                    }
                    .foregroundColor(active ? Theme.bg : Theme.sub)
                    .padding(.vertical, 5).padding(.horizontal, 9)
                    .background(active ? Theme.acc : Theme.c2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(active ? Theme.acc : Theme.brd, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: Sets × (reps | target seconds) row, shared by reps & timed kinds
    private func setsParamRow(_ ex: Binding<PlanExercise>, idx: Int?, kind: ExKind) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(t("pe.sets").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Button { tap(); if ex.wrappedValue.sets > 1 { ex.wrappedValue.sets -= 1 } } label: {
                    Image(systemName: "minus").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.txt)
                        .frame(width: 26, height: 26).background(Theme.c3).clipShape(Circle())
                }.buttonStyle(.plain)
                Text("\(ex.wrappedValue.sets)").font(.num(16)).frame(minWidth: 16)
                Button { tap(); ex.wrappedValue.sets += 1 } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.txt)
                        .frame(width: 26, height: 26).background(Theme.c3).clipShape(Circle())
                }.buttonStyle(.plain)
            }
            Spacer()
            // For a timed hold, the "reps" field carries the target hold in seconds.
            Text((kind == .timed ? t("pe.target_sec") : t("wk.reps")).uppercased())
                .font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            TextField("", text: ex.reps,
                      prompt: Text(kind == .timed ? "45" : "10").foregroundColor(Theme.sub))
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                .frame(width: 64).padding(.vertical, 7)
                .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            reorderButtons(idx: idx)
        }
    }

    // MARK: Interval (HIIT) parameter row: work / rest / rounds steppers
    private func intervalParamRow(_ ex: Binding<PlanExercise>, idx: Int?) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                intStepper(t("pe.work_sec"), value: Binding(
                    get: { ex.wrappedValue.workSec ?? 30 },
                    set: { ex.wrappedValue.workSec = $0 }), step: 5, min: 5, suffix: "s")
                intStepper(t("pe.rest_sec"), value: Binding(
                    get: { ex.wrappedValue.restSec ?? 15 },
                    set: { ex.wrappedValue.restSec = $0 }), step: 5, min: 0, suffix: "s")
            }
            HStack(spacing: 10) {
                intStepper(t("pe.rounds"), value: Binding(
                    get: { ex.wrappedValue.rounds ?? 8 },
                    set: { ex.wrappedValue.rounds = $0 }), step: 1, min: 1, suffix: "")
                Spacer()
                reorderButtons(idx: idx)
            }
        }
    }

    private func intStepper(_ label: String, value: Binding<Int>, step: Int, min: Int, suffix: String) -> some View {
        HStack(spacing: 7) {
            Text(label.uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            Button { tap(); value.wrappedValue = Swift.max(min, value.wrappedValue - step) } label: {
                Image(systemName: "minus").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.txt)
                    .frame(width: 24, height: 24).background(Theme.c3).clipShape(Circle())
            }.buttonStyle(.plain)
            Text("\(value.wrappedValue)\(suffix)").font(.num(15)).frame(minWidth: 28)
            Button { tap(); value.wrappedValue += step } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.txt)
                    .frame(width: 24, height: 24).background(Theme.c3).clipShape(Circle())
            }.buttonStyle(.plain)
        }
    }

    private func reorderButtons(idx: Int?) -> some View {
        VStack(spacing: 2) {
            Button { tap(); if let i = idx, i > 0 { plan.exercises.swapAt(i, i - 1) } } label: {
                Image(systemName: "chevron.up").font(.system(size: 11)).foregroundColor((idx ?? 0) > 0 ? Theme.sub : Theme.brd)
                    .frame(width: 26, height: 18)
            }.buttonStyle(.plain).disabled((idx ?? 0) == 0)
            Button { tap(); if let i = idx, i < plan.exercises.count - 1 { plan.exercises.swapAt(i, i + 1) } } label: {
                Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor((idx ?? 0) < plan.exercises.count - 1 ? Theme.sub : Theme.brd)
                    .frame(width: 26, height: 18)
            }.buttonStyle(.plain).disabled((idx ?? 0) == plan.exercises.count - 1)
        }
    }

    // Muscle-group-only row for timed/interval kinds (no method/superset).
    private func muscleOnlyRow(_ ex: Binding<PlanExercise>) -> some View {
        let muscle = ex.wrappedValue.muscle ?? store.exerciseCategory(ex.wrappedValue.name)
        let mg = MuscleGroup(rawValue: muscle) ?? .other
        return HStack(spacing: 10) {
            Text(t("mg.title").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            Menu {
                ForEach(MuscleGroup.allCases) { g in
                    Button(t(g.labelKey)) { tap(); ex.wrappedValue.muscle = g.rawValue }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: mg.color)).frame(width: 7, height: 7)
                    Text(t(mg.labelKey)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.txt)
                    Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(Theme.sub)
                }
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Theme.c1).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private func methodRow(_ ex: Binding<PlanExercise>) -> some View {
        let cur = ex.wrappedValue.trainMethod
        let isGrouped = cur == .superset || cur == .giant
        // Effective muscle group: explicit choice, else the library's saved value,
        // else a guess from the name — so the menu always shows something sensible.
        let muscle = ex.wrappedValue.muscle ?? store.exerciseCategory(ex.wrappedValue.name)
        let mg = MuscleGroup(rawValue: muscle) ?? .other
        return HStack(spacing: 10) {
            Text(t("wk.method").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            Menu {
                ForEach(TrainMethod.allCases, id: \.self) { m in
                    Button(methodLabel(m)) { tap(); ex.wrappedValue.method = m == .normal ? nil : m.rawValue }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(methodLabel(cur)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.txt)
                    Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(Theme.sub)
                }
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Theme.c1).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
            // Muscle group, right next to the method selector.
            Menu {
                ForEach(MuscleGroup.allCases) { g in
                    Button(t(g.labelKey)) { tap(); ex.wrappedValue.muscle = g.rawValue }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: mg.color)).frame(width: 7, height: 7)
                    Text(t(mg.labelKey)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.txt)
                    Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(Theme.sub)
                }
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Theme.c1).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
            Spacer()
            if isGrouped {
                Text(t("pe.group").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Button { tap(); let g = (ex.wrappedValue.supersetGroup ?? 1); ex.wrappedValue.supersetGroup = max(1, g - 1) } label: {
                    Image(systemName: "minus").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.txt)
                        .frame(width: 24, height: 24).background(Theme.c3).clipShape(Circle())
                }.buttonStyle(.plain)
                Text("\(ex.wrappedValue.supersetGroup ?? 1)").font(.num(15)).frame(minWidth: 14)
                Button { tap(); ex.wrappedValue.supersetGroup = (ex.wrappedValue.supersetGroup ?? 0) + 1 } label: {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.txt)
                        .frame(width: 24, height: 24).background(Theme.c3).clipShape(Circle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    private func methodLabel(_ m: TrainMethod) -> String {
        switch m {
        case .normal:    return t("none")
        case .superset:  return t("wk.superset")
        case .dropset:   return "Drop set"
        case .restpause: return "Rest-pause"
        case .giant:     return "Giant set"
        }
    }
}

// MARK: - Browse-by-muscle exercise picker
// Lets the user add an exercise from the curated/auto-populated library: search,
// scan muscle-group sections, tap to add (inheriting the library's muscle group +
// bodyweight flag), or type a brand-new name. Tapping an existing entry while a
// query is typed is the natural "create a variant" path — the new name rolls up to
// the same movement family via Store.normalizedBase.
struct ExercisePickerSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var onPick: (PlanExercise) -> Void

    @State private var search = ""

    private var sections: [(group: MuscleGroup, items: [ExerciseItem])] {
        store.exercisesByMuscle(query: search)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                InputField(placeholder: t("pe.search_ex"), text: $search, keyboard: .default)
                // Quick "create" affordance when the typed name isn't in the library.
                if !trimmedSearch.isEmpty && !nameExists {
                    Button { tap(); add(name: trimmedSearch, group: nil, bodyweight: false) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").foregroundColor(Theme.acc)
                            Text("\(t("pe.create")) \"\(trimmedSearch)\"")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                            Spacer()
                        }
                        .padding(.vertical, 12).padding(.horizontal, 14)
                        .background(Theme.acc.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.acc.opacity(0.4), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                ScrollView {
                    LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                        if sections.isEmpty {
                            Text(t("pe.no_ex_found")).font(.system(size: 12)).foregroundColor(Theme.sub)
                                .frame(maxWidth: .infinity).padding(.top, 24)
                        }
                        ForEach(sections, id: \.group) { section in
                            Section {
                                ForEach(section.items) { item in row(item, group: section.group) }
                            } header: {
                                HStack(spacing: 7) {
                                    Circle().fill(Color(hex: section.group.color)).frame(width: 8, height: 8)
                                    Text(t(section.group.labelKey).uppercased())
                                        .font(.head(10, .bold)).tracking(1).foregroundColor(Theme.txt)
                                    Spacer()
                                }
                                .padding(.vertical, 5).padding(.horizontal, 2)
                                .background(Theme.bg)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
    }

    private var trimmedSearch: String { search.trimmingCharacters(in: .whitespaces) }
    private var nameExists: Bool {
        store.exerciseItems.contains { $0.name.localizedCaseInsensitiveCompare(trimmedSearch) == .orderedSame }
    }

    private var header: some View {
        HStack {
            Text(t("pe.browse")).font(.head(18, .bold)).foregroundColor(Theme.txt)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 18)
    }

    private func row(_ item: ExerciseItem, group: MuscleGroup) -> some View {
        Button { tap(); add(name: item.name, group: group, bodyweight: item.isBodyweight) } label: {
            HStack(spacing: 10) {
                Text(item.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                if item.isBodyweight {
                    Text(t("wk.bodyweight")).font(.head(8, .semibold)).tracking(0.5).foregroundColor(Theme.good)
                        .padding(.vertical, 2).padding(.horizontal, 6)
                        .background(Theme.good.opacity(0.14)).clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.acc)
            }
            .padding(.vertical, 11).padding(.horizontal, 13)
            .background(Theme.c1)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.brd, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func add(name: String, group: MuscleGroup?, bodyweight: Bool) {
        var pe = PlanExercise(name: name, sets: 3, reps: "10")
        pe.isBodyweight = bodyweight ? true : nil
        pe.muscle = (group ?? MuscleGroup(rawValue: store.exerciseCategory(name)) ?? .other).rawValue
        haptic(.success)
        onPick(pe)
        dismiss()
    }
}
