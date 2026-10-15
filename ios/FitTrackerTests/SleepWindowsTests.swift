import XCTest
@testable import FitTracker

/// Time asleep when Apple Watch and the band record the same night.
final class SleepWindowsTests: XCTestCase {
    private let night = Date(timeIntervalSince1970: 1_700_000_000)

    private func at(_ hours: Double) -> Date {
        night.addingTimeInterval(hours * 3600)
    }

    private func totalHours(_ windows: [(start: Date, end: Date)]) -> Double {
        windows.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) / 3600 }
    }

    func testSameNightFromTwoSourcesCountsOnce() {
        let watch = [(start: at(0), end: at(4)), (start: at(4.5), end: at(8))]
        let band = [(start: at(0.25), end: at(7.75))]

        let merged = SleepWindows.merge(watch + band)

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(totalHours(merged), 8, accuracy: 0.001)
    }

    func testSeparateWindowsStaySeparate() {
        let merged = SleepWindows.merge([(start: at(5), end: at(6)), (start: at(0), end: at(2))])

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first?.start, at(0))
        XCTAssertEqual(totalHours(merged), 3, accuracy: 0.001)
    }

    func testTouchingWindowsJoinAndEmptyOnesAreDropped() {
        let merged = SleepWindows.merge([(start: at(0), end: at(1)), (start: at(1), end: at(2)), (start: at(3), end: at(3))])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(totalHours(merged), 2, accuracy: 0.001)
    }

    // MARK: Nights

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    /// 14 Oct 2026 at `hour` (Rome); hours past 24 run into the next day.
    private func oct14(_ hour: Double) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 14))!.addingTimeInterval(hour * 3600)
    }

    private func sample(_ from: Double, _ to: Double, _ stage: SleepSample.Stage, _ source: String) -> SleepSample {
        SleepSample(start: oct14(from), end: oct14(to), stage: stage, source: source)
    }

    func testANightAcrossMidnightBelongsToTheWakeDayWithItsStages() {
        let watch = [sample(23, 25, .core, "watch"), sample(25, 26.5, .deep, "watch"),
                     sample(26.5, 27, .awake, "watch"), sample(27, 29, .rem, "watch"), sample(29, 31, .core, "watch")]

        let nights = SleepWindows.nights(watch, cal: cal)

        XCTAssertEqual(nights.count, 1)
        let n = nights[0]
        XCTAssertEqual(n.day, "2026-10-15")
        XCTAssertEqual(n.asleepHours, 7.5, accuracy: 0.001)
        XCTAssertEqual(n.inBedHours, 8, accuracy: 0.001)
        XCTAssertEqual(n.deepMin, 90, accuracy: 0.001)
        XCTAssertEqual(n.remMin, 120, accuracy: 0.001)
        XCTAssertEqual(n.awakeMin, 30, accuracy: 0.001)
    }

    func testOneSourceIsKeptInsteadOfTheUnionOfBoth() {
        let watch = [sample(23, 27, .asleep, "watch"), sample(27, 27.5, .awake, "watch"), sample(27.5, 31, .asleep, "watch")]
        let band = [sample(23.25, 27.25, .asleep, "band"), sample(28, 31, .asleep, "band")]

        let nights = SleepWindows.nights(watch + band, cal: cal)

        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].asleepHours, 7.5, accuracy: 0.001, "the watch's 7.5 h, not the 8 h union")
    }

    func testANapDoesNotReplaceTheNight() {
        let night = [sample(23, 31, .asleep, "watch")]
        let nap = [sample(38, 38.5, .asleep, "watch")]   // 14:00 the next day

        let nights = SleepWindows.nights(night + nap, cal: cal)

        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].asleepHours, 8, accuracy: 0.001)
    }

    func testAReadingAtElevenPMCountsForTheNightThatEndsNextMorning() {
        // The v11 bug: an evening heart-rate sample was filed under the evening's
        // own day, splitting one night's average across two days.
        let nights = SleepWindows.nights([sample(22.5, 30.5, .asleep, "band")], cal: cal)

        let n = SleepWindows.night(at: oct14(23), in: nights)

        XCTAssertEqual(n?.day, "2026-10-15")
        XCTAssertEqual(n?.isAsleep(at: oct14(23)), true)
        XCTAssertNil(SleepWindows.night(at: oct14(20), in: nights))
    }
}
