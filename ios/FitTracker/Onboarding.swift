import SwiftUI

// MARK: - App gate: onboarding on first launch, otherwise the main app
struct AppRootView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Group {
            if store.prefs.didOnboard { RootView() }
            else { OnboardingView() }
        }
        // Start the Apple Watch link (no-op without a paired watch) and keep the
        // wrist's workout catalog in sync with the saved plans / cardio types.
        .onAppear { WatchSync.shared.attach(store) }
        .alert(t("store.unreadable_title"), isPresented: Binding(
            get: { loadProblemText != nil }, set: { if !$0 { store.acknowledgeStorageProblem() } })) {
            Button(t("ok")) { store.acknowledgeStorageProblem() }
        } message: { Text(loadProblemText ?? "") }
    }

    /// Text for a problem found while loading. A failed save is shown as a banner
    /// instead (`StorageBanner`), because it can repeat on every autosave.
    private var loadProblemText: String? {
        switch store.storageProblem {
        case .unreadable:           return t("store.unreadable_body")
        case .recovered(let name):  return t("store.recovered_body", name)
        case .saveFailed, .none:    return nil
        }
    }
}

/// Shown above the tab bar for as long as saving keeps failing.
struct StorageBanner: View {
    let reason: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.red)
            Text(t("store.save_failed", reason)).font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.txt).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11).padding(.horizontal, 16)
        .chrome(18, stroke: Theme.red.opacity(0.5))
        .padding(.horizontal, 16)
    }
}

// MARK: - Reusable form pieces
struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // FieldLabel pins the caption to a fixed single-line height, so two
            // FieldRows side by side (e.g. Height / Current weight, Training days /
            // Resting HR) keep their input boxes perfectly aligned regardless of
            // how long the localized label is.
            FieldLabel(label)
            content
        }
    }
}

/// A wrapping set of selectable pills bound to a raw-value string.
struct PillSelect: View {
    var options: [String]
    var title: (String) -> String
    @Binding var selection: String
    var body: some View {
        FlexWrap(options, spacing: 7) { opt in
            let on = opt == selection
            Button { tap(); selection = opt } label: {
                Text(title(opt))
                    .font(.head(12, .semibold))
                    .foregroundColor(on ? Theme.bg : Theme.txt)
                    .padding(.vertical, 9).padding(.horizontal, 14)
                    .chrome(10, fill: on ? Theme.acc : Theme.c2, stroke: on ? Color.clear : Theme.brd)
            }
        }
    }
}

// MARK: - Editable profile state (shared by onboarding & settings)
struct ProfileFields: Equatable {
    var lang: String
    var sex: String
    var birth: Date
    var heightCm: String
    var weight: String
    var goalWeight: String
    var goalMode: String
    var rate: String
    var activity: String
    var trainDays: String
    var restHR: String
    var maxHR: String
    var sleepNeed: String

    init(_ p: Prefs, currentWeight: Double) {
        lang = p.langCode
        sex = p.sex_
        birth = p.birthDate.flatMap { isoFormatter.date(from: $0) }
            ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        // Height/weight are STORED in metric; show them in the active unit system.
        heightCm = trimNum((Units.heightOut(p.height) * 10).rounded() / 10)
        weight = dispW(currentWeight)
        goalWeight = dispW(p.goalWeight)
        goalMode = p.goal.rawValue
        rate = p.weeklyRate.map { dispW(abs($0)) } ?? ""
        activity = p.activityLevel.rawValue
        trainDays = p.trainingDays.map(String.init) ?? ""
        restHR = p.restingHR.map(String.init) ?? ""
        maxHR = p.maxHR.map(String.init) ?? ""
        sleepNeed = p.sleepNeed.map(trimNum) ?? ""
    }

