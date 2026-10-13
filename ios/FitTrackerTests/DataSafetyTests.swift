import XCTest
@testable import FitTracker

/// The store must never lose or overwrite the user's history: not on an
/// unreadable file, not on an unrelated delete, not on a non-finite number.
final class DataSafetyTests: XCTestCase {
    private var dir: URL!
    private var dataFile: URL { dir.appendingPathComponent("fittracker.json") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fittracker-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: dir)
    }

    private func strengthSession(_ exercise: String, date: String = "2026-10-01") -> WorkoutSession {
        let sets = [SetEntry(reps: "8", weight: "100")]
        return WorkoutSession(date: date, planId: "p1", planName: "Push", planColor: "ff5a52",
                              exercises: [LoggedExercise(name: exercise, sets: sets, notes: "", target: "1×8")])
    }

    private func document(sessions: [WorkoutSession]) throws -> Data {
        try JSONEncoder().encode(AppData(sessions: sessions))
    }

    // MARK: Number parsing

    func testParsingTreatsNonFiniteInputAsZero() {
        XCTAssertEqual(pf("87,5"), 87.5)
        XCTAssertEqual(pf("inf"), 0)
        XCTAssertEqual(pf("-infinity"), 0)
        XCTAssertEqual(pf("nan"), 0)
        XCTAssertEqual(pf("1e400"), 0)
        XCTAssertEqual(pf("1e30"), 0, "a finite but absurd value would trap in Int(...)")
    }

    func testFormattingNeverTrapsOnHugeOrNonFiniteValues() {
        XCTAssertEqual(trimNum(12), "12")
        XCTAssertEqual(trimNum(12.5), "12.5")
        XCTAssertEqual(trimNum(.infinity), "—")
        XCTAssertEqual(trimNum(.nan), "—")
        XCTAssertEqual(trimNum(1e30), "1e+30")
    }

    // MARK: Persistence

    func testSavedDataIsReadBackByANewStore() throws {
        let first = Store(directory: dir)
        first.sessions.append(strengthSession("Bench"))
        first.flushNow()

        let second = Store(directory: dir)
        XCTAssertEqual(second.sessions.map(\.planName), ["Push"])
        XCTAssertNil(second.storageProblem)
    }

    func testUnreadableFileIsSetAsideAndSurvivesLaterSaves() throws {
        let garbage = Data("{ \"sessions\": \"this is not the schema\"".utf8)
        try garbage.write(to: dataFile)

        let store = Store(directory: dir)
        XCTAssertEqual(store.storageProblem, .unreadable)
        store.sessions.append(strengthSession("Bench"))
        store.flushNow()

        let aside = try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath: dir.path)
            .first { $0.hasPrefix("fittracker.corrupt-") }, "the unreadable file is kept under a dated name")
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(aside)), garbage)
        XCTAssertEqual(Store(directory: dir).sessions.count, 1, "the app keeps working and saving")
    }

    func testUnreadableFileFallsBackToTheNewestReadableBackup() throws {
        try Data("not json".utf8).write(to: dataFile)
        try document(sessions: [strengthSession("Old")])
            .write(to: dir.appendingPathComponent("backup-2026-09-01.json"))
        try document(sessions: [strengthSession("Newer"), strengthSession("Newest")])
            .write(to: dir.appendingPathComponent("backup-2026-10-10.json"))

        let store = Store(directory: dir)

        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertEqual(store.storageProblem, .recovered(from: "backup-2026-10-10.json"))
    }

    func testDatedBackupHoldsTheStateFromBeforeTodaysFirstSave() throws {
        try document(sessions: [strengthSession("Yesterday")]).write(to: dataFile)

        let store = Store(directory: dir)
        store.sessions.append(strengthSession("Today"))
        store.flushNow()
        store.sessions.append(strengthSession("Later today"))
        store.flushNow()

        let backup = dir.appendingPathComponent("backup-\(today()).json")
        let restored = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: backup))
        XCTAssertEqual(restored.sessions.count, 1, "the backup is yesterday's state, not a copy of today's")
    }

    func testDocumentWithoutTheLaterOptionalFieldsStillDecodes() throws {
        let prefs = String(decoding: try JSONEncoder().encode(Prefs()), as: UTF8.self)
        let old = Data("{\"daily\":[],\"sessions\":[],\"body\":[],\"plans\":[],\"prefs\":\(prefs)}".utf8)
        try old.write(to: dataFile)

        let store = Store(directory: dir)

        XCTAssertNil(store.storageProblem)
        XCTAssertFalse(store.plans.isEmpty, "an empty plan list is seeded with the defaults")
    }

    func testImportKeepsACopyOfWhatItReplaces() throws {
        let store = Store(directory: dir)
        store.sessions.append(strengthSession("Mine"))
        let incoming = dir.appendingPathComponent("incoming.json")
        try document(sessions: []).write(to: incoming)

        XCTAssertEqual(store.importFile(incoming), .imported)

        XCTAssertTrue(store.sessions.isEmpty)
        let snapshot = try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath: dir.path)
            .first { $0.hasPrefix("pre-import-") })
        let kept = try JSONDecoder().decode(AppData.self,
                                            from: Data(contentsOf: dir.appendingPathComponent(snapshot)))
        XCTAssertEqual(kept.sessions.map(\.planName), ["Push"])
    }

    // MARK: Deleting an exercise

    func testDeletingAnExerciseLeavesUnrelatedEmptySessionsAlone() {
        let store = Store(directory: dir)
        var imported = WorkoutSession(date: "2026-09-20", planId: "health-strength",
                                      planName: "Weight Training", planColor: "92e82a")
        imported.healthUUID = "ABC"
        var mixed = strengthSession("Bench")
        mixed.exercises.append(LoggedExercise(name: "Row", sets: [SetEntry(reps: "8", weight: "60")],
                                              notes: "", target: "1×8"))
        store.sessions = [imported, strengthSession("Bench"), mixed]

        store.deleteExercise("Bench")

        XCTAssertEqual(store.sessions.count, 2, "only the session emptied by this delete goes")
        XCTAssertTrue(store.sessions.contains { $0.healthUUID == "ABC" })
        XCTAssertEqual(store.sessions.last?.exercises.map(\.name), ["Row"])
    }
}
