import SwiftUI

// MARK: - Info points
// Every metric carries a small "i". It opens a sheet that explains what the
// number means and how it is computed, in Italian or English (a toggle in the
// sheet), and, when the metric has reference ranges, a colored scale with the
// user's own value on it.

/// Every info point. The text lives in Localization under info.<rawValue>.title /
/// .body; a typo in a topic does not compile, and a test checks both languages.
enum InfoTopic: String, CaseIterable {
    // Load and training
    case trimp, acwr, load, monotony, strain, overload, volume, muscleVol = "muscle_vol"
    case calories, pace, activity, weekplan, streak, goal
    case form, recovery, intensity, decoupling, strength, e1rm, effort
    // Recovery and sleep
    case readiness, hrv, vitals, nightVitals = "night_vitals", sleep, sleepStages = "sleep_stages"
    case sleepEff = "sleep_eff", sleepReg = "sleep_reg", sleepHR = "sleep_hr", sleepDebt = "sleep_debt"
    case jetLag = "jet_lag", hrvStability = "hrv_stability"
    case spo2, respRate = "resp_rate", wristTemp = "wrist_temp"
    // Heart and fitness
    case restingHR = "resting_hr", walkingHR = "walking_hr", hrRecovery = "hr_recovery", vo2max, fitness
    case fitnessAge = "fitness_age"
    // Daily activity
    case steps, activeKcal = "active_kcal", exerciseMin = "exercise_min", stand, daylight, flights
    // Body
    case weight, bmi, bodyfat, ffmi, measures, navy
    // Nutrition
    case tdee, macros, carbcycle, lea, trend, adherence, intake, nutCalendar = "nut_calendar", salt

    var titleKey: String { "info.\(rawValue).title" }
    var bodyKey: String { "info.\(rawValue).body" }
}

extension HealthCategory {
    var info: InfoTopic {
        switch self {
        case .steps:       return .steps
        case .restHR:      return .restingHR
        case .hrv:         return .hrv
        case .sleep:       return .sleep
        case .sleepHR:     return .sleepHR
        case .activeKcal:  return .activeKcal
        case .exerciseMin: return .exerciseMin
        case .vo2max:      return .vo2max
        case .spo2:        return .spo2
        case .respRate:    return .respRate
        case .wristTemp:   return .wristTemp
        case .walkingHR:   return .walkingHR
        case .hrRecovery:  return .hrRecovery
        case .standHours:  return .stand
        case .daylight:    return .daylight
        case .flights:     return .flights
        case .weight:      return .weight
        case .bodyFat:     return .bodyfat
        }
    }
}

// MARK: - Reference scales
enum Tone {
    case bad, fair, good, great
    var color: Color {
        switch self {
        case .bad:   return Theme.red
        case .fair:  return Theme.acc2
        case .good:  return Theme.good.opacity(0.6)
        case .great: return Theme.good
        }
    }
}

/// One band of a scale: from the previous band's upper bound up to `upTo`.
struct InfoBand {
    var upTo: Double
    var key: String            // band.<key> in Localization
    var tone: Tone
}

struct InfoScale {
    var from: Double
    var bands: [InfoBand]      // ascending
    var unit = ""
    var decimals = 0
    var to: Double { bands.last?.upTo ?? from }
    func lower(_ i: Int) -> Double { i == 0 ? from : bands[i - 1].upTo }
    func bandIndex(of v: Double) -> Int { bands.firstIndex { v < $0.upTo } ?? bands.count - 1 }
    func format(_ v: Double) -> String { String(format: "%.\(decimals)f", v) }
}

private func band(_ upTo: Double, _ key: String, _ tone: Tone) -> InfoBand { InfoBand(upTo: upTo, key: key, tone: tone) }

extension Store {
    /// The reference ranges of a metric, built from the user's profile where they
    /// depend on it (VO₂max, body fat and FFMI by sex and age; vitals and HRV from
    /// the user's own last 60 days). nil for metrics with no meaningful scale.
    func infoScale(_ topic: InfoTopic) -> InfoScale? { memo("infoScale|\(topic.rawValue)") { computeInfoScale(topic) } }

    /// Label key and colour of a value on a metric's scale: the one place cards
    /// take their wording from, so a card and its "i" sheet never disagree.
    func scaleBand(_ topic: InfoTopic, _ value: Double) -> (key: String, color: Color)? {
        guard let scale = infoScale(topic) else { return nil }
        let b = scale.bands[scale.bandIndex(of: value)]
        return ("band." + b.key, b.tone.color)
    }

