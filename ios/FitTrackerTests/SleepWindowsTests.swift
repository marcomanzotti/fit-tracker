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
}
