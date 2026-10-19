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
        XCTAssertTrue(store.plans.isEmpty, "plans the user deleted stay deleted")
        XCTAssertFalse(store.cardioTypes.isEmpty, "a file older than cardio activities gets the defaults")
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

    // MARK: Apple Health values

    func testHealthNeverOverwritesATypedValueUnlessReimported() {
        let store = Store(directory: dir)
        store.saveCheckIn(weight: 80, sleep: nil, restHR: 55, date: "2026-10-01")
        let sample = HealthDaySample(date: "2026-10-01", values: [.restHR: 62, .weight: 85, .steps: 9_000])

        store.applyHealthSamples([sample])
        XCTAssertEqual(store.dailyEntry("2026-10-01")?.restHR, 55)
        XCTAssertEqual(store.dailyEntry("2026-10-01")?.weight, 80)
        XCTAssertEqual(store.dailyEntry("2026-10-01")?.steps, 9_000)

        store.applyHealthSamples([sample], overwrite: true)
        XCTAssertEqual(store.dailyEntry("2026-10-01")?.restHR, 62)
        XCTAssertEqual(store.dailyEntry("2026-10-01")?.weight, 85)
    }

    func testHealthCorrectsAValueItWroteEarlier() {
        let store = Store(directory: dir)
        // Watch and band counted twice by an old version, then read correctly.
        store.applyHealthSamples([HealthDaySample(date: "2026-10-01", values: [.sleepHours: 14, .activeKcal: 900])])
        store.applyHealthSamples([HealthDaySample(date: "2026-10-01", values: [.sleepHours: 7.2, .activeKcal: 640])])

        let e = store.dailyEntry("2026-10-01")
        XCTAssertEqual(e?.sleepHours, 7.2)
        XCTAssertEqual(e?.activeKcal, 640)
        XCTAssertEqual(e?.sleep, Store.sleepScore(hours: 7.2), "the score follows the night")
    }

    func testAVersionOneTypedSleepScoreIsKeptAndADerivedOneIsRecomputed() throws {
        let typed = DailyEntry(date: "2026-10-01", sleep: 70, sleepHours: 8)      // v1 formula gives 100
        let derived = DailyEntry(date: "2026-10-02", sleep: 100, sleepHours: 8)
        var doc = AppData(sessions: [])
        doc.daily = [typed, derived]
        doc.schemaVersion = 1
        try JSONEncoder().encode(doc).write(to: dataFile)

        let store = Store(directory: dir)
        store.applyHealthSamples([HealthDaySample(date: "2026-10-01", values: [.sleepHours: 6]),
                                  HealthDaySample(date: "2026-10-02", values: [.sleepHours: 6])])

        XCTAssertEqual(store.dailyEntry("2026-10-01")?.sleep, 70)
        XCTAssertEqual(store.dailyEntry("2026-10-02")?.sleep, Store.sleepScore(hours: 6))
    }

    func testACategorySelectionSavedBeforeV12GetsTheNewCategories() {
        var prefs = Prefs()
        prefs.healthImport = ["steps", "sleep"]
        XCTAssertTrue(prefs.healthCategories.isSuperset(of: ["steps", "sleep", "spo2", "respRate"]))
        XCTAssertFalse(prefs.healthCategories.contains("restHR"))

        prefs.setHealthCategories(["steps"])
        XCTAssertEqual(prefs.healthCategories, ["steps"])
    }

    // MARK: v14

    func testANumberThatIsNotFiniteIsSavedAsZeroAndSavingGoesOn() {
        let store = Store(directory: dir)
        store.foods = [FoodItem(name: "Scanned", k100: .nan, p100: .infinity)]
        store.flushNow()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))     // the save result lands on main

        XCTAssertNil(store.storageProblem)
        let reread = Store(directory: dir)
        XCTAssertEqual(reread.foods.first?.k100, 0)
        XCTAssertEqual(reread.foods.first?.p100, 0)
        XCTAssertEqual(FoodLog(name: "x", grams: 100, k100: .nan, p100: 0, c100: 0, f100: 0).kcal, 0, "never traps")
    }

    func testFoodFactsKeepsOnlyFiniteAndPlausibleNumbers() throws {
        let json = """
        {"status":1,"product":{"product_name":"Cracker","nutriments":{"energy-kcal_100g":"nan",
        "energy-kj_100g":"inf","proteins_100g":"12","carbohydrates_100g":250,"fat_100g":"-3"}}}
        """
        let food = try XCTUnwrap(OpenFoodFacts.parse(Data(json.utf8), barcode: "12345678"))

        XCTAssertEqual(food.k100, 0)
        XCTAssertEqual(food.p100, 12)
        XCTAssertEqual(food.c100, 0, "more than 100 g in 100 g")
        XCTAssertEqual(food.f100, 0)
    }

    func testDefaultPlansDoNotComeBackOnceAllAreDeleted() {
        let first = Store(directory: dir)
        XCTAssertFalse(first.plans.isEmpty, "a first launch starts from the templates")
        first.plans = []
        first.cardioTypes = []
        first.flushNow()

        let second = Store(directory: dir)
        XCTAssertTrue(second.plans.isEmpty)
        XCTAssertTrue(second.cardioTypes.isEmpty)
    }

    func testLaunchingDoesNotMarkThePlansExercisesAsUsed() {
        Store(directory: dir).flushNow()
        let second = Store(directory: dir)
        XCTAssertTrue(second.exerciseItems.allSatisfy { $0.lastUsed == nil }, "nothing was logged yet")
    }

    func testOlderDataTakesLastUsedFromTheSessionsAndTheRateSignFromTheGoal() throws {
        var doc = AppData(sessions: [strengthSession("Bench", date: "2026-09-01")])
        doc.schemaVersion = 2
        doc.exerciseItems = [ExerciseItem(name: "Bench", lastUsed: "2026-10-18"),
                             ExerciseItem(name: "Fly", lastUsed: "2026-10-18")]
        doc.prefs.goalMode = "cut"
        doc.prefs.weeklyRate = 0.5
        try JSONEncoder().encode(doc).write(to: dataFile)

        let store = Store(directory: dir)

        XCTAssertEqual(store.exerciseItems.first { $0.name == "Bench" }?.lastUsed, "2026-09-01")
        XCTAssertNil(store.exerciseItems.first { $0.name == "Fly" }?.lastUsed, "never logged")
        XCTAssertEqual(store.prefs.weeklyRate, -0.5)
    }

    // MARK: Undo of a deletion

    func testADeletedPlanComesBackInPlaceWithItsScheduleDay() {
        let store = Store(directory: dir)
        let id = store.plans[1].id
        store.prefs.schedule = ["", id, "", "", "", "", ""]

        let removed = store.deletePlan(id)
        XCTAssertFalse(store.plans.contains { $0.id == id })
        XCTAssertEqual(store.prefs.schedule?[1], "")

        store.restorePlan(removed!)
        XCTAssertEqual(store.plans[1].id, id)
        XCTAssertEqual(store.prefs.schedule?[1], id)
    }

    func testADeletedCardioActivityComesBack() {
        let store = Store(directory: dir)
        let activity = store.cardioTypes[0]
        let removed = store.deleteCardioType(activity.id)
        store.restoreCardioType(removed!)
        XCTAssertEqual(store.cardioTypes.first?.id, activity.id)
    }

    func testAClearedNutritionDayComesBackWithItsFoods() {
        let store = Store(directory: dir)
        let food = FoodLog(name: "Rice", grams: 200, k100: 130, p100: 2.7, c100: 28, f100: 0.3)
        store.saveDayFoods(date: "2026-10-01", foods: [food])
        store.upsertDaily("2026-10-01") { $0.weight = 80 }

        let before = store.clearNutrition(date: "2026-10-01")
        XCTAssertNil(store.dailyEntry("2026-10-01")?.foods)

        store.restoreNutrition(before!)
        XCTAssertEqual(store.dailyEntry("2026-10-01")?.foods?.count, 1)
        XCTAssertEqual(store.dailyEntry("2026-10-01")?.weight, 80, "the rest of the day was never touched")
    }

    func testAPlainToastWaitsForAPendingUndo() {
        let toasts = ToastCenter()
        var undone = false
        toasts.showUndo("Deleted") { undone = true }
        toasts.show("Saved")

        XCTAssertEqual(toasts.message, "Deleted", "the Undo stays reachable")
        toasts.runAction()
        XCTAssertTrue(undone)
        XCTAssertEqual(toasts.message, "Saved", "the waiting message comes next")
    }

    // MARK: Copy outside the phone

    func testTheDataFileIsCopiedToThePickedFolderOnceADayAndOldCopiesAreTrimmed() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "backup-\(UUID().uuidString)"))
        let folder = dir.appendingPathComponent("iCloud", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("v1".utf8).write(to: dataFile)
        try ExternalBackup.choose(folder, defaults: defaults)

        XCTAssertNil(ExternalBackup.copyIfDue(dataFile, day: "2026-10-19", defaults: defaults))
        try Data("v2".utf8).write(to: dataFile)
        ExternalBackup.copyIfDue(dataFile, day: "2026-10-19", defaults: defaults)
        let copy = folder.appendingPathComponent("FitTracker-2026-10-19.json")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "v1", "one copy a day")

        for day in 1...20 { ExternalBackup.copyIfDue(dataFile, day: String(format: "2026-11-%02d", day), defaults: defaults) }
        let copies = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("FitTracker-") }
        XCTAssertEqual(copies.count, ExternalBackup.kept)
        XCTAssertTrue(copies.contains("FitTracker-2026-11-20.json"))
        XCTAssertEqual(ExternalBackup.lastCopyDay(defaults: defaults), "2026-11-20")
    }

    // MARK: Spreadsheet export

    func testTheSessionsCSVHasOneRowPerSetAndQuotesCommas() {
        let store = Store(directory: dir)
        var bench = strengthSession("Bench, paused")
        bench.exercises[0].sets.append(SetEntry(reps: "6", weight: "105"))
        store.sessions = [bench]

        let lines = CSVExport.sessions(store).split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 3, "header + one row per set")
        XCTAssertTrue(lines[1].contains("\"Bench, paused\""))
        XCTAssertTrue(lines[2].hasPrefix("2026-10-01,Push,strength,\"Bench, paused\",2,6,105"))
    }

    func testTheDailyCSVHasOneRowPerDay() {
        let store = Store(directory: dir)
        store.daily = [DailyEntry(date: "2026-10-01", weight: 80.5), DailyEntry(date: "2026-10-02", steps: 9000)]
        let lines = CSVExport.daily(store).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].hasPrefix("2026-10-01,80.5"))
    }

    // MARK: Fibre, salt and food search

    func testAScannedFoodKeepsFibreAndSaltAndSodiumBecomesSalt() throws {
        let json = #"{"status":1,"product":{"product_name":"Oats","nutriments":{"energy-kcal_100g":370,"proteins_100g":13,"carbohydrates_100g":60,"fat_100g":7,"fiber_100g":10,"sodium_100g":0.2}}}"#
        let food = try XCTUnwrap(OpenFoodFacts.parse(Data(json.utf8), barcode: "12345678"))
        XCTAssertEqual(food.fiber100, 10)
        XCTAssertEqual(food.salt100 ?? 0, 0.5, accuracy: 0.001)

        let log = food.log(50)
        XCTAssertEqual(log.fiber ?? 0, 5, accuracy: 0.001)
        let day = DailyEntry(date: "2026-10-01", foods: [log, food.log(50)])
        XCTAssertEqual(day.totalFiber ?? 0, 10, accuracy: 0.001)
        XCTAssertEqual(day.totalSalt ?? 0, 0.5, accuracy: 0.001)
    }

    func testFoodSearchResultsAreParsedAndAServerErrorIsNotProductNotFound() {
        let json = #"{"products":[{"code":"8001","product_name":"Pasta","brands":"Barilla","nutriments":{"energy-kcal_100g":359,"proteins_100g":12.5}},{"code":"8002","nutriments":{}}]}"#
        let found = OpenFoodFacts.parseSearch(Data(json.utf8))
        XCTAssertEqual(found.map(\.name), ["Pasta"], "a result with nothing usable is dropped")
        XCTAssertEqual(found.first?.brand, "Barilla")

        XCTAssertEqual(OpenFoodFacts.outcome(status: 404, data: Data(), barcode: "8001"), .notFound)
        XCTAssertEqual(OpenFoodFacts.outcome(status: 503, data: Data(), barcode: "8001"), .unreachable)
    }
}
