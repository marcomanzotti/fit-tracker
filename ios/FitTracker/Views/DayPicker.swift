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
    }

    private var divider: some View { Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 2) }

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