    func apply(to p: inout Prefs, includingGoals: Bool = true) {
        p.language = lang
        p.sex = sex
        p.birthDate = isoFormatter.string(from: birth)
        if pf(heightCm) > 0 { p.height = Units.heightIn(pf(heightCm)) }
        if includingGoals {
            if pf(goalWeight) > 0 { p.goalWeight = Units.wIn(pf(goalWeight)) }
            p.goalMode = goalMode
            p.setWeeklyRate(rate.isEmpty ? nil : Units.wIn(pf(rate)))
        }
        p.activity = activity
        p.trainingDays = Int(trainDays)
        p.restingHR = Int(restHR)
        p.maxHR = Int(maxHR)
        p.sleepNeed = pf(sleepNeed) > 0 ? pf(sleepNeed) : nil
    }
}

private func activityTitle(_ v: String) -> String {
    switch v {
    case "sedentary": return t("ob.act_sed")
    case "light":     return t("ob.act_light")
    case "moderate":  return t("ob.act_mod")
    case "high":      return t("ob.act_high")
    case "athlete":   return t("ob.act_athlete")
    default:          return v
    }
}
/// One-line, day-quantified description of the selected activity level so the
/// user understands exactly what each multiplier means for their calories.
private func activityDesc(_ v: String) -> String {
    switch v {
    case "sedentary": return t("ob.act_sed_d")
    case "light":     return t("ob.act_light_d")
    case "moderate":  return t("ob.act_mod_d")
    case "high":      return t("ob.act_high_d")
    case "athlete":   return t("ob.act_athlete_d")
    default:          return ""
    }
}
/// "Weight to lose (kg/week)" or "to gain", from the goal.
func rateLabel(_ goalMode: String) -> String {
    "\(t(goalMode == GoalMode.cut.rawValue ? "ob.rate_loss" : "ob.rate_gain")) (\(Units.wLabel)/\(t("ob.per_wk")))"
}

private func goalTitle(_ v: String) -> String {
    switch v {
    case "cut":      return t("nut.cut")
    case "maintain": return t("nut.maintain")
    case "bulk":     return t("nut.bulk")
    default:         return v
    }
}

// MARK: - The profile form body (fields only)
struct ProfileFormBody: View {
    @EnvironmentObject var store: Store
    @Binding var f: ProfileFields
    var showLanguage: Bool = true
    /// Settings edits goals in the goal editor only; the first launch asks for them here.
    var showGoals: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showLanguage {
                FieldRow(label: t("ob.language")) {
                    PillSelect(options: ["it", "en"],
                               title: { $0 == "it" ? "Italiano" : "English" },
                               selection: $f.lang)
                }
            }
            FieldRow(label: t("ob.sex")) {
                PillSelect(options: ["m", "f"],
                           title: { $0 == "m" ? t("ob.male") : t("ob.female") },
                           selection: $f.sex)
            }
            FieldRow(label: t("ob.birth")) {
                DatePicker("", selection: $f.birth, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(Theme.acc)
            }
            HStack(spacing: 12) {
                FieldRow(label: "\(t("ob.height")) (\(Units.heightLabel))") { InputField(placeholder: Units.imperial ? "71" : "180", text: $f.heightCm) }
                FieldRow(label: "\(t("ob.weight")) (\(Units.wLabel))") { InputField(placeholder: Units.imperial ? "176" : "80", text: $f.weight) }
            }
            if showGoals {
                FieldRow(label: t("ob.goal_mode")) {
                    PillSelect(options: ["cut", "maintain", "bulk"], title: goalTitle, selection: $f.goalMode)
                }
                HStack(spacing: 12) {
                    FieldRow(label: "\(t("ob.goal_weight")) (\(Units.wLabel))") { InputField(placeholder: Units.imperial ? "165" : "75", text: $f.goalWeight) }
                    // A plain number: the goal says whether it is lost or gained.
                    if f.goalMode != GoalMode.maintain.rawValue {
                        FieldRow(label: rateLabel(f.goalMode)) { InputField(placeholder: Units.imperial ? "1" : "0.5", text: $f.rate) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 2) {
                    Lbl(text: t("ob.activity"))
                    InfoButton(id: .activity)
                    Spacer()
                }
                PillSelect(options: ["sedentary", "light", "moderate", "high", "athlete"],
                           title: activityTitle, selection: $f.activity)
                Text(activityDesc(f.activity)).font(.system(size: 11)).foregroundColor(Theme.sub)
                    .padding(.top, 2)
            }
            HStack(spacing: 12) {
                FieldRow(label: t("ob.train_days")) { InputField(placeholder: "4", text: $f.trainDays, keyboard: .numberPad) }
                FieldRow(label: t("ob.rest_hr")) { InputField(placeholder: "60", text: $f.restHR, keyboard: .numberPad) }
            }
            FieldRow(label: t("ob.max_hr")) { InputField(placeholder: "—", text: $f.maxHR, keyboard: .numberPad) }
            // Learned from the workouts, offered and never applied alone.
            if let suggested = store.suggestedMaxHR, f.maxHR != String(suggested) {
                Button { f.maxHR = String(suggested) } label: {
                    Text(t("ob.max_hr_suggest", suggested)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.acc2)
                }
                .buttonStyle(.plain)
            }
            FieldRow(label: t("ob.sleep_need")) { InputField(placeholder: "8", text: $f.sleepNeed, keyboard: .decimalPad) }
        }
    }
}

// MARK: - Clean starting numbers per sex (round, generic placeholders)
struct SexDefaults { let height: String; let weight: String; let goal: String }
let maleDefaults   = SexDefaults(height: "180", weight: "80", goal: "75")
let femaleDefaults = SexDefaults(height: "165", weight: "65", goal: "60")

// MARK: - Onboarding (first launch)
struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var f: ProfileFields
    @State private var showGuide = false