    private func computeInfoScale(_ topic: InfoTopic) -> InfoScale? {
        let female = prefs.sex_ == "f"
        switch topic {
        case .readiness:
            return InfoScale(from: 0, bands: [band(Double(Store.readinessRestBelow), "rest", .bad),
                                              band(Double(Store.readinessReadyFrom), "easy", .fair),
                                              band(70, "ready", .good), band(100, "optimal", .great)])
        case .acwr:
            return InfoScale(from: 0, bands: [band(0.8, "detraining", .fair), band(1.3, "sweet_spot", .great),
                                              band(1.5, "caution", .fair), band(2, "danger", .bad)], decimals: 2)
        case .monotony:
            return InfoScale(from: 0, bands: [band(1.5, "varied", .great), band(2, "caution", .fair),
                                              band(3, "monotonous", .bad)], decimals: 1)
        case .strain:
            guard let avg = averageStrain() else { return nil }
            return InfoScale(from: 0, bands: [band(avg * 0.8, "lighter", .good), band(avg * 1.2, "usual", .great),
                                              band(avg * 1.5, "high", .fair), band(avg * 2, "very_high", .bad)])
        case .trimp:
            return InfoScale(from: 0, bands: [band(80, "light", .great), band(150, "moderate", .good),
                                              band(250, "hard", .fair), band(400, "very_hard", .bad)])
        case .sleep:
            return InfoScale(from: 0, bands: [band(50, "poor", .bad), band(70, "fair", .fair),
                                              band(85, "good", .good), band(100, "excellent", .great)])
        case .sleepStages:
            return InfoScale(from: 0, bands: [band(10, "low", .bad), band(13, "slightly_low", .fair),
                                              band(23, "normal", .great), band(35, "high", .good)], unit: "%")
        case .sleepEff:
            return InfoScale(from: 50, bands: [band(75, "poor", .bad), band(85, "fair", .fair),
                                               band(100, "good", .great)], unit: "%")
        case .sleepReg:
            return InfoScale(from: 0, bands: [band(30, "regular", .great), band(60, "fair", .good),
                                              band(90, "irregular", .fair), band(150, "very_irregular", .bad)], unit: "min")
        case .spo2:
            return InfoScale(from: 85, bands: [band(90, "very_low", .bad), band(Store.spo2LowPercent, "low", .fair),
                                               band(95, "slightly_low", .good), band(100, "normal", .great)], unit: "%")
        case .respRate:
            return personalScale(.respRate, higherIsBetter: nil, floor: 1, unit: "/min", decimals: 1)
                ?? InfoScale(from: 8, bands: [band(12, "low", .fair), band(20, "normal", .great),
                                              band(25, "high", .bad)], unit: "/min")
        case .wristTemp:
            guard personalRange({ $0.wristTemp }, before: today()) != nil else { return nil }
            return InfoScale(from: -1.5, bands: [band(-0.5, "below_usual", .fair), band(0.5, "usual", .great),
                                                 band(1, "above_usual", .fair), band(2, "high", .bad)],
                             unit: "°C", decimals: 1)
        case .hrv:
            return personalScale(.hrvSleep, higherIsBetter: true, floor: 6, unit: "ms")
        case .sleepHR:
            return personalScale(.sleepHR, higherIsBetter: false, floor: 3, unit: "bpm")
        case .walkingHR:
            return personalScale(.walkingHR, higherIsBetter: false, floor: 3, unit: "bpm")
        case .restingHR:
            return InfoScale(from: 35, bands: [band(50, "athlete", .great), band(60, "excellent", .great),
                                               band(70, "good", .good), band(80, "average", .fair),
                                               band(100, "high", .bad)], unit: "bpm")
        case .hrRecovery:
            return InfoScale(from: 0, bands: [band(12, "poor", .bad), band(20, "fair", .fair),
                                              band(30, "good", .good), band(50, "excellent", .great)], unit: "bpm")
        case .vo2max, .fitness:
            let t = vo2Thresholds()
            return InfoScale(from: max(10, t[0] - 8), bands: [band(t[0], "very_poor", .bad), band(t[1], "poor", .bad),
                                                             band(t[2], "fair", .fair), band(t[3], "good", .good),
                                                             band(t[4], "excellent", .great), band(t[4] + 10, "superior", .great)],
                             unit: "mL/kg·min", decimals: 1)
        case .steps:
            return InfoScale(from: 0, bands: [band(5_000, "sedentary", .bad), band(7_500, "low_active", .fair),
                                              band(10_000, "active", .good), band(15_000, "very_active", .great)])
        case .stand:
            return InfoScale(from: 0, bands: [band(6, "low", .bad), band(10, "fair", .fair),
                                              band(12, "good", .good), band(16, "excellent", .great)], unit: "h")
        case .daylight:
            return InfoScale(from: 0, bands: [band(20, "low", .bad), band(60, "fair", .fair),
                                              band(120, "good", .good), band(240, "excellent", .great)], unit: "min")
        case .flights:
            return InfoScale(from: 0, bands: [band(3, "low", .fair), band(10, "good", .good),
                                              band(25, "excellent", .great)])
        case .bmi:
            return InfoScale(from: 15, bands: [band(18.5, "underweight", .fair), band(25, "normal", .great),
                                               band(30, "overweight", .fair), band(40, "obese", .bad)], decimals: 1)
        case .bodyfat:
            let b: [Double] = female ? [14, 21, 25, 32, 45] : [6, 14, 18, 25, 40]
            return InfoScale(from: female ? 10 : 2, bands: [band(b[0], "essential", .fair), band(b[1], "athletic", .great),
                                                            band(b[2], "fitness", .good), band(b[3], "average", .fair),
                                                            band(b[4], "high", .bad)], unit: "%", decimals: 1)
        case .ffmi:
            let s = female ? -3.0 : 0
            return InfoScale(from: 15 + s, bands: [band(18 + s, "below_average", .fair), band(20 + s, "average", .good),
                                                   band(22 + s, "above_average", .good), band(23 + s, "excellent", .great),
                                                   band(26 + s, "superior", .great), band(28 + s, "rare", .fair)], decimals: 1)
        case .lea:
            return InfoScale(from: 0, bands: [band(30, "risk", .bad), band(45, "caution", .fair),
                                              band(65, "adequate", .great)], unit: "kcal/kg")
        case .macros:
            return InfoScale(from: 0.5, bands: [band(1.2, "low", .bad), band(1.6, "fair", .fair),
                                                band(2.2, "optimal", .great), band(3, "high", .good)], unit: "g/kg", decimals: 1)
        case .intake:
            return InfoScale(from: 50, bands: [band(80, "well_under", .bad), band(90, "under", .fair),
                                               band(110, "on_target", .great), band(120, "over", .fair),
                                               band(150, "well_over", .bad)], unit: "%")
        case .adherence:
            return InfoScale(from: 0, bands: [band(50, "low", .bad), band(80, "fair", .fair),
                                              band(100, "good", .great)], unit: "%")
        case .form:
            // A share of fitness (intervals.icu bands), so it does not depend on the TRIMP unit.
            return InfoScale(from: -50, bands: [band(-30, "overreaching", .bad), band(-10, "productive", .great),
                                                band(5, "maintaining", .good), band(25, "fresh", .great),
                                                band(50, "detraining", .fair)], unit: "%")
        case .intensity:
            return InfoScale(from: 0, bands: [band(60, "too_hard", .bad), band(75, "mixed", .fair),
                                              band(90, "polarized", .great), band(100, "mostly_easy", .good)], unit: "%")
        case .decoupling:
            return InfoScale(from: -5, bands: [band(5, "aerobic_solid", .great), band(10, "fair", .fair),
                                               band(25, "drifting", .bad)], unit: "%", decimals: 1)
        case .sleepDebt:
            return InfoScale(from: 0, bands: [band(3, "low", .great), band(7, "moderate", .fair),
                                              band(14, "high", .bad), band(25, "very_high", .bad)], unit: "h", decimals: 1)
        case .jetLag:
            return InfoScale(from: 0, bands: [band(30, "low", .great), band(60, "fair", .good),
                                              band(120, "high", .fair), band(240, "very_high", .bad)], unit: "min")
        case .hrvStability:
            return InfoScale(from: 0, bands: [band(5, "stable", .great), band(10, "normal", .good),
                                              band(15, "unstable", .fair), band(25, "very_unstable", .bad)],
                             unit: "%", decimals: 1)
        case .fitnessAge:
            guard let age = prefs.age.map(Double.init) else { return nil }
            return InfoScale(from: max(15, age - 25), bands: [band(age - 5, "younger", .great), band(age + 5, "in_line", .good),
                                                              band(age + 25, "older", .fair)])
        default:
            return nil
        }
    }

