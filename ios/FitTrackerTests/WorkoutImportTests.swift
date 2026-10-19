import XCTest
@testable import FitTracker

/// Workouts from any device end up as one session each, with every metric the
/// device measured, and what the user typed is never overwritten.
final class WorkoutImportTests: XCTestCase {
    private var dir: URL!
    private var store: Store!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("import-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = Store(directory: dir)
    }

    override func tearDownWithError() throws {
        store = nil
        try FileManager.default.removeItem(at: dir)
    }

    private func workout(_ uuid: String = UUID().uuidString, sport: String = "running", seconds: Int = 1800,
                         avgHR: Int? = 150, metrics: [WorkoutMetric: Double] = [.cadence: 160],
                         fromThisApp: Bool = false, date: String = "2026-10-10", start: Date? = nil) -> HealthWorkout {
        var m = WorkoutMeasures()
        m.durationSec = seconds
        m.avgHR = avgHR
        m.maxHR = 175
        m.kcal = 400
        m.distanceKm = sport == "strength" ? nil : 5
        m.metrics = metrics
        return HealthWorkout(uuid: uuid, date: date, sport: sport, displayName: "Running", measures: m,
                             fromThisApp: fromThisApp, sourceName: "Garmin Connect",
                             start: start, end: start?.addingTimeInterval(TimeInterval(seconds)))
    }

    /// A clock time on the test day.
    private func at(_ time: String, on date: String = "2026-10-10") -> Date {
        cachedFormatter("yyyy-MM-dd HH:mm").date(from: "\(date) \(time)")!
    }

    private func manualSession(sport: String?, seconds: Int?, date: String = "2026-10-10") -> WorkoutSession {
        var s = WorkoutSession(date: date, planId: "p1", planName: "Push", planColor: "ff5a52")
        s.sport = sport
        s.durationSec = seconds
        return s
    }

    // MARK: Metric layers

    func testTypedValueWinsAndClearingItBringsTheDeviceValueBack() {
        var s = manualSession(sport: "running", seconds: 600)
        s.absorbDevice([.cadence: 160])
        s.setTyped(.cadence, 172)
        XCTAssertEqual(s.metric(.cadence), 172)
        XCTAssertEqual(s.deviceMetric(.cadence), 160)

        s.setTyped(.cadence, nil)
        XCTAssertEqual(s.metric(.cadence), 160)
        XCTAssertNil(s.metricOverrides, "no empty dictionary left behind")
    }

    func testAbsorbFillsOnlyEmptyCoreFields() {
        var s = manualSession(sport: "running", seconds: 1750)
        s.avgHR = 140
        var m = WorkoutMeasures()
        m.durationSec = 1800
        m.avgHR = 150
        m.maxHR = 180
        s.absorb(m)
        XCTAssertEqual(s.durationSec, 1750)
        XCTAssertEqual(s.avgHR, 140)
        XCTAssertEqual(s.maxHRSes, 180)
    }

    // MARK: Health sync

