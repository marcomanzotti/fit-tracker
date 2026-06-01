import SwiftUI

// MARK: - Goal editor (always reachable from Home)
// The goal is fixed at onboarding and only ever changes here, on purpose — it
// must not drift with daily check-ins. Start weight is the baseline progress is
// measured from, so it's editable too.
struct GoalEditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var goalWeight = ""
    @State private var startWeight = ""
    @State private var goalBF = ""
    @State private var goalMode = "maintain"
    @State private var rate = ""

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(t("goal.title").uppercased()).font(.head(18, .bold)).tracking(1).foregroundColor(Theme.txt)
                        InfoButton(id: "goal")
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    Text(t("goal.hint")).font(.system(size: 12)).foregroundColor(Theme.sub).lineSpacing(3)

                    Card {
                        FieldRow(label: t("ob.goal_mode")) {
                            PillSelect(options: ["cut", "maintain", "bulk"], title: goalTitleLocal, selection: $goalMode)
                        }
                        Spacer().frame(height: 14)
                        HStack(spacing: 12) {
                            FieldRow(label: t("goal.start_weight")) { InputField(placeholder: "88", text: $startWeight) }
                            FieldRow(label: t("ob.goal_weight")) { InputField(placeholder: "80", text: $goalWeight) }
                        }
                        Spacer().frame(height: 14)
                        HStack(spacing: 12) {
                            FieldRow(label: t("pc.goal_bf")) { InputField(placeholder: "15", text: $goalBF) }
                            FieldRow(label: t("ob.rate")) { InputField(placeholder: "-0.5", text: $rate) }
                        }
                    }

                    BigButton(title: t("save")) { save() }
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            let p = store.prefs
            goalWeight = trimNum(p.goalWeight)
            startWeight = trimNum(p.startWeight)
            goalBF = trimNum(p.goalBF)
            goalMode = p.goal.rawValue
            rate = p.weeklyRate.map { trimNum($0) } ?? ""
        }
    }

    private func goalTitleLocal(_ v: String) -> String {
        switch v { case "cut": return t("nut.cut"); case "bulk": return t("nut.bulk"); default: return t("nut.maintain") }
    }

    private func save() {
        var p = store.prefs
        if pf(goalWeight) > 0 { p.goalWeight = pf(goalWeight) }
        if pf(startWeight) > 0 { p.startWeight = pf(startWeight) }
        if pf(goalBF) > 0 { p.goalBF = pf(goalBF) }
        p.goalMode = goalMode
        p.weeklyRate = rate.isEmpty ? nil : pf(rate)
        store.prefs = p
        haptic(.success)
        toast.show(t("goal.saved"))
        dismiss()
    }
}