    /// The user's value for a topic's scale: the latest reading for nightly
    /// values, a 7-day average (today excluded, it is not over yet) for daily
    /// totals.
    func infoValue(_ topic: InfoTopic) -> Double? { memo("infoValue|\(topic.rawValue)") { computeInfoValue(topic) } }

    private func computeInfoValue(_ topic: InfoTopic) -> Double? {
        func latest(_ f: HealthField) -> Double? { sortedDaily.last { ($0[f] ?? 0) > 0 }?[f] }
        switch topic {
        case .readiness:   return readiness().score.map(Double.init)
        case .acwr:        return acwr().ratio
        case .monotony:    return weekLoad(offset: 0).monotony
        case .strain:      return weekLoad(offset: 0).strain
        case .trimp:       return lastSessionTrimp()?.value
        case .sleep:       return sortedDaily.last { ($0.sleep ?? 0) > 0 }?.sleep.map(Double.init)
        case .sleepStages: return lastNight(\.deepShare)
        case .sleepEff:    return lastNight(\.efficiency)
        case .sleepReg:
            return sortedDaily.last { $0.sleepEndMin != nil }.flatMap { sleepRegularity(endingOn: $0.date) }
        case .spo2:        return latest(.spo2)
        case .respRate:    return latest(.respRate)
        case .wristTemp:
            guard let v = latestRecent({ $0.wristTemp }),
                  let r = personalRange({ $0.wristTemp }, before: v.date) else { return nil }
            return v.value - r.mean
        case .hrv:         return latest(.hrvSleep)
        case .sleepHR:     return latest(.sleepHR)
        case .walkingHR:   return latest(.walkingHR)
        case .restingHR:   return latest(.restHR) ?? prefs.restingHR.map(Double.init)
        case .hrRecovery:  return latest(.hrRecovery)
        case .vo2max, .fitness: return vo2maxEstimate()?.value
        case .steps:       return weekAverage(.steps)
        case .stand:       return weekAverage(.standHours)
        case .daylight:    return weekAverage(.daylightMin)
        case .flights:     return weekAverage(.flights)
        case .bmi:         return bmi(lastWeight)
        case .bodyfat:     return currentBF
        case .ffmi:        return ffmi()?.normalized
        case .lea:         return energyAvailability().ea
        case .macros:
            let days = pastWeek.filter { $0.hasNutrition }
            guard !days.isEmpty, lastWeight > 0 else { return nil }
            return days.reduce(0) { $0 + $1.totalProtein } / Double(days.count) / lastWeight
        case .intake:
            let days = pastWeek.filter { $0.totalKcal > 0 }
            let target = energyTargets().target
            guard !days.isEmpty, target > 0 else { return nil }
            return Double(days.reduce(0) { $0 + $1.totalKcal }) / Double(days.count) / target * 100
        case .adherence:   return adherence().loggingPct * 100
        case .form:        return formPercent()
        case .intensity:
            let recent = intensityWeeks().suffix(4)
            let total = recent.reduce(0) { $0 + $1.total }
            return total > 0 ? recent.reduce(0) { $0 + $1.zoneSeconds[0] + $1.zoneSeconds[1] } / total * 100 : nil
        case .decoupling:  return lastDecoupling?.value
        case .sleepDebt:   return sleepDebt()
        case .jetLag:      return socialJetLag()
        case .hrvStability: return hrvStability()
        case .fitnessAge:  return fitnessAge().map(Double.init)
        default:           return nil
        }
    }