    func testWorkoutFromAnotherDeviceBecomesASessionWithItsMetrics() {
        let r = store.applyHealthWorkouts([workout("A", metrics: [.cadence: 160, .avgPower: 250])])

        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.sources, ["Garmin Connect"])
        let s = store.sessions[0]
        XCTAssertEqual(s.healthUUID, "A")
        XCTAssertEqual(s.avgHR, 150)
        XCTAssertEqual(s.caloriesManual, 400)
        XCTAssertEqual(s.metric(.avgPower), 250)
    }

    func testSyncingAgainRefreshesTheDeviceButNeverWhatTheUserTyped() {
        store.applyHealthWorkouts([workout("A", metrics: [.cadence: 160])])
        var s = store.sessions[0]
        s.avgHR = 140
        s.setTyped(.cadence, 170)
        store.saveSession(s)

        let r = store.applyHealthWorkouts([workout("A", avgHR: 152, metrics: [.cadence: 165, .steps: 5000])])

        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(store.sessions.count, 1)
        let after = store.sessions[0]
        XCTAssertEqual(after.avgHR, 140)
        XCTAssertEqual(after.metric(.cadence), 170)
        XCTAssertEqual(after.deviceMetric(.cadence), 165)
        XCTAssertEqual(after.metric(.steps), 5000)
    }

    func testWatchWorkoutEnrichesTheSessionLoggedByHandInsteadOfAddingOne() {
        store.sessions = [manualSession(sport: nil, seconds: 3600)]

        let r = store.applyHealthWorkouts([workout("W", sport: "strength", seconds: 3700, avgHR: 128, metrics: [.mets: 5.5])])

        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].healthUUID, "W")
        XCTAssertEqual(store.sessions[0].avgHR, 128)
        XCTAssertEqual(store.sessions[0].metric(.mets), 5.5)
    }

    func testOwnWatchWorkoutIsNeverAddedOrGuessedOntoAnotherSession() {
        store.applyHealthWorkouts([workout("own", fromThisApp: true)])
        XCTAssertTrue(store.sessions.isEmpty, "the watch already delivered it over WatchConnectivity")

        // Its own session arrives with the UUID; a look-alike manual one is left alone.
        store.sessions = [manualSession(sport: "running", seconds: 1790)]
        store.applyHealthWorkouts([workout("own", fromThisApp: true)])
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertNil(store.sessions[0].healthUUID)
    }

    func testSecondDeviceRecordingTheSameWorkoutJoinsTheSessionInsteadOfAddingOne() {
        let r = store.applyHealthWorkouts([
            workout("watch", metrics: [.cadence: 160]),
            workout("band", seconds: 1830, metrics: [.cadence: 150, .aerobicEffect: 3.1]),
        ])

        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(store.sessions.count, 1)
        let s = store.sessions[0]
        XCTAssertEqual(s.healthUUID, "watch")
        XCTAssertEqual(s.mergedHealthUUIDs, ["band"])
        XCTAssertEqual(s.metric(.cadence), 160, "the first device's value is kept")
        XCTAssertEqual(s.metric(.aerobicEffect), 3.1, "what only the second measured is added")
        store.applyHealthWorkouts([workout("band", seconds: 1830)])
        XCTAssertEqual(store.sessions.count, 1)
    }

    func testAFieldTheUserClearedIsNotRefilledBySync() {
        store.applyHealthWorkouts([workout("A")])
        var s = store.sessions[0]
        s.avgHR = nil
        store.saveSession(s)

        store.applyHealthWorkouts([workout("A")])

        XCTAssertNil(store.sessions[0].avgHR)
    }

    func testAbsurdNumbersInAFileAreDroppedNotConverted() throws {
        let tcx = """
        <?xml version="1.0"?>
        <TrainingCenterDatabase><Activities><Activity Sport="Running"><Lap>
        <TotalTimeSeconds>1e30</TotalTimeSeconds><Calories>inf</Calories><Track>
        <Trackpoint><Time>2026-10-01T07:00:00Z</Time><HeartRateBpm><Value>nan</Value></HeartRateBpm></Trackpoint>
        <Trackpoint><Time>2026-10-01T07:10:00Z</Time></Trackpoint>
        </Track></Lap></Activity></Activities></TrainingCenterDatabase>
        """
        let p = try XCTUnwrap(WorkoutFile.parse(Data(tcx.utf8)))

        XCTAssertEqual(p.durationSec, 0)
        XCTAssertNil(p.kcal)
        XCTAssertNil(p.measures.avgHR)
    }

    func testWithImportOffLinkedSessionsStillRefreshButNothingIsAdded() {
        var linked = manualSession(sport: "running", seconds: 1800)
        linked.healthUUID = "L"
        store.sessions = [linked]

        let r = store.applyHealthWorkouts([workout("L", metrics: [.cadence: 158]), workout("new", date: "2026-10-11")],
                                          importNew: false)

        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].metric(.cadence), 158)
    }

    func testExportedWorkoutDoesNotComeBackAsASecondSession() {
        var s = manualSession(sport: "running", seconds: 1800)
        s.exportedHealthUUID = "X"
        store.sessions = [s]

        store.applyHealthWorkouts([workout("X", fromThisApp: true)])

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertNil(store.sessions[0].healthUUID)
    }

    func testASessionWithoutDurationMatchesOnlyWhenItIsTheDaysOnlyCandidate() {
        let one = [manualSession(sport: nil, seconds: nil)]
        XCTAssertEqual(Store.matchingSession(for: workout(sport: "strength"), in: one), 0)

        let two = [manualSession(sport: nil, seconds: nil), manualSession(sport: nil, seconds: nil)]
        XCTAssertNil(Store.matchingSession(for: workout(sport: "strength"), in: two))

        let otherDay = [manualSession(sport: nil, seconds: nil, date: "2026-10-09")]
        XCTAssertNil(Store.matchingSession(for: workout(sport: "strength"), in: otherDay))
    }

    func testMergingKeepsEveryMetricWithThePrimaryWinning() throws {
        var a = manualSession(sport: "running", seconds: 600)
        a.absorbDevice([.cadence: 160])
        var b = manualSession(sport: "running", seconds: 600)
        b.absorbDevice([.cadence: 150, .avgPower: 240])
        store.sessions = [a, b]

        let merged = try XCTUnwrap(store.mergeSessions([a.id, b.id], keeping: a.id))

        XCTAssertEqual(merged.metric(.cadence), 160)
        XCTAssertEqual(merged.metric(.avgPower), 240)
    }

    // MARK: Same day, different workouts

    func testTwoRidesOnTheSameDayStayTwoSessions() {
        let r = store.applyHealthWorkouts([
            workout("morning", sport: "cycling", seconds: 1500, start: at("08:00")),
            workout("evening", sport: "cycling", seconds: 1620, avgHR: 120, start: at("18:00")),
        ])

        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(Set(store.sessions.compactMap(\.healthUUID)), ["morning", "evening"])
        XCTAssertEqual(store.sessions.first { $0.healthUUID == "evening" }?.avgHR, 120,
                       "the second ride keeps its own numbers")
    }

    func testWatchAndBandWornTogetherStillMakeOneSession() {
        let r = store.applyHealthWorkouts([
            workout("watch", seconds: 1800, start: at("08:00")),
            workout("band", seconds: 1750, metrics: [.aerobicEffect: 3], start: at("08:01")),
        ])

        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(store.sessions.first?.mergedHealthUUIDs, ["band"])
    }

    func testARideTheOldRuleFoldedIntoAnotherCanBeImportedByHand() {
        var morning = manualSession(sport: "cycling", seconds: 1500)
        morning.healthUUID = "morning"
        morning.mergedHealthUUIDs = ["evening"]
        store.sessions = [morning]
        // The sync gives the session the time span of its own workout.
        store.applyHealthWorkouts([workout("morning", sport: "cycling", seconds: 1500, start: at("08:00"))])
        let evening = workout("evening", sport: "cycling", seconds: 1620, start: at("18:00"))

        XCTAssertEqual(store.importable([evening]).map(\.uuid), ["evening"])
        store.importHealthWorkout(evening)

        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertNil(store.sessions.first { $0.healthUUID == "morning" }?.mergedHealthUUIDs)
        XCTAssertTrue(store.importable([evening]).isEmpty)
    }

    func testADeletedHealthWorkoutDoesNotComeBackOnTheNextSync() throws {
        store.applyHealthWorkouts([workout("A")])
        let removed = try XCTUnwrap(store.deleteSession(store.sessions[0].id))

        store.applyHealthWorkouts([workout("A")])
        XCTAssertTrue(store.sessions.isEmpty)

        store.restoreSession(removed.session, at: removed.index)           // Undo
        store.applyHealthWorkouts([workout("A")])
        XCTAssertEqual(store.sessions.count, 1)

        store.deleteSession(store.sessions[0].id)
        store.importHealthWorkout(workout("A"))                             // picked by hand from the day
        store.applyHealthWorkouts([workout("A")])
        XCTAssertEqual(store.sessions.count, 1)
    }

    func testTwoFilesOfDifferentRidesOnTheSameDayBothImport() throws {
        func ride(_ name: String, start: String) throws -> URL {
            let tcx = """
            <?xml version="1.0"?>
            <TrainingCenterDatabase><Activities><Activity Sport="Biking"><Id>\(start)</Id>
            <Lap StartTime="\(start)"><TotalTimeSeconds>1500</TotalTimeSeconds><DistanceMeters>9000</DistanceMeters>
            <Track><Trackpoint><Time>\(start)</Time></Trackpoint></Track></Lap></Activity></Activities></TrainingCenterDatabase>
            """
            let url = dir.appendingPathComponent(name)
            try Data(tcx.utf8).write(to: url)
            return url
        }
        let morning = try ride("morning.tcx", start: "2026-10-01T07:00:00Z")
        let evening = try ride("evening.tcx", start: "2026-10-01T16:00:00Z")

        guard case .imported = store.importWorkoutFile(morning) else { return XCTFail("morning not imported") }
        guard case .imported = store.importWorkoutFile(evening) else { return XCTFail("evening not imported") }
        guard case .alreadyLogged = store.importWorkoutFile(morning) else { return XCTFail("same file twice") }
        XCTAssertEqual(store.sessions.count, 2)
    }

    // MARK: Sessions from the watch and from the day picker

    func testWatchResultArrivingAfterTheSessionWasSavedJoinsIt() {
        var saved = WorkoutSession(date: "2026-10-10", planId: "p1", planName: "Push", planColor: "ff5a52",
                                   exercises: [LoggedExercise(name: "Bench", sets: [SetEntry(reps: "8", weight: "100")])])
        saved.durationSec = 3_000
        store.sessions = [saved]
        let r = WatchResult(id: UUID().uuidString, date: "2026-10-10", kind: "strength", activityId: "p1",
                            name: "Push", color: "ff5a52", sport: nil, durationSec: 3_100, avgHR: 128, maxHR: 160,
                            activeKcal: 320, distanceKm: nil, healthUUID: "HK1")

        store.ingestWatchResult(r)
        store.ingestWatchResult(r)          // the second transport

        XCTAssertEqual(store.sessions.count, 1)
        let s = store.sessions[0]
        XCTAssertEqual(s.avgHR, 128)
        XCTAssertEqual(s.caloriesManual, 320)
        XCTAssertEqual(s.durationSec, 3_000, "what the phone recorded stays")
        XCTAssertEqual(s.healthUUID, "HK1")
        XCTAssertEqual(s.exercises.count, 1)
    }

    func testASessionFromTheDayPickerExistsOnlyOnceSaved() {
        let plan = WorkoutPlan(id: "p1", name: "Push", exercises: [PlanExercise(name: "Bench")])
        store.setRestDay("2026-10-09", on: true)

        let draft = store.newSession(plan: plan, date: "2026-10-09")
        XCTAssertTrue(store.sessions.isEmpty, "cancelling the editor leaves nothing behind")
        XCTAssertTrue(store.isRestDay("2026-10-09"))

        store.saveSession(draft)
        XCTAssertEqual(store.sessions.map(\.id), [draft.id])
        XCTAssertFalse(store.isRestDay("2026-10-09"))
    }

    // MARK: Files

    func testFitFileGivesTotalsMetricsAndTrack() throws {
        let p = try XCTUnwrap(WorkoutFile.parse(FitFixture.run()))

        XCTAssertEqual(p.sport, "running")
        XCTAssertEqual(p.durationSec, 1800)
        XCTAssertEqual(p.distanceKm, 5)
        XCTAssertEqual(p.kcal, 400)
        XCTAssertEqual(p.measures.avgHR, 150)
        XCTAssertEqual(p.measures.maxHR, 175)
        XCTAssertEqual(p.elevationM, 42)
        XCTAssertEqual(p.measures.metrics[.cadence], 170, "strides per minute doubled to steps")
        XCTAssertEqual(p.measures.metrics[.avgPower], 250)
        XCTAssertEqual(p.measures.metrics[.maxPower], 320)
        XCTAssertEqual(try XCTUnwrap(p.measures.metrics[.aerobicEffect]), 3.2, accuracy: 0.001)
        XCTAssertEqual(p.start, Date(timeIntervalSince1970: FitFixture.start + 631_065_600))
        XCTAssertEqual(p.points.count, 3)
        XCTAssertEqual(try XCTUnwrap(p.points[0].lat), 45, accuracy: 0.0001)
        XCTAssertNil(p.points[1].hr, "0xFF is FIT's 'no value'")
        XCTAssertEqual(p.points[2].time, Date(timeIntervalSince1970: FitFixture.start + 631_065_600 + 2),
                       "compressed timestamp")
        XCTAssertEqual(p.points[2].hr, 160)
    }

    func testTcxFileReadsPowerCadenceAndClimbFromTheTrack() throws {
        let tcx = """
        <?xml version="1.0"?>
        <TrainingCenterDatabase xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
        <Activities><Activity Sport="Biking"><Id>2026-10-01T07:00:00Z</Id>
        <Lap StartTime="2026-10-01T07:00:00Z"><TotalTimeSeconds>600</TotalTimeSeconds><DistanceMeters>5000</DistanceMeters>
        <Calories>150</Calories><Track>
        <Trackpoint><Time>2026-10-01T07:00:00Z</Time><AltitudeMeters>100</AltitudeMeters>
        <HeartRateBpm><Value>120</Value></HeartRateBpm><Cadence>80</Cadence>
        <Extensions><ns3:TPX><ns3:Watts>200</ns3:Watts></ns3:TPX></Extensions></Trackpoint>
        <Trackpoint><Time>2026-10-01T07:10:00Z</Time><AltitudeMeters>110</AltitudeMeters>
        <HeartRateBpm><Value>140</Value></HeartRateBpm><Cadence>90</Cadence>
        <Extensions><ns3:TPX><ns3:Watts>300</ns3:Watts></ns3:TPX></Extensions></Trackpoint>
        </Track></Lap></Activity></Activities></TrainingCenterDatabase>
        """
        let p = try XCTUnwrap(WorkoutFile.parse(Data(tcx.utf8)))

        XCTAssertEqual(p.sport, "cycling")
        XCTAssertEqual(p.durationSec, 600)
        XCTAssertEqual(p.distanceKm, 5)
        XCTAssertEqual(p.kcal, 150)
        XCTAssertEqual(p.measures.avgHR, 130)
        XCTAssertEqual(p.measures.maxHR, 140)
        XCTAssertEqual(p.elevationM, 10)
        XCTAssertEqual(p.measures.metrics[.cadence], 85)
        XCTAssertEqual(p.measures.metrics[.avgPower], 250)
        XCTAssertEqual(p.measures.metrics[.maxPower], 300)
        XCTAssertEqual(p.measures.metrics[.minHR], 120)
    }

    func testGpxFileMeasuresDistanceFromPositions() throws {
        let gpx = """
        <?xml version="1.0"?>
        <gpx xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"><trk><type>running</type><trkseg>
        <trkpt lat="45.0" lon="9.0"><ele>120</ele><time>2026-10-01T07:00:00Z</time>
        <extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>140</gpxtpx:hr><gpxtpx:cad>84</gpxtpx:cad></gpxtpx:TrackPointExtension></extensions></trkpt>
        <trkpt lat="45.009" lon="9.0"><ele>121</ele><time>2026-10-01T07:05:00Z</time>
        <extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>160</gpxtpx:hr><gpxtpx:cad>86</gpxtpx:cad></gpxtpx:TrackPointExtension></extensions></trkpt>
        </trkseg></trk></gpx>
        """
        let p = try XCTUnwrap(WorkoutFile.parse(Data(gpx.utf8)))

        XCTAssertEqual(p.sport, "running")
        XCTAssertEqual(p.durationSec, 300)
        XCTAssertEqual(try XCTUnwrap(p.distanceKm), 1.0, accuracy: 0.01)
        XCTAssertEqual(p.measures.avgHR, 150)
        XCTAssertEqual(p.measures.metrics[.cadence], 170)
        XCTAssertNil(p.elevationM, "one metre of GPS noise is no climb")
    }

    func testFileImportCreatesASessionWithTheFilesMetrics() throws {
        let url = dir.appendingPathComponent("ride.fit")
        try FitFixture.run().write(to: url)

        guard case .imported(let s) = store.importWorkoutFile(url) else { return XCTFail("expected an import") }

        XCTAssertEqual(s.source, "ride.fit")
        XCTAssertEqual(s.metric(.avgPower), 250)
        guard case .alreadyLogged = store.importWorkoutFile(url) else { return XCTFail("the same file twice is one session") }
    }
}

