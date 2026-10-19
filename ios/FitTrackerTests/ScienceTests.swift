import XCTest
@testable import FitTracker

/// The numbers the app advises with: nutrition adherence, streak, progression,
/// scheduling and body-fat bounds.
final class ScienceTests: XCTestCase {
    private var dir: URL!
    private var store: Store!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fittracker-science-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = Store(directory: dir)
    }

    override func tearDownWithError() throws {
        store = nil
        try FileManager.default.removeItem(at: dir)
    }

    /// yyyy-MM-dd for `days` days before today.
    private func day(_ days: Int) -> String {
        isoFormatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!)
    }

    private func benchSession(daysAgo: Int, reps: [String], weight: String = "80") -> WorkoutSession {
        let sets = reps.map { SetEntry(reps: $0, weight: weight) }
        return WorkoutSession(date: day(daysAgo), planId: "p1", planName: "Push", planColor: "ff5a52",
                              exercises: [LoggedExercise(name: "Barbell bench press", sets: sets,
                                                         notes: "", target: "4×6-8")])
    }

    // MARK: Nutrition

    func testAdherenceCountsDaysLoggedByMealOrByFood() {
        let food = FoodLog(name: "Rice", grams: 200, k100: 130, p100: 2.7, c100: 28, f100: 0.3)
        store.daily = [
            DailyEntry(date: day(1), kcal: 2_100),                                              // quick total
            DailyEntry(date: day(2), meals: ["lunch": MealEntry(kcal: 700, protein: 40)]),      // per meal
            DailyEntry(date: day(3), foods: [food])                                             // per food
        ]

        let adherence = store.adherence(days: 14)

        XCTAssertEqual(adherence.loggingPct, 3.0 / 14.0, accuracy: 0.0001)
        XCTAssertEqual(adherence.avgIntake, (2_100 + 700 + 260) / 3)
        XCTAssertNotEqual(adherence.status, "none")
    }

    // MARK: Streak

    func testStreakIgnoresDaysThatOnlyHoldHealthImports() {
        store.daily = [
            DailyEntry(date: day(1), weight: 80),
            DailyEntry(date: day(2), steps: 9_000),          // imported from Health, nothing logged
            DailyEntry(date: day(3), steps: 8_000),
            DailyEntry(date: day(4), weight: 80.2)
        ]
        XCTAssertEqual(store.streak, 1, "only yesterday was actually logged")
    }

    func testStreakCountsCheckInsSessionsNutritionAndRestDays() {
        store.daily = [DailyEntry(date: day(1), weight: 80),
                       DailyEntry(date: day(3), kcal: 2_000)]
        store.sessions = [benchSession(daysAgo: 2, reps: ["8"])]
        store.setRestDay(day(4), on: true)
        XCTAssertEqual(store.streak, 4)
    }

    // MARK: Progression

    func testOneSessionAtTheTopOfTheRangeAfterAShortfallStaysOnReps() {
        store.sessions = [benchSession(daysAgo: 2, reps: ["8", "8", "8", "8"]),      // latest: at ceiling
                          benchSession(daysAgo: 5, reps: ["8", "7", "6", "6"])]      // before: fell short
        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .addReps)
    }

    func testTwoSessionsAtTheTopOfTheRangeEarnMoreLoad() {
        store.sessions = [benchSession(daysAgo: 2, reps: ["8", "8", "8", "8"]),
                          benchSession(daysAgo: 5, reps: ["8", "8", "8", "8"])]
        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .addLoad)
        XCTAssertEqual(store.suggested(planId: "p1", exercise: "Barbell bench press"), 82.5)
    }

    func testASingleSessionAtTheTopGetsTheBenefitOfTheDoubt() {
        store.sessions = [benchSession(daysAgo: 2, reps: ["8", "8", "8", "8"])]
        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .addLoad)
    }

    func testOneHardRideDoesNotBlockProgression() {
        // A single HR session gives an ACWR far above 1.3; with so little load
        // history that ratio means nothing and must not hold the user back.
        var ride = WorkoutSession(date: day(1), planId: "cardio-c-bike", planName: "Cycling", planColor: "7fc950")
        ride.sport = "cycling"; ride.durationSec = 5_400; ride.avgHR = 150
        store.sessions = [ride, benchSession(daysAgo: 2, reps: ["8", "8", "8", "8"])]

        XCTAssertFalse(store.loadDataStatus().reliable)
        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .addLoad)
    }

    func testAnOldLowHRVReadingDoesNotForceADeload() {
        // Baseline of normal nights three weeks ago, then one bad night, then nothing:
        // that last reading is not "today" and must not drive a deload now.
        store.daily = (0..<10).map { DailyEntry(date: day(40 - $0), hrvSleep: 60 + Double($0 % 3)) }
            + [DailyEntry(date: day(21), hrvSleep: 12)]
        store.sessions = [benchSession(daysAgo: 2, reps: ["8", "8", "8", "8"])]

        XCTAssertNil(store.readiness().score)
        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .addLoad)
    }

    func testDaytimeHRVDoesNotDriveReadinessOrDeload() {
        // The same numbers as a fresh bad night, but measured during the day: only
        // HRV taken asleep is scored.
        store.daily = (0..<10).map { DailyEntry(date: day(12 - $0), hrvSDNN: 60 + Double($0 % 3)) }
            + [DailyEntry(date: day(0), hrvSDNN: 12)]
        store.sessions = [benchSession(daysAgo: 2, reps: ["8", "8", "8", "8"])]

        XCTAssertFalse(store.readiness().usedSignals.contains("hrv"))
        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .addLoad)
    }

    func testAFreshLowHRVReadingStillDeloads() {
        store.daily = (0..<10).map { DailyEntry(date: day(12 - $0), hrvSleep: 60 + Double($0 % 3)) }
            + [DailyEntry(date: day(0), hrvSleep: 12)]
        store.sessions = [benchSession(daysAgo: 2, reps: ["8", "8", "8", "8"])]

        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .deload)
    }

    // MARK: Schedule

    func testScheduleThatOnlyPointsAtADeletedPlanFallsBackToRotation() {
        store.plans.append(WorkoutPlan(id: "gone", name: "Gone", sub: "", color: "ffe000", exercises: []))
        store.prefs.schedule = ["gone", "", "", "", "", "", ""]
        XCTAssertNotNil(store.nextUp())

        store.deletePlan("gone")

        XCTAssertFalse(store.prefs.weekSchedule.contains("gone"), "the deleted plan leaves the schedule")
        XCTAssertNotNil(store.nextUp(), "with plans available there is always a next workout")
    }

    // MARK: Body fat

    func testNavyBodyFatOutsideAPlausibleRangeIsNotReported() {
        store.prefs.height = 1.80
        XCTAssertNotNil(store.bfNavy(waist: 85, neck: 38))
        XCTAssertNil(store.bfNavy(waist: 38.5, neck: 38), "a waist barely above the neck gives a negative %")
    }

    // MARK: Week boundaries

    func testWeekStartsOnMondayAtMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 18))!

        let thisWeek = weekStart(now: wednesday, calendar: calendar)
        let lastWeek = weekStart(offset: 1, now: wednesday, calendar: calendar)

        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: thisWeek),
                       DateComponents(year: 2026, month: 10, day: 12, hour: 0))
        XCTAssertEqual(calendar.dateComponents([.month, .day], from: lastWeek), DateComponents(month: 10, day: 5))
    }

    func testWeekStartOnASundayIsThePreviousMonday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 9))!
        XCTAssertEqual(calendar.dateComponents([.month, .day], from: weekStart(now: sunday, calendar: calendar)),
                       DateComponents(month: 10, day: 12))
    }

    func testWeeklyChartBucketsStartOnMondayWhateverTheDeviceSays() {
        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.firstWeekday = 1
        let sunday = sundayFirst.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 9))!

        let bucket = Store.ChartGranularity.week.bucket(of: sunday, calendar: sundayFirst)

        XCTAssertEqual(sundayFirst.dateComponents([.month, .day], from: bucket), DateComponents(month: 10, day: 12))
    }

    // MARK: Goal and plates

    func testTheGoalDecidesWhetherTheRateLosesOrGains() {
        store.prefs.goalMode = "cut"
        store.prefs.weeklyRate = 0.5
        XCTAssertEqual(store.targetRate(), -0.5)
        XCTAssertLessThan(store.energyTargets().target, store.energyTargets().tdee)

        store.prefs.goalMode = "bulk"
        store.prefs.weeklyRate = -0.3
        XCTAssertEqual(store.targetRate(), 0.3)

        store.prefs.goalMode = "maintain"
        XCTAssertEqual(store.targetRate(), 0)
    }

    func testATinyPlateCannotStallThePlateCalculator() {
        store.prefs.plates = [0.0000001, 20]
        XCTAssertEqual(store.prefs.plateSet, [20])
        XCTAssertEqual(store.plateBreakdown(target: 60)?.plates, [20])
    }

    // MARK: Health values that change

    func testAValueRemovedFromHealthIsClearedAfterAFullReadButATypedOneStays() {
        store.applyHealthSamples([HealthDaySample(date: day(1), values: [.steps: 9_000, .restHR: 55, .vo2max: 45])])
        store.saveCheckIn(weight: nil, sleep: nil, restHR: 58, date: day(2))

        store.applyHealthSamples([], clearing: (days: [day(1), day(2)], categories: ["steps", "restHR"]))

        XCTAssertNil(store.dailyEntry(day(1))?.steps)
        XCTAssertNil(store.dailyEntry(day(1))?.restHR)
        XCTAssertEqual(store.dailyEntry(day(1))?.vo2max, 45, "a category that was not read stays")
        XCTAssertEqual(store.dailyEntry(day(2))?.restHR, 58, "typed by the user")
    }

    // MARK: Heart rate, VO2max

    func testTrimpDoesNotTreatALowSessionPeakAsTheMaxHR() {
        store.prefs.restingHR = 60
        store.prefs.maxHR = 190
        var lift = benchSession(daysAgo: 0, reps: ["8"])
        lift.durationSec = 3_600; lift.avgHR = 110
        var withPeak = lift
        withPeak.maxHRSes = 125

        XCTAssertEqual(store.trimp(withPeak)!, store.trimp(lift)!, accuracy: 0.001,
                       "a 125 bpm peak must not make 110 bpm look like 77 % of the reserve")
    }

    func testVO2EstimateScalesOnlyTheReserveAboveRest() {
        store.prefs.restingHR = 60
        store.prefs.maxHR = 190
        var run = WorkoutSession(date: day(1), planId: "cardio-run", planName: "Run", planColor: "ffe000",
                                 exercises: [], sport: "running")
        run.durationSec = 1_800; run.distanceKm = 6; run.avgHR = 164   // 200 m/min at 80 % of HR reserve
        store.sessions = [run]

        let est = store.vo2maxEstimate()
        // ACSM: 0.2 × 200 + 3.5 = 43.5; VO2max = 3.5 + 40 / 0.8 = 53.5
        XCTAssertEqual(est?.value ?? 0, 53.5, accuracy: 0.05)
        XCTAssertEqual(est?.estimated, true)
    }

    // MARK: Sleep score

    func testAGoodNightScoresFullMarks() {
        let score = Store.sleepScore(hours: 8, inBedHours: 8.5, deepMin: 90, remMin: 110, coreMin: 280, midpointSD: 20)
        XCTAssertEqual(score, 100)
    }

    func testHoursAloneStillGiveAScore() {
        XCTAssertEqual(Store.sleepScore(hours: 5.5), 50, "half-way between 4 h and 7 h")
        XCTAssertEqual(Store.sleepScore(hours: 8), 100)
        XCTAssertEqual(Store.sleepScore(hours: 12), 0)
    }

    func testShortDeepSleepAndIrregularHoursLowerTheScore() {
        let good = Store.sleepScore(hours: 8, inBedHours: 8.5, deepMin: 90, remMin: 110, coreMin: 280, midpointSD: 20)
        let poor = Store.sleepScore(hours: 8, inBedHours: 8.5, deepMin: 20, remMin: 110, coreMin: 350, midpointSD: 100)
        XCTAssertLessThan(poor, good - 15)
    }

    func testADeviceWithoutREMIsNotPenalised() {
        // The band's 15–16 Oct night: 9h35 asleep, deep 2h04, light 7h31, no REM.
        let band = Store.sleepScore(hours: 9.58, inBedHours: 10.7, deepMin: 124, remMin: 0, coreMin: 451)
        let noStages = Store.sleepScore(hours: 9.58, inBedHours: 10.7)
        XCTAssertGreaterThanOrEqual(band, noStages, "healthy deep sleep must not lower the score")
    }

    func testSleepRegularityNeedsFourNights() {
        store.daily = (1...3).map { DailyEntry(date: day($0), sleepStartMin: -60, sleepEndMin: 420) }
        XCTAssertNil(store.sleepRegularity(endingOn: day(1)))

        store.daily.append(DailyEntry(date: day(4), sleepStartMin: 0, sleepEndMin: 480))
        // Midpoints 180, 180, 180, 240 → SD 26 min
        XCTAssertEqual(store.sleepRegularity(endingOn: day(1)) ?? 0, 25.98, accuracy: 0.1)
    }

    // MARK: Readiness

    func testFastBreathingAtNightCapsReadinessAtEasy() {
        store.daily = (1...20).map { i in
            DailyEntry(date: day(i), sleep: 85, restHR: 52, hrvSleep: 60 + Double(i % 3), respRate: 14 + Double(i % 2) * 0.3)
        } + [DailyEntry(date: day(0), sleep: 90, restHR: 50, hrvSleep: 66, respRate: 18)]

        let r = store.readiness()

        XCTAssertEqual(r.warnings, [.respRate])
        XCTAssertEqual(r.advice, "easy")
        XCTAssertLessThan(r.score ?? 100, Store.readinessReadyFrom)
    }

    func testAGoodMorningIsReady() {
        store.daily = (1...20).map { i in
            DailyEntry(date: day(i), sleep: 80, restHR: 54 + i % 2, hrvSleep: 60 + Double(i % 3))
        } + [DailyEntry(date: day(0), sleep: 88, restHR: 52, hrvSleep: 68)]

        let r = store.readiness()

        XCTAssertEqual(r.advice, "ready")
        XCTAssertEqual(Set(r.usedSignals), ["hrv", "hr", "sleep"])
        XCTAssertTrue(r.warnings.isEmpty)
    }

    // MARK: Info points and charts

    func testEveryInfoPointHasItalianAndEnglishText() {
        for topic in InfoTopic.allCases {
            for lang in ["it", "en"] {
                XCTAssertNotEqual(L.t(topic.titleKey, lang: lang), topic.titleKey, "\(topic) title in \(lang)")
                XCTAssertNotEqual(L.t(topic.bodyKey, lang: lang), topic.bodyKey, "\(topic) body in \(lang)")
            }
        }
    }

    func testEveryScaleAscendsAndNamesItsBands() {
        // Personal scales need a baseline: give every nightly value 20 nights.
        store.daily = (1...20).map { i in
            DailyEntry(date: day(i), hrvSleep: 60 + Double(i % 4), sleepHR: 52 + i % 3,
                       respRate: 14 + Double(i % 3) * 0.2, wristTemp: 34.5 + Double(i % 3) * 0.1, walkingHR: 95 + i % 4)
        }
        for sex in ["m", "f"] {
            store.prefs.sex = sex
            for topic in InfoTopic.allCases {
                guard let scale = store.infoScale(topic) else { continue }
                var lower = scale.from
                for (i, band) in scale.bands.enumerated() {
                    XCTAssertGreaterThan(band.upTo, lower, "\(topic) band \(i) does not ascend")
                    lower = band.upTo
                    XCTAssertNotEqual(L.t("band." + band.key), "band." + band.key, "\(topic): band.\(band.key) missing")
                }
            }
        }
    }

    func testChartSeriesHaveOneDatedPointPerDayAcrossYears() {
        // Two sessions on one day, and the same day-of-month a year apart: the old
        // "MM-dd" labels merged the years and duplicated the day.
        let thisYear = benchSession(daysAgo: 10, reps: ["8"], weight: "80")
        let sameDay = benchSession(daysAgo: 10, reps: ["8"], weight: "90")
        let lastYear = benchSession(daysAgo: 375, reps: ["8"], weight: "70")
        store.sessions = [thisYear, sameDay, lastYear]

        let history = store.exerciseHistory("Barbell bench press")

        XCTAssertEqual(history.count, 2)
        XCTAssertLessThan(history[0].day, history[1].day)
        XCTAssertEqual(history[1].maxW, 90, "the heavier set of the day wins")
        XCTAssertEqual(history[1].vol, 80 * 8 + 90 * 8, "both sessions' volume add up")
    }

    // MARK: Training and sleep algorithms

    private func ride(daysAgo: Int, hr: Int = 140) -> WorkoutSession {
        var r = WorkoutSession(date: day(daysAgo), planId: "cardio-bike", planName: "Bike", planColor: "7fc950",
                               exercises: [], sport: "cycling")
        r.durationSec = 3_600; r.avgHR = hr
        return r
    }

    func testSteadyTrainingSettlesFitnessAndFatigueOnTheSameLoad() {
        store.prefs.restingHR = 60; store.prefs.maxHR = 190
        store.sessions = (0..<200).map { ride(daysAgo: $0) }
        let load = store.trimp(store.sessions[0])!

        let today = store.formSeries(days: 5).last!

        XCTAssertEqual(today.fitness, load, accuracy: load * 0.05)
        XCTAssertEqual(today.fatigue, load, accuracy: load * 0.01)
        XCTAssertEqual(today.form, 0, accuracy: load * 0.05, "steady training is neither fresh nor overloaded")
    }

    func testRestDaysMakeYouFresh() {
        store.prefs.restingHR = 60; store.prefs.maxHR = 190
        store.sessions = (10..<200).map { ride(daysAgo: $0) }
        XCTAssertGreaterThan(store.formSeries(days: 1).last!.form, 10)
    }

    func testRecoveryIsLongerAfterAHarderSession() {
        store.prefs.restingHR = 60; store.prefs.maxHR = 190
        store.sessions = [ride(daysAgo: 0, hr: 120)]
        let easy = store.recoveryEstimate()!.hours
        store.sessions = [ride(daysAgo: 0, hr: 175)]
        let hard = store.recoveryEstimate()!.hours
        XCTAssertLessThan(easy, hard)
        XCTAssertTrue((8...72).contains(hard))
    }

    func testSleepDebtCountsShortNightsAndPaysBackLongOnes() {
        store.daily = (0..<14).map { DailyEntry(date: day($0), sleepHours: $0 < 7 ? 6 : 9) }
        // 7 nights 2 h short, 7 nights 1 h long → 7 h of debt.
        XCTAssertEqual(store.sleepDebt() ?? 0, 7, accuracy: 0.001)
        store.daily = (0..<5).map { DailyEntry(date: day($0), sleepHours: 5) }
        XCTAssertNil(store.sleepDebt(), "not enough nights")
    }

    func testSocialJetLagIsTheShiftOfTheWeekendNight() {
        store.daily = (0..<28).map { i in
            let ds = day(i)
            let weekday = Calendar.current.component(.weekday, from: isoFormatter.date(from: ds)!)
            let weekend = weekday == 1 || weekday == 7
            return DailyEntry(date: ds, sleepStartMin: weekend ? 60 : -60, sleepEndMin: weekend ? 600 : 420)
        }
        // Midpoints 180 on work days, 330 at weekends.
        XCTAssertEqual(store.socialJetLag() ?? 0, 150, accuracy: 0.001)
    }

    func testHRVStabilityIsZeroForAFlatWeekAndGrowsWithSwings() {
        store.daily = (0..<7).map { DailyEntry(date: day($0), hrvSleep: 60) }
        XCTAssertEqual(store.hrvStability() ?? -1, 0, accuracy: 0.0001)
        store.daily = (0..<7).map { DailyEntry(date: day($0), hrvSleep: $0 % 2 == 0 ? 40 : 90) }
        XCTAssertGreaterThan(store.hrvStability() ?? 0, 5)
    }

    func testFitnessAgeOfATypicalVO2IsAboutTheSameAge() {
        store.prefs.sex = "m"; store.prefs.birthDate = "1986-01-01"
        store.daily = [DailyEntry(date: day(1), vo2max: 39)]            // typical for the 40s row
        XCTAssertEqual(Double(store.fitnessAge() ?? 0), 45, accuracy: 1)
        store.daily = [DailyEntry(date: day(1), vo2max: 52)]
        XCTAssertLessThan(store.fitnessAge() ?? 99, 30)
    }

    func testRelativeStrengthUsesTheBestBarbellLift() {
        store.daily = [DailyEntry(date: day(1), weight: 80)]
        let bench = LoggedExercise(name: "Barbell bench press", sets: [SetEntry(reps: "5", weight: "100")], notes: "", target: "")
        let dumbbell = LoggedExercise(name: "Dumbbell bench press", sets: [SetEntry(reps: "5", weight: "60")], notes: "", target: "")
        store.sessions = [WorkoutSession(date: day(1), planId: "p1", planName: "Push", planColor: "ff5a52",
                                         exercises: [bench, dumbbell])]

        let lifts = store.relativeStrength()

        XCTAssertEqual(lifts.map(\.lift), [.bench])
        XCTAssertEqual(lifts[0].ratio, 100 * (1 + 5.0 / 30) / 80, accuracy: 0.001)
    }

    func testZoneWeeksReportTheEasyShare() {
        store.workoutIntensity = [
            WorkoutIntensity(date: day(1), end: Date(), sport: "running", zoneSeconds: [1_800, 1_800, 0, 600, 300], decoupling: 3)
        ]
        let week = store.intensityWeeks().last!
        XCTAssertEqual(week.easyShare, 3_600.0 / 4_500 * 100, accuracy: 0.001)
        XCTAssertEqual(store.lastDecoupling?.value, 3)
    }
}