    /// The seven days before today.
    private var pastWeek: [DailyEntry] {
        let from = Calendar.current.date(byAdding: .day, value: -7, to: Date()).map { isoFormatter.string(from: $0) } ?? ""
        let todayKey = today()
        return sortedDaily.filter { $0.date >= from && $0.date < todayKey }
    }

    private func weekAverage(_ f: HealthField) -> Double? {
        average(pastWeek.compactMap { $0[f] }.filter { $0 > 0 })
    }

    private func lastNight(_ value: KeyPath<DailyEntry, Double?>) -> Double? {
        sortedDaily.last { $0[keyPath: value] != nil }?[keyPath: value]
    }

    /// The mean strain of the four weeks before this one, the reference for this
    /// week's (strain has no universal scale, only a personal one).
    private func averageStrain() -> Double? {
        let past = (1...4).compactMap { weekLoad(offset: $0).strain }
        guard !past.isEmpty else { return nil }
        let avg = past.reduce(0, +) / Double(past.count)
        return avg > 0 ? avg : nil
    }

    /// A scale centred on the user's own last 60 days. `higherIsBetter` nil means
    /// both directions away from usual are worth a look (breathing rate).
    private func personalScale(_ f: HealthField, higherIsBetter: Bool?, floor: Double,
                               unit: String, decimals: Int = 0) -> InfoScale? {
        guard let r = personalRange({ $0[f] }, before: today()) else { return nil }
        let m = r.mean, b = max(2 * r.sd, floor), h = b / 2
        switch higherIsBetter {
        case true?:
            return InfoScale(from: m - 2 * b, bands: [band(m - b, "below_usual", .bad), band(m - h, "slightly_low", .fair),
                                                       band(m + h, "usual", .good), band(m + 2 * b, "above_usual", .great)],
                             unit: unit, decimals: decimals)
        case false?:
            return InfoScale(from: m - 2 * b, bands: [band(m - h, "below_usual", .great), band(m + h, "usual", .good),
                                                       band(m + b, "slightly_high", .fair), band(m + 2 * b, "above_usual", .bad)],
                             unit: unit, decimals: decimals)
        case nil:
            return InfoScale(from: m - 2 * b, bands: [band(m - b, "below_usual", .fair), band(m + b, "usual", .great),
                                                       band(m + 2 * b, "above_usual", .bad)],
                             unit: unit, decimals: decimals)
        }
    }