    init() {
        // Store isn't available at init time; seed with defaults, refresh on appear.
        _f = State(initialValue: ProfileFields(Prefs(), currentWeight: 80))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            Text("FIT TR").foregroundColor(Theme.txt)
                            Text("A").foregroundColor(Theme.acc)
                            Text("CKER").foregroundColor(Theme.txt)
                        }
                        .font(.head(28, .bold)).tracking(1)
                        Text(t("ob.welcome").uppercased())
                            .font(.head(13, .semibold)).tracking(2).foregroundColor(Theme.acc)
                        Text(t("ob.intro")).font(.system(size: 14)).foregroundColor(Theme.sub).lineSpacing(4)
                    }
                    .padding(.top, 30)

                    Card { ProfileFormBody(f: $f) }

                    // Optional: point new users at the watch-setup guide so any
                    // wearable (Apple Watch, Garmin, Polar, Huawei via file…) can
                    // feed the app from day one.
                    Card {
                        Lbl(text: t("guide.open"), color: Theme.acc2).padding(.bottom, 6)
                        Text(t("guide.intro")).font(.system(size: 11)).foregroundColor(Theme.sub).lineSpacing(3)
                            .padding(.bottom, 10)
                        GhostButton(title: t("guide.open"), color: Theme.blue) { showGuide = true }
                    }

                    BigButton(title: t("ob.finish")) { finish() }
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showGuide) { WatchSetupGuide() }
        .onChange(of: f.lang) { store.prefs.language = f.lang; store.syncLang() }
        .onChange(of: f.sex) { _, newSex in
            // Swap in the selected sex's clean defaults, but only if the user
            // hasn't already typed their own numbers (i.e. the fields still hold
            // the other sex's defaults).
            let from = newSex == "m" ? femaleDefaults : maleDefaults
            let to   = newSex == "m" ? maleDefaults   : femaleDefaults
            if f.heightCm == from.height && f.weight == from.weight && f.goalWeight == from.goal {
                f.heightCm = to.height; f.weight = to.weight; f.goalWeight = to.goal
            }
        }
        .onAppear { f = ProfileFields(store.prefs, currentWeight: store.lastWeight) }
    }

    private func finish() {
        var p = store.prefs
        f.apply(to: &p)
        let wKg = Units.wIn(pf(f.weight))    // input is in the active unit; store kg
        p.startWeight = wKg > 0 ? wKg : p.startWeight
        p.onboarded = true
        store.prefs = p
        store.syncLang()
        if wKg > 0 { store.saveCheckIn(weight: wKg, sleep: nil) }
        haptic(.success)
    }
}
