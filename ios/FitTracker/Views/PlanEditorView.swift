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
                GhostButton(title: "← Annulla") { onCancel() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isNew ? "NUOVO GIORNO" : "MODIFICA GIORNO")
                        .font(.head(18, .bold)).tracking(0.5).foregroundColor(Color(hex: plan.color))
                    Text("Personalizza esercizi, serie e ripetizioni")
                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                }
                Spacer()
            }

            // Name + subtitle
            Card {
                Lbl(text: "Nome giorno").padding(.bottom, 8)
                InputField(placeholder: "es. Push, Petto, Gambe…", text: $plan.name, keyboard: .default)
                    .padding(.bottom, 10)
                Lbl(text: "Sottotitolo").padding(.bottom, 8)
                InputField(placeholder: "es. Spalle + Petto", text: $plan.sub, keyboard: .default)
                    .padding(.bottom, 12)
                Lbl(text: "Colore").padding(.bottom, 8)
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
                    Lbl(text: "Esercizi (\(plan.exercises.count))")
                    Spacer()
                }
                .padding(.bottom, 10)

                if plan.exercises.isEmpty {
                    Text("Nessun esercizio. Aggiungine uno qui sotto.")
                        .font(.system(size: 12)).foregroundColor(Theme.sub)
                        .padding(.vertical, 8)
                }

                ForEach(plan.exercises.indices, id: \.self) { i in
                    exerciseRow(i)
                }

                Button { tap(); plan.exercises.append(PlanExercise(name: "")) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Aggiungi esercizio").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Theme.acc)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.acc.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.acc.opacity(0.4), lineWidth: 1))
                }
                .padding(.top, 6)
            }

            BigButton(title: isNew ? "Crea giorno" : "Salva modifiche") { onSave() }

            if !isNew {
                Button { tap(); confirmDelete = true } label: {
                    Text("Elimina giorno").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.red)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.red.opacity(0.4), lineWidth: 1))
                }
                .padding(.top, 2)
                .confirmationDialog("Eliminare questo giorno?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Elimina", role: .destructive) { onDelete() }
                    Button("Annulla", role: .cancel) {}
                }
            }
        }
    }

    private func exerciseRow(_ i: Int) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                TextField("", text: $plan.exercises[i].name,
                          prompt: Text("Nome esercizio").foregroundColor(Theme.sub))
                    .font(.system(size: 14, weight: .medium)).foregroundColor(Theme.txt)
                Button { tap(); plan.exercises.remove(at: i) } label: {
                    Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(Theme.red.opacity(0.7))
                        .frame(width: 30, height: 34)
                }.buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                // Sets stepper
                HStack(spacing: 8) {
                    Text("SERIE").font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
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
                Text("RIP").font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
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
        }
        .padding(.vertical, 11).padding(.horizontal, 12)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
        .padding(.bottom, 8)
    }
}