    /// Upper bounds of the VO₂max classes very poor … excellent for the user's sex
    /// and age (Cooper Institute norms; under 20 uses the 20–29 row).
    func vo2Thresholds(age: Int? = nil) -> [Double] {
        let men: [[Double]] = [[33, 36.5, 42.5, 46.5, 52.5], [31.5, 35.5, 41, 45, 49.5], [30.2, 33.6, 39, 43.8, 48.1],
                               [26.1, 31, 35.8, 41, 45.4], [20.5, 26.1, 32.3, 36.5, 44.3]]
        let women: [[Double]] = [[23.6, 29, 33, 37, 41.1], [22.8, 27, 31.5, 35.7, 40.1], [21, 24.5, 29, 32.9, 37],
                                 [20.2, 22.8, 27, 31.5, 35.8], [17.5, 20.2, 24.5, 30.3, 31.5]]
        let row = min(4, max(0, ((age ?? prefs.age ?? 30) - 20) / 10))
        return (prefs.sex_ == "f" ? women : men)[row]
    }
}

extension DailyEntry {
    /// Deep sleep as a share of the time asleep, % (nil without stages).
    var deepShare: Double? {
        guard let deep = sleepDeepMin else { return nil }
        let staged = Double(deep + (sleepREMMin ?? 0) + (sleepCoreMin ?? 0))
        return staged > 0 ? Double(deep) / staged * 100 : nil
    }
    /// Time asleep over time in bed, %.
    var efficiency: Double? {
        guard let h = sleepHours, let bed = inBedHours, bed > 0 else { return nil }
        return min(100, h / bed * 100)
    }
}

// MARK: - Range bar
/// Colored bands of a scale with a marker at the user's value. The band the
/// value falls in is drawn at full strength, the others faded.
struct RangeBar: View {
    let scale: InfoScale
    let value: Double?
    var height: CGFloat = 10