// MARK: - Weekly planner (assign each weekday a plan / cardio / rest)
struct WeeklyPlanView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    // Monday-first labels independent of locale weekday order.
    private var dayNames: [String] {
        L.lang == "en"
            ? ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            : ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
    }

    var body: some View {
        let todayMon = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(t("plan.week").uppercased()).font(.head(18, .bold)).tracking(1).foregroundColor(Theme.txt)
                        InfoButton(id: "weekplan")
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    Text(t("plan.week_hint")).font(.system(size: 12)).foregroundColor(Theme.sub).lineSpacing(3)

                    Card {
                        ForEach(0..<7, id: \.self) { wd in
                            dayRow(wd, isToday: wd == todayMon)
                            if wd < 6 { Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 2) }
                        }
                    }

                    if store.prefs.hasSchedule {
                        Button { tap(); store.clearSchedule(); toast.show(t("plan.saved")) } label: {
                            Text(t("plan.clear")).font(.head(13, .semibold)).foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.red.opacity(0.4), lineWidth: 1))
                        }
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func dayRow(_ wd: Int, isToday: Bool) -> some View {
        let cur = store.prefs.weekSchedule[wd]
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayNames[wd]).font(.system(size: 14, weight: .semibold)).foregroundColor(isToday ? Theme.acc : Theme.txt)
                if isToday { Text(t("plan.today").uppercased()).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.acc) }
            }
            Spacer()
            Menu {
                Button(t("plan.auto")) { tap(); store.setSchedule(weekday: wd, id: "") }
                Button(t("plan.rest")) { tap(); store.setSchedule(weekday: wd, id: "rest") }
                if !store.plans.isEmpty {
                    Divider()
                    ForEach(store.plans) { p in
                        Button(p.name) { tap(); store.setSchedule(weekday: wd, id: p.id) }
                    }
                }
                if !store.cardioTypes.isEmpty {
                    Divider()
                    ForEach(store.cardioTypes) { c in
                        Button(c.name) { tap(); store.setSchedule(weekday: wd, id: c.id) }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(slotColor(cur)).frame(width: 18, height: 18)
                        if cur == "rest" {
                            Image(systemName: Theme.restIcon).font(.system(size: 9, weight: .bold)).foregroundColor(Theme.bg)
                        } else if let icon = slotIcon(cur) {
                            Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundColor(Theme.bg)
                        }
                    }
                    Text(slotLabel(cur)).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.txt)
                    Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(Theme.sub)
                }
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(Theme.c2).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            }
        }
        .padding(.vertical, 7)
    }

    private func slotLabel(_ id: String) -> String {
        if id.isEmpty { return t("plan.auto") }
        if id == "rest" { return t("plan.rest") }
        if let p = store.plans.first(where: { $0.id == id }) { return p.name }
        if let c = store.cardioTypes.first(where: { $0.id == id }) { return c.name }
        return t("plan.auto")
    }
    private func slotColor(_ id: String) -> Color {
        if id.isEmpty { return Theme.brd2 }
        if id == "rest" { return Theme.restFill }
        if let p = store.plans.first(where: { $0.id == id }) { return Color(hex: p.color) }
        if let c = store.cardioTypes.first(where: { $0.id == id }) { return Color(hex: c.color) }
        return Theme.brd2
    }
    private func slotIcon(_ id: String) -> String? {
        if id.isEmpty || id == "rest" { return nil }
        if store.plans.contains(where: { $0.id == id }) { return "dumbbell.fill" }
        if let c = store.cardioTypes.first(where: { $0.id == id }) { return c.sportType.icon }
        return nil
    }
}

// MARK: - Compact weekly-plan card for Home
struct WeeklyPlanCard: View {
    @EnvironmentObject var store: Store
    @State private var editing = false

    var body: some View {
        let sched = store.prefs.weekSchedule
        let todayMon = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        let heads = L.weekHeaders   // Monday-first single letters
        Button { tap(); editing = true } label: {
            Card {
                HStack(spacing: 2) {
                    Lbl(text: t("plan.week"), color: Theme.acc2)
                    InfoButton(id: "weekplan", color: Theme.acc2)
                    Spacer()
                    Text((store.prefs.hasSchedule ? t("plan.scheduled") : t("plan.rotation")).uppercased())
                        .font(.head(9, .semibold)).tracking(0.8).foregroundColor(Theme.sub)
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(Theme.sub).padding(.leading, 4)
                }
                .padding(.bottom, 12)
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { wd in
                        VStack(spacing: 6) {
                            Text(heads[wd]).font(.head(9, .semibold)).foregroundColor(wd == todayMon ? Theme.acc : Theme.sub)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(slotColor(sched[wd]))
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(wd == todayMon ? Theme.acc : Color.clear, lineWidth: 1.5))
                                .overlay {
                                    // Colors alone can collide (e.g. swimming and a
                                    // pull day sharing a hue); show the activity icon
                                    // too, exactly like rest days show a moon.
                                    if sched[wd] == "rest" { RestChip(size: 11) }
                                    else if let icon = slotIcon(sched[wd]) {
                                        Image(systemName: icon).font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Theme.bg)
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $editing) { WeeklyPlanView() }
    }

    private func slotColor(_ id: String) -> Color {
        if id.isEmpty { return Theme.c3 }
        if id == "rest" { return Theme.restFill }
        if let p = store.plans.first(where: { $0.id == id }) { return Color(hex: p.color) }
        if let c = store.cardioTypes.first(where: { $0.id == id }) { return Color(hex: c.color) }
        return Theme.c3
    }
    /// SF Symbol for an assigned slot: a dumbbell for strength plans, the sport
    /// icon for cardio activities; nil for empty / rest (handled separately).
    private func slotIcon(_ id: String) -> String? {
        if id.isEmpty || id == "rest" { return nil }
        if store.plans.contains(where: { $0.id == id }) { return "dumbbell.fill" }
        if let c = store.cardioTypes.first(where: { $0.id == id }) { return c.sportType.icon }
        return nil
    }
}
