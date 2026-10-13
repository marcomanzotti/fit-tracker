import XCTest
@testable import FitTracker

/// A workout in progress must survive the app being suspended, killed or simply
/// left alone, and the clocks must follow real time rather than timer ticks.
final class WorkoutDraftTests: XCTestCase {
    private var now = Date(timeIntervalSince1970: 1_780_000_000)
    private var clock: () -> Date { { self.now } }

    private let plan = WorkoutPlan(id: "p1", name: "Push", sub: "Chest", color: "ff5a52", exercises: [
        PlanExercise(name: "Bench", sets: 2, reps: "8"),
        PlanExercise(name: "Fly", sets: 1, reps: "12")
    ])
    private let run = CardioType(id: "c-run", name: "Running", sport: "running", color: "ff5a52")

    private func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }

    private func startedWorkout() -> ActiveWorkout {
        let workout = ActiveWorkout(clock: clock)
        workout.start(plan: plan)
        workout.log[0].sets[0].reps = "8"
        workout.log[0].sets[0].weight = "100"
        return workout
    }

    // MARK: Draft round trip

    func testDraftBringsBackEverythingTyped() throws {
        let workout = startedWorkout()
        workout.avgHR = "132"
        workout.durationSec = 3_000
        workout.caloriesManual = "410"

        let restored = ActiveWorkout(clock: clock)
        restored.restore(try XCTUnwrap(workout.draft))

        XCTAssertEqual(restored.plan, plan)
        XCTAssertEqual(restored.log, workout.log)
        XCTAssertEqual(restored.startDate, workout.startDate)
        XCTAssertEqual(restored.avgHR, "132")
        XCTAssertEqual(restored.durationSec, 3_000)
        XCTAssertEqual(restored.caloriesManual, "410")
        XCTAssertEqual(restored.restored, .resumed)
    }

    func testDraftFileRoundTripsAndAnEmptyDraftRemovesIt() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("draft-\(UUID().uuidString)").appendingPathComponent("active.json")
        let drafts = WorkoutDraftStore(url: url)
        XCTAssertNil(try drafts.load())

        let saved = WorkoutDraft(savedAt: now, strength: startedWorkout().draft, cardio: nil, rest: nil)
        try drafts.save(saved)
        XCTAssertEqual(try drafts.load(), saved)

        try drafts.save(WorkoutDraft(savedAt: now, strength: nil, cardio: nil, rest: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testARunningWorkoutComesBackAfterTheAppIsRelaunched() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("keeper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let drafts = WorkoutDraftStore(url: dir.appendingPathComponent("active-workout.json"))
        let store = Store(directory: dir)
        func keeper(for workout: ActiveWorkout) -> SessionKeeper {
            SessionKeeper(store: store, workout: workout,
                          cardio: ActiveCardio(clock: clock, tracksLocation: false),
                          timer: RestTimer(), toast: ToastCenter(), drafts: drafts)
        }

        let running = startedWorkout()
        running.avgHR = "140"
        keeper(for: running).saveNow()

        let relaunched = ActiveWorkout(clock: clock)        // a fresh process: nothing in memory
        let secondKeeper = keeper(for: relaunched)
        XCTAssertEqual(relaunched.plan, plan)
        XCTAssertEqual(relaunched.log, running.log)
        XCTAssertEqual(relaunched.avgHR, "140")

        relaunched.end()
        secondKeeper.saveNow()
        XCTAssertNil(try drafts.load(), "a finished workout must not come back at the next launch")
    }

    func testDraftUntouchedForHoursIsFlaggedStale() throws {
        let workout = startedWorkout()
        let draft = try XCTUnwrap(workout.draft)
        advance(ActiveWorkout.staleAfterSec + 60)

        let restored = ActiveWorkout(clock: clock)
        restored.restore(draft)

        XCTAssertEqual(restored.restored, .stale)
    }

    // MARK: Finishing

    func testFinishedSessionKeepsOnlyFilledSetsAndTheStartDay() throws {
        let workout = startedWorkout()
        advance(50 * 60)
        workout.log[0].sets[1].reps = "6"

        let session = try XCTUnwrap(workout.finishedSession())

        XCTAssertEqual(session.exercises.map(\.name), ["Bench"])
        XCTAssertEqual(session.exercises[0].sets.count, 2)
        XCTAssertEqual(session.date, isoFormatter.string(from: try XCTUnwrap(workout.startDate)))
        XCTAssertEqual(session.planName, "Push")
        XCTAssertEqual(session.durationSec, 50 * 60)
    }

    func testNothingLoggedMeansNoSession() {
        let workout = ActiveWorkout(clock: clock)
        workout.start(plan: plan)
        XCTAssertNil(workout.finishedSession())
    }

    func testForgottenWorkoutRecordsTimeUpToTheLastEditNotUntilNow() throws {
        let workout = startedWorkout()
        advance(40 * 60)
        workout.log[0].sets[1].reps = "7"          // last thing the user did
        advance(14 * 3600)                         // …then the phone sat in a bag overnight

        let session = try XCTUnwrap(workout.finishedSession())

        XCTAssertEqual(session.durationSec, 40 * 60)
    }

    func testTypedDurationAlwaysWins() throws {
        let workout = startedWorkout()
        workout.durationSec = 1_234
        advance(3_600)
        XCTAssertEqual(try XCTUnwrap(workout.finishedSession()).durationSec, 1_234)
    }

    // MARK: Watch

    func testAbsorbedWatchResultGivesTheSessionItsIdSoASecondDeliveryDedupes() throws {
        let workout = startedWorkout()
        let id = UUID().uuidString
        let result = WatchResult(id: id, date: "2026-10-13", kind: WatchKind.strength.rawValue,
                                 activityId: "p1", name: "Push", color: "ff5a52", sport: nil,
                                 durationSec: 2_700, avgHR: 128, maxHR: 160, activeKcal: 350,
                                 distanceKm: nil,
                                 exercises: [WatchResultExercise(name: "Fly", reps: ["12"], weight: ["14"])])

        workout.absorb(result: result)
        let session = try XCTUnwrap(workout.finishedSession())

        XCTAssertEqual(session.id.uuidString, id)
        XCTAssertEqual(session.durationSec, 2_700)
        XCTAssertEqual(session.avgHR, 128)
        XCTAssertEqual(session.caloriesManual, 350)
        XCTAssertEqual(session.exercises.map(\.name), ["Bench", "Fly"], "wrist sets fill the empty ones")
        XCTAssertEqual(workout.log[0].sets[0].weight, "100", "typed values are never overwritten")
    }

    func testWatchDataForAnotherActivityIsIgnored() {
        let workout = startedWorkout()
        let other = WatchResult(id: UUID().uuidString, date: "2026-10-13", kind: WatchKind.strength.rawValue,
                                activityId: "p2", name: "Pull", color: "4fb8c4", sport: nil,
                                durationSec: 100, avgHR: 99, maxHR: nil, activeKcal: nil,
                                distanceKm: nil, exercises: nil)
        workout.absorb(result: other)
        XCTAssertEqual(workout.avgHR, "")
        XCTAssertNil(workout.durationSec)
    }

    // MARK: Cardio clock

    func testCardioClockFollowsRealTimeAndSkipsPauses() {
        let cardio = ActiveCardio(clock: clock, tracksLocation: false)
        cardio.start(run)
        advance(600)
        XCTAssertEqual(cardio.elapsedSec(), 600)

        cardio.togglePause()
        advance(300)                               // paused: not counted
        XCTAssertEqual(cardio.elapsedSec(), 600)

        cardio.togglePause()
        advance(120)
        XCTAssertEqual(cardio.elapsedSec(), 720)
    }

    func testCardioRestoredAfterAShortGapKeepsCounting() throws {
        let cardio = ActiveCardio(clock: clock, tracksLocation: false)
        cardio.start(run)
        advance(600)
        let draft = try XCTUnwrap(cardio.draft)
        let savedAt = now
        advance(120)                               // app was gone for two minutes

        let restored = ActiveCardio(clock: clock, tracksLocation: false)
        restored.restore(draft, savedAt: savedAt)

        XCTAssertFalse(restored.paused)
        XCTAssertEqual(restored.elapsedSec(), 720)
    }

    func testCardioRestoredAfterALongGapComesBackPausedAtTheLastSave() throws {
        let cardio = ActiveCardio(clock: clock, tracksLocation: false)
        cardio.start(run)
        advance(600)
        let draft = try XCTUnwrap(cardio.draft)
        let savedAt = now
        advance(ActiveCardio.resumeGapSec + 3_600)

        let restored = ActiveCardio(clock: clock, tracksLocation: false)
        restored.restore(draft, savedAt: savedAt)

        XCTAssertTrue(restored.paused)
        XCTAssertEqual(restored.elapsedSec(), 600, "time the app was gone is not invented")
    }

    func testCardioSessionCarriesTimeAndWatchNumbers() throws {
        let cardio = ActiveCardio(clock: clock, tracksLocation: false)
        cardio.start(run)
        advance(1_800)
        let id = UUID().uuidString
        cardio.absorb(result: WatchResult(id: id, date: "2026-10-13", kind: WatchKind.cardio.rawValue,
                                          activityId: "cardio-c-run", name: "Running", color: "ff5a52",
                                          sport: "running", durationSec: 1_790, avgHR: 151, maxHR: 172,
                                          activeKcal: 402, distanceKm: 5.2, exercises: nil))

        let session = try XCTUnwrap(cardio.finishedSession())

        XCTAssertEqual(session.id.uuidString, id)
        XCTAssertEqual(session.sport, "running")
        XCTAssertEqual(session.durationSec, 1_790)
        XCTAssertEqual(session.avgHR, 151)
        XCTAssertEqual(session.distanceKm, 5.2)
        XCTAssertEqual(session.caloriesManual, 402)
    }

    // MARK: Rest timer

    func testRestCountdownComesFromTheClockNotFromTicks() {
        let timer = RestTimer()
        timer.start(90, now: now)
        XCTAssertEqual(timer.remaining, 90)

        advance(60)                                // a minute in the background, no ticks delivered
        timer.refresh(now: now)
        XCTAssertEqual(timer.remaining, 30)
        XCTAssertTrue(timer.running)

        advance(45)
        timer.refresh(now: now)
        XCTAssertEqual(timer.remaining, 0)
        XCTAssertTrue(timer.done)
        XCTAssertFalse(timer.running)
    }

    func testARestThatAlreadyEndedIsNotResumed() {
        let timer = RestTimer()
        timer.resume(endsAt: now.addingTimeInterval(-5), total: 90, now: now)
        XCTAssertFalse(timer.active)
    }
}

/// The end-of-workout recap compares the session with the history before it.
final class WorkoutSummaryTests: XCTestCase {
    private func session(_ sets: [(String, String)], exercise: String = "Bench") -> WorkoutSession {
        WorkoutSession(date: "2026-10-13", planId: "p1", planName: "Push", planColor: "ff5a52",
                       exercises: [LoggedExercise(name: exercise,
                                                  sets: sets.map { SetEntry(reps: $0.0, weight: $0.1) },
                                                  notes: "", target: "")])
    }

    func testVolumeIsComparedWithThePreviousSessionOfThePlan() {
        let summary = WorkoutSummary.make(session: session([("8", "100"), ("8", "100")]),
                                          previous: session([("8", "100"), ("7", "100")]),
                                          recordBefore: { _ in 100 }, kcal: 300, trimp: nil)
        XCTAssertEqual(summary.sets, 2)
        XCTAssertEqual(summary.volume, 1_600)
        XCTAssertEqual(summary.volumeChange ?? 0, 100.0 / 1_500, accuracy: 0.0001)
        XCTAssertTrue(summary.records.isEmpty, "matching the record is not beating it")
    }

    func testAHeavierTopSetIsARecordButAFirstEverLogIsNot() {
        let beaten = WorkoutSummary.make(session: session([("5", "105")]), previous: nil,
                                         recordBefore: { _ in 100 }, kcal: 0, trimp: nil)
        XCTAssertEqual(beaten.records, [WorkoutSummary.Record(name: "Bench", weight: 105, previous: 100)])
        XCTAssertNil(beaten.volumeChange, "nothing to compare with the first time")

        let first = WorkoutSummary.make(session: session([("5", "105")]), previous: nil,
                                        recordBefore: { _ in 0 }, kcal: 0, trimp: nil)
        XCTAssertTrue(first.records.isEmpty)
    }
}
