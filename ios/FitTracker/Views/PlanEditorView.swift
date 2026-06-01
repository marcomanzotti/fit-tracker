import SwiftUI

struct PlanEditorView: View {
    @Binding var plan: WorkoutPlan
    var isNew: Bool
    var onSave: () -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    @State private var confirmDelete = false

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
                    .padding(.bottom, 10)
                Lbl(text: t("pe.subtitle")).padding(.bottom, 8)
                InputField(placeholder: t("pe.subtitle_ph"), text: $plan.sub, keyboard: .default)
                    .padding(.bottom, 12)
                Lbl(text: t("pe.color")).padding(.bottom, 8)
                HStack(spacing: 10) {
                    ForEach(Theme.planColors, id: \.self) { c in
                        Circle().fill(Color(hex: c))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Theme.txt, lineWidth: plan.color == c ? 2 : 0))
                            .onTapGesture { tap(); plan.color = c }
                    }
                    Spacer()
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

                // Iterate over stable element ids (not indices): removing an
                // exercise must never leave a stale index that gets subscripted
                // during the SwiftUI diff — that was an out-of-bounds crash.
                ForEach(plan.exercises) { ex in
                    exerciseRow(ex.id)
                }

                Button { tap(); plan.exercises.append(PlanExercise(name: "")) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(t("wk.add_ex")).font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Theme.acc)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.acc.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.acc.opacity(0.4), lineWidth: 1))
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
    }

    @ViewBuilder
    private func exerciseRow(_ id: UUID) -> some View {
        if let i = plan.exercises.firstIndex(where: { $0.id == id }) {
            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    TextField("", text: $plan.exercises[i].name,
                              prompt: Text(t("pe.ex_name_ph")).foregroundColor(Theme.sub))
                        .font(.system(size: 14, weight: .medium)).foregroundColor(Theme.txt)
                    Button { tap(); plan.exercises.removeAll { $0.id == id } } label: {
                        Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.7))
                            .frame(width: 30, height: 34)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 10) {
                    // Sets stepper
                    HStack(spacing: 8) {
                        Text(t("pe.sets").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                        Button { tap(); if plan.exercises[i].sets > 1 { plan.exercises[i].sets -= 1 } } label: {
                            Image(systemName: "minus").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.txt)
                                .frame(width: 26, height: 26).background(Theme.c3).clipShape(Circle())
                        }.buttonStyle(.plain)
                        Text("\(plan.exercises[i].sets)").font(.num(16)).frame(minWidth: 16)
                        Button { tap(); plan.exercises[i].sets += 1 } label: {
                            Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.txt)
                                .frame(width: 26, height: 26).background(Theme.c3).clipShape(Circle())
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    // Reps
                    Text(t("wk.reps").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                    TextField("", text: $plan.exercises[i].reps,
                              prompt: Text("10").foregroundColor(Theme.sub))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                        .frame(width: 64).padding(.vertical, 7)
                        .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.brd, lineWidth: 1))
                    // Reorder
                    VStack(spacing: 2) {
                        Button { tap(); if i > 0 { plan.exercises.swapAt(i, i - 1) } } label: {
                            Image(systemName: "chevron.up").font(.system(size: 11)).foregroundColor(i > 0 ? Theme.sub : Theme.brd)
                                .frame(width: 26, height: 18)
                        }.buttonStyle(.plain).disabled(i == 0)
                        Button { tap(); if i < plan.exercises.count - 1 { plan.exercises.swapAt(i, i + 1) } } label: {
                            Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(i < plan.exercises.count - 1 ? Theme.sub : Theme.brd)
                                .frame(width: 26, height: 18)
                        }.buttonStyle(.plain).disabled(i == plan.exercises.count - 1)
                    }
                }
                methodRow(i)
            }
            .padding(.vertical, 11).padding(.horizontal, 12)
            .background(Theme.c2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            .padding(.bottom, 8)
        }
    }

    private func methodRow(_ i: Int) -> some View {
        let cur = plan.exercises[i].trainMethod
        let isGrouped = cur == .superset || cur == .giant
        return HStack(spacing: 10) {
            Text(t("wk.method").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            Menu {
                ForEach(TrainMethod.allCases, id: \.self) { m in
                    Button(methodLabel(m)) { tap(); plan.exercises[i].method = m == .normal ? nil : m.rawValue }
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
            Spacer()
            if isGrouped {
                Text(t("pe.group").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Button { tap(); let g = (plan.exercises[i].supersetGroup ?? 1); plan.exercises[i].supersetGroup = max(1, g - 1) } label: {
                    Image(systemName: "minus").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.txt)
                        .frame(width: 24, height: 24).background(Theme.c3).clipShape(Circle())
                }.buttonStyle(.plain)
                Text("\(plan.exercises[i].supersetGroup ?? 1)").font(.num(15)).frame(minWidth: 14)
                Button { tap(); plan.exercises[i].supersetGroup = (plan.exercises[i].supersetGroup ?? 0) + 1 } label: {
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
