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
}
