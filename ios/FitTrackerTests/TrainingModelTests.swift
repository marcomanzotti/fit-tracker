import SwiftUI
import XCTest
@testable import FitTracker

/// Load, heart-rate and body-composition models: resting HR of the day, TRIMP over
/// samples, the single form-based load model, learned max HR, one scale per metric.
final class TrainingModelTests: XCTestCase {
    private var dir: URL!
    private var store: Store!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fittracker-training-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = Store(directory: dir)
        store.prefs.restingHR = 60; store.prefs.maxHR = 190
    }

    override func tearDownWithError() throws {
        store = nil
        try FileManager.default.removeItem(at: dir)
    }

    private func day(_ days: Int) -> String {
        isoFormatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!)
    }

    private func ride(daysAgo: Int, hr: Int = 140, minutes: Int = 60) -> WorkoutSession {
        var r = WorkoutSession(date: day(daysAgo), planId: "cardio-bike", planName: "Bike", planColor: "7fc950",
                               exercises: [], sport: "cycling")
        r.durationSec = minutes * 60; r.avgHR = hr
        return r
    }

    private func bench(daysAgo: Int) -> WorkoutSession {
        let sets = ["8", "8", "8", "8"].map { SetEntry(reps: $0, weight: "80") }
        return WorkoutSession(date: day(daysAgo), planId: "p1", planName: "Push", planColor: "ff5a52",
                              exercises: [LoggedExercise(name: "Barbell bench press", sets: sets, notes: "", target: "4×6-8")])
    }

    // MARK: Resting heart rate of the day

    func testTRIMPUsesTheRestingHeartRateOfTheWeekBeforeTheSession() {
        let session = ride(daysAgo: 3)
        store.sessions = [session]
        let withProfile = store.trimp(session)!

        store.daily = (4...10).map { DailyEntry(date: day($0), restHR: 48) }
        let withHealth = store.trimp(session)!
        XCTAssertGreaterThan(withHealth, withProfile, "a lower resting HR means a bigger reserve used")

        store.daily += [DailyEntry(date: day(1), restHR: 75)]      // an illness after the session
        XCTAssertEqual(store.trimp(session)!, withHealth, accuracy: 0.0001, "history does not move")
    }

    func testTRIMPFallsBackToTheProfileWithoutEnoughReadings() {
        let session = ride(daysAgo: 3)
        store.sessions = [session]
        let withProfile = store.trimp(session)!
        store.daily = [DailyEntry(date: day(5), restHR: 40)]
        XCTAssertEqual(store.trimp(session)!, withProfile, accuracy: 0.0001)
    }

    // MARK: TRIMP over heart-rate samples

    func testIntervalsWeighMoreThanTheSameAverageHeartRate() {
        var steady = ride(daysAgo: 1, hr: 140)
        var intervals = steady
        steady.hrHistogram = [140: 3_600]
        intervals.hrHistogram = [100: 1_800, 180: 1_800]
        let flat = store.trimp(steady)!, hard = store.trimp(intervals)!
        XCTAssertGreaterThan(hard, flat * 1.1)
    }

    func testSamplesCoveringTooLittleOfTheWorkoutFallBackToTheAverage() {
        var s = ride(daysAgo: 1, hr: 140)
        let plain = store.trimp(s)!
        s.hrHistogram = [170: 300]                 // 5 min of a 60 min workout
        XCTAssertEqual(store.trimp(s)!, plain, accuracy: 0.0001)
    }

    // MARK: Max heart rate

    func testMaxHeartRateIsSuggestedFromTheSecondHighestPeak() {
        store.prefs.maxHR = nil                                   // Tanaka 187 at 30
        store.prefs.birthDate = isoFormatter.string(from: Calendar.current.date(byAdding: .year, value: -30, to: Date())!)
        var a = ride(daysAgo: 10); a.maxHRSes = 201
        var b = ride(daysAgo: 20); b.maxHRSes = 196
        var c = ride(daysAgo: 30); c.maxHRSes = 150
        store.sessions = [a, b, c]
        XCTAssertEqual(store.suggestedMaxHR, 196)

        store.sessions = [a, c]
        XCTAssertNil(store.suggestedMaxHR, "one outlier is not enough")
    }

    func testZonesAndTRIMPShareTheSameMaxHeartRate() {
        var s = ride(daysAgo: 1, hr: 150); s.maxHRSes = 200
        let noPeak = ride(daysAgo: 1, hr: 150)
        XCTAssertEqual(store.trimp(s)!, store.trimp(noPeak)!, accuracy: 0.0001)
    }

    // MARK: One load model

    func testFormIsAShareOfFitness() {
        store.sessions = (0..<200).map { ride(daysAgo: $0) }
        XCTAssertEqual(store.formPercent() ?? 99, 0, accuracy: 3)

        store.sessions = (10..<200).map { ride(daysAgo: $0) }
        XCTAssertGreaterThan(store.formPercent() ?? 0, 10)
    }

    func testAHeavyBlockAfterEasyWeeksIsOverreachingAndHoldsProgression() {
        store.sessions = (10..<60).map { ride(daysAgo: $0, hr: 125, minutes: 45) }
            + (0..<5).map { ride(daysAgo: $0, hr: 175, minutes: 90) } + [bench(daysAgo: 2)]

        XCTAssertLessThan(store.formPercent() ?? 0, -30)
        XCTAssertEqual(store.progression(planId: "p1", exercise: "Barbell bench press"), .hold)
    }

    func testLoadRatioIsFatigueOverFitness() {
        store.sessions = (0..<200).map { ride(daysAgo: $0) }
        XCTAssertEqual(store.acwr().ratio ?? 0, 1, accuracy: 0.05)
        XCTAssertEqual(store.acwr().zone, "ok")
    }

    // MARK: Muscles

    func testSecondaryMusclesCountHalfASet() {
        store.sessions = [bench(daysAgo: 0)]                      // 4 sets
        let volume = Dictionary(uniqueKeysWithValues: store.weeklyMuscleVolume().map { ($0.group, $0.sets) })
        XCTAssertEqual(volume[.chest], 4)
        XCTAssertEqual(volume[.arms], 2)
        XCTAssertEqual(volume[.shoulders], 2)
    }

    // MARK: Sleep need

    func testSleepDebtFollowsThePersonalNeed() {
        store.daily = (0..<14).map { DailyEntry(date: day($0), sleepHours: 7.5) }
        store.prefs.sleepNeed = 8
        XCTAssertEqual(store.sleepDebt() ?? 0, 7, accuracy: 0.001)
        store.prefs.sleepNeed = 7
        XCTAssertEqual(store.sleepDebt() ?? 1, 0, accuracy: 0.001)
    }

    // MARK: Aerobic decoupling

    func testDecouplingSkipsTheWarmUpAndWorksOnPower() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        func at(_ min: Double) -> Date { start.addingTimeInterval(min * 60) }
        // 60 minutes. The first 10 are a warm-up at 120 bpm and 100 W (left out). From
        // minute 10 to 35 it is 150 bpm and from 35 to 60 it is 155 bpm, at 200 W.
        let hr = (0..<60).map { m in (at(Double(m)), m < 10 ? 120.0 : (m < 35 ? 150 : 155)) }
        let power = (0..<60).map { m in (at(Double(m)), m < 10 ? 100.0 : 200) }

        let d = aerobicDecoupling(heartRate: hr, work: power, kind: .power, start: start, end: at(60))

        // Halves of minute 10…60 split at 35: 150 bpm against 155 bpm at equal power.
        XCTAssertEqual(d ?? -99, (1 - (200 / 155.0) / (200 / 150.0)) * 100, accuracy: 0.05)
    }

    func testDecouplingOnDistanceUsesTheMetresOfEachHalf() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        func at(_ min: Double) -> Date { start.addingTimeInterval(min * 60) }
        let hr = (0..<40).map { (at(Double($0)), 150.0) }
        let metres = (0..<40).map { (at(Double($0)), $0 < 25 ? 200.0 : 180.0) }   // slows down late

        let d = aerobicDecoupling(heartRate: hr, work: metres, kind: .distance, start: start, end: at(40))

        XCTAssertGreaterThan(d ?? 0, 0)
    }

    // MARK: Categories

    func testBodyFatCardAndInfoSheetUseTheSameBand() {
        let band = store.scaleBand(.bodyfat, 27)
        let scale = store.infoScale(.bodyfat)!
        XCTAssertEqual(band?.key, "band." + scale.bands[scale.bandIndex(of: 27)].key)
    }

    func testFFMITrendOnlyPlotsDaysWithAMeasurementInterpolated() {
        store.prefs.height = 1.80
        var first = BodyEntry(date: day(10)); first.bfManual = 20
        var second = BodyEntry(date: day(0)); second.bfManual = 10
        store.body = [first, second]

        XCTAssertNil(store.ffmiTrend(on: day(20), weight: 80), "before any measurement")
        XCTAssertEqual(store.ffmiTrend(on: day(10), weight: 80) ?? 0, 80 * 0.8 / 3.24, accuracy: 0.1)
        XCTAssertEqual(store.ffmiTrend(on: day(5), weight: 80) ?? 0, 80 * 0.85 / 3.24, accuracy: 0.1)
    }
}
