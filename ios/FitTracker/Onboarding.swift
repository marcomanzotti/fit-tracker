import SwiftUI

// MARK: - App gate: onboarding on first launch, otherwise the main app
struct AppRootView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Group {
            if store.prefs.didOnboard { RootView() }
            else { OnboardingView() }
        }
    }
}

// MARK: - Reusable form pieces
struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Lbl(text: label)
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
                    .background(on ? Theme.acc : Theme.c2)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(on ? Color.clear : Theme.brd, lineWidth: 1))
            }
        }
    }
}

// MARK: - Editable profile state (shared by onboarding & settings)
struct ProfileFields {
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

    init(_ p: Prefs, currentWeight: Double) {
        lang = p.langCode
        sex = p.sex_
        birth = p.birthDate.flatMap { isoFormatter.date(from: $0) }
            ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        heightCm = trimNum(p.height * 100)
        weight = trimNum(currentWeight)
        goalWeight = trimNum(p.goalWeight)
        goalMode = p.goal.rawValue
        rate = p.weeklyRate.map { trimNum($0) } ?? ""
        activity = p.activityLevel.rawValue
        trainDays = p.trainingDays.map(String.init) ?? ""
        restHR = p.restingHR.map(String.init) ?? ""
        maxHR = p.maxHR.map(String.init) ?? ""
    }

    func apply(to p: inout Prefs) {
        p.language = lang
        p.sex = sex
        p.birthDate = isoFormatter.string(from: birth)
        if pf(heightCm) > 0 { p.height = pf(heightCm) / 100 }
        if pf(goalWeight) > 0 { p.goalWeight = pf(goalWeight) }
        p.goalMode = goalMode
        p.weeklyRate = rate.isEmpty ? nil : pf(rate)
        p.activity = activity
        p.trainingDays = Int(trainDays)
        p.restingHR = Int(restHR)
        p.maxHR = Int(maxHR)
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
    @Binding var f: ProfileFields
    var showLanguage: Bool = true

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
                FieldRow(label: t("ob.height")) { InputField(placeholder: "180", text: $f.heightCm) }
                FieldRow(label: t("ob.weight")) { InputField(placeholder: "80", text: $f.weight) }
            }
            FieldRow(label: t("ob.goal_mode")) {
                PillSelect(options: ["cut", "maintain", "bulk"], title: goalTitle, selection: $f.goalMode)
            }
            HStack(spacing: 12) {
                FieldRow(label: t("ob.goal_weight")) { InputField(placeholder: "75", text: $f.goalWeight) }
                FieldRow(label: t("ob.rate")) { InputField(placeholder: "-0.5", text: $f.rate) }
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 2) {
                    Lbl(text: t("ob.activity"))
                    InfoButton(id: "activity")
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

                    BigButton(title: t("ob.finish")) { finish() }
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onChange(of: f.lang) { _ in store.prefs.language = f.lang; store.syncLang() }
        .onChange(of: f.sex) { newSex in
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
        p.startWeight = pf(f.weight) > 0 ? pf(f.weight) : p.startWeight
        p.onboarded = true
        store.prefs = p
        store.syncLang()
        if pf(f.weight) > 0 { store.saveCheckIn(weight: pf(f.weight), sleep: nil) }
        haptic(.success)
    }
}

// MARK: - Settings / edit profile (sheet)
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @State private var f: ProfileFields
    @State private var sleepTrack: Bool
    @State private var timerSec: String
    @State private var hkOn: Bool

    init(store: Store) {
        _f = State(initialValue: ProfileFields(store.prefs, currentWeight: store.lastWeight))
        _sleepTrack = State(initialValue: store.prefs.sleepEnabled)
        _timerSec = State(initialValue: String(store.prefs.timer))
        _hkOn = State(initialValue: store.prefs.healthKitEnabled)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(t("set.title").uppercased()).font(.head(18, .bold)).tracking(1).foregroundColor(Theme.txt)
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    Card {
                        Lbl(text: t("set.profile"))
                        Spacer().frame(height: 14)
                        ProfileFormBody(f: $f)
                    }

                    Card {
                        Toggle(isOn: $sleepTrack) {
                            Text(t("set.sleep_track")).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.txt)
                        }
                        .tint(Theme.acc)
                        Spacer().frame(height: 14)
                        FieldRow(label: t("set.timer")) {
                            InputField(placeholder: "60", text: $timerSec, keyboard: .numberPad)
                        }
                    }

                    healthCard

                    BigButton(title: t("save")) { save() }
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Apple Health (optional data source)
    private var healthCard: some View {
        Card {
            HStack(spacing: 2) {
                Lbl(text: t("hk.connect"), color: Theme.acc2)
                InfoButton(id: "steps", color: Theme.acc2)
                Spacer()
            }
            .padding(.bottom, 8)
            Text(t("hk.hint")).font(.system(size: 11)).foregroundColor(Theme.sub).lineSpacing(3).padding(.bottom, 12)
            if HealthKitManager.shared.isAvailable {
                if hkOn {
                    HStack(spacing: 10) {
                        Text(t("hk.connected").uppercased()).font(.head(11, .semibold)).tracking(0.5).foregroundColor(Theme.good)
                        Spacer()
                        GhostButton(title: t("hk.sync"), color: Theme.acc) {
                            store.syncHealth { ok in if ok { toast.show(t("hk.synced")) } }
                        }
                    }
                } else {
                    FilledButton(title: t("hk.connect")) {
                        store.syncHealth { ok in
                            if ok { hkOn = true; store.prefs.healthKit = true; toast.show(t("hk.synced")) }
                        }
                    }
                }
            } else {
                Text(t("hk.unavailable")).font(.system(size: 12)).foregroundColor(Theme.sub)
            }
        }
    }

    private func save() {
        var p = store.prefs
        f.apply(to: &p)
        p.sleepTracking = sleepTrack
        p.healthKit = hkOn
        if let ts = Int(timerSec), ts > 0 { p.timer = ts }
        store.prefs = p
        store.syncLang()
        haptic(.success)
        dismiss()
    }
}