/// A small FIT activity: a session and three records, the last one with a
/// compressed timestamp (laid out by a definition without the timestamp field).
private enum FitFixture {
    static let start: TimeInterval = 1_100_000_000

    static func run() -> Data {
        var body: [UInt8] = []
        func le(_ v: UInt64, _ n: Int) -> [UInt8] { (0..<n).map { UInt8(truncatingIfNeeded: v >> UInt64(8 * $0)) } }
        func define(_ local: UInt8, global: UInt16, _ fields: [(UInt8, UInt8, UInt8)]) {
            body += [0x40 | local, 0, 0] + le(UInt64(global), 2) + [UInt8(fields.count)]
            for f in fields { body += [f.0, f.1, f.2] }
        }
        let ts = UInt64(start)
        define(0, global: 18, [(253, 4, 0x86), (2, 4, 0x86), (5, 1, 0x00), (6, 1, 0x00), (8, 4, 0x86), (9, 4, 0x86),
                               (11, 2, 0x84), (16, 1, 0x02), (17, 1, 0x02), (18, 1, 0x02), (20, 2, 0x84), (21, 2, 0x84),
                               (22, 2, 0x84), (24, 1, 0x02)])
        body += [0] + le(ts + 1800, 4) + le(ts, 4) + [1, 0] + le(1_800_000, 4) + le(500_000, 4)
            + le(400, 2) + [150, 175, 85] + le(250, 2) + le(320, 2) + le(42, 2) + [32]
        let position: [(UInt8, UInt8, UInt8)] = [(0, 4, 0x85), (1, 4, 0x85), (3, 1, 0x02), (7, 2, 0x84)]
        define(1, global: 20, [(253, 4, 0x86)] + position)
        define(2, global: 20, position)
        let lat = UInt64(536_870_912)                  // 45° in semicircles
        body += [1] + le(ts, 4) + le(lat, 4) + le(lat / 5, 4) + [140] + le(240, 2)
        body += [1] + le(ts + 1, 4) + le(lat, 4) + le(lat / 5, 4) + [0xFF] + le(260, 2)
        body += [0x80 | (2 << 5) | UInt8((ts + 2) & 0x1F)] + le(lat, 4) + le(lat / 5, 4) + [160] + le(250, 2)
        let header: [UInt8] = [14, 0x20] + le(2132, 2) + le(UInt64(body.count), 4) + Array(".FIT".utf8) + [0, 0]
        return Data(header + body + [0, 0])
    }
}