    var body: some View {
        let current = value.map { scale.bandIndex(of: $0) }
        GeometryReader { geo in
            let span = max(scale.to - scale.from, .ulpOfOne)
            let gap: CGFloat = 2
            let usable = geo.size.width - gap * CGFloat(scale.bands.count - 1)
            ZStack(alignment: .leading) {
                HStack(spacing: gap) {
                    ForEach(scale.bands.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .fill(scale.bands[i].tone.color.opacity(current == nil || current == i ? 1 : 0.35))
                            .frame(width: max(2, usable * CGFloat((scale.bands[i].upTo - scale.lower(i)) / span)))
                    }
                }
                if let value {
                    let x = geo.size.width * CGFloat((min(max(value, scale.from), scale.to) - scale.from) / span)
                    Capsule().fill(Theme.txt)
                        .frame(width: 4, height: height + 10)
                        .overlay(Capsule().stroke(Theme.bg, lineWidth: 1.5))
                        .offset(x: min(max(0, x - 2), geo.size.width - 4))
                }
            }
            .frame(height: height + 10)
        }
        .frame(height: height + 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let value else { return "" }
        let b = scale.bands[scale.bandIndex(of: value)]
        return "\(scale.format(value)) \(scale.unit), \(t("band." + b.key))"
    }
}

// MARK: - Info button + sheet
struct InfoButton: View {
    let id: InfoTopic
    var color: Color = Theme.sub
    var size: CGFloat = 26         // visible size; the tap area is always 44 pt
    @State private var show = false
    var body: some View {
        Button { show = true } label: {
            Image(systemName: "info.circle").font(.ui(13)).foregroundColor(color)
                .frame(width: size, height: size)
        }
        .buttonStyle(PressableStyle())
        .hitArea((Theme.minTapTarget - size) / 2)
        .accessibilityLabel("\(t("a11y.info")): \(t(id.titleKey))")
        .sheet(isPresented: $show) { InfoSheet(topic: id) }
    }
}

struct InfoSheet: View {
    let topic: InfoTopic
    @Environment(Store.self) var store
    @Environment(\.dismiss) private var dismiss
    @State private var lang = L.lang

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(L.t(topic.titleKey, lang: lang)).font(.head(20, .bold)).tracking(0.3)
                            .foregroundColor(Theme.acc).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        ChipPicker(options: ["it", "en"], selection: $lang) { $0.uppercased() }
                            .padding(.top, 4)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub)
                                .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        }
                        .accessibilityLabel(L.t("a11y.close", lang: lang))
                    }
                    if let scale = store.infoScale(topic) { scaleCard(scale, value: store.infoValue(topic)) }
                    Text(L.t(topic.bodyKey, lang: lang))
                        .font(.ui(14)).foregroundColor(Theme.txt).lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 10)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    /// The scale, the user's value on it, and every band with its numbers.
    private func scaleCard(_ scale: InfoScale, value: Double?) -> some View {
        let current = value.map { scale.bandIndex(of: $0) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L.t("info.your_value", lang: lang).uppercased())
                    .font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                Spacer()
                if let value, let current {
                    Text("\(scale.format(value)) \(scale.unit)").font(.num(18)).foregroundColor(Theme.txt).monospacedDigit()
                    Text(L.t("band." + scale.bands[current].key, lang: lang))
                        .font(.head(11, .semibold)).foregroundColor(scale.bands[current].tone.color)
                } else {
                    Text(L.t("info.no_value", lang: lang)).font(.ui(12)).foregroundColor(Theme.sub)
                }
            }
            RangeBar(scale: scale, value: value)
            VStack(spacing: 6) {
                ForEach(Array(scale.bands.enumerated().reversed()), id: \.offset) { i, b in
                    HStack(spacing: 8) {
                        Circle().fill(b.tone.color).frame(width: 8, height: 8)
                        Text(L.t("band." + b.key, lang: lang)).font(.ui(13, weight: current == i ? .bold : .regular))
                            .foregroundColor(current == i ? Theme.txt : Theme.sub)
                        Spacer()
                        Text(rangeText(scale, i)).font(.num(12, .medium)).monospacedDigit()
                            .foregroundColor(current == i ? Theme.txt : Theme.sub)
                    }
                }
            }
        }
        .padding(14)
        .chrome(Theme.radiusS, fill: Theme.c1, stroke: Theme.brd)
    }

    /// "18.5–25", "< 30" for the first band, "≥ 52.5" for the last.
    private func rangeText(_ s: InfoScale, _ i: Int) -> String {
        let unit = s.unit.isEmpty ? "" : " \(s.unit)"
        if i == 0 { return "< \(s.format(s.bands[0].upTo))\(unit)" }
        if i == s.bands.count - 1 { return "≥ \(s.format(s.lower(i)))\(unit)" }
        return "\(s.format(s.lower(i)))–\(s.format(s.bands[i].upTo))\(unit)"
    }
}
