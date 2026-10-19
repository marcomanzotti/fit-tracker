import Foundation

// Data leaving the app: a daily copy in a folder of the person's choice, and the
// history as CSV for a spreadsheet.

// MARK: - Backup outside the phone
/// A daily copy of the data file in a folder the person picks once, usually in
/// iCloud Drive: deleting the app no longer takes the whole history with it. The
/// folder is remembered on this device with a security-scoped bookmark; the copy
/// runs after a save, at most once a day, and the folder keeps the last two weeks.
enum ExternalBackup {
    static let kept = 14
    private static let prefix = "FitTracker-"
    private static let bookmarkKey = "externalBackup.folder"
    private static let lastDayKey = "externalBackup.lastDay"
    private static let failedKey = "externalBackup.failed"

    /// Remember the folder. The first copy happens on the next save.
    static func choose(_ folder: URL, defaults: UserDefaults = .standard) throws {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let bookmark = try folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(bookmark, forKey: bookmarkKey)
        defaults.removeObject(forKey: lastDayKey)
        defaults.removeObject(forKey: failedKey)
    }

    static func forget(defaults: UserDefaults = .standard) {
        [bookmarkKey, lastDayKey, failedKey].forEach { defaults.removeObject(forKey: $0) }
    }

    static func folderName(defaults: UserDefaults = .standard) -> String? { folder(defaults: defaults)?.lastPathComponent }
    static func lastCopyDay(defaults: UserDefaults = .standard) -> String? { defaults.string(forKey: lastDayKey) }
    /// The last attempt could not write into the folder (moved, deleted, offline provider).
    static func lastAttemptFailed(defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: failedKey) }

    /// Copy `file` into the folder unless today's copy exists (`force` for "copy now").
    /// Returns the error when the copy failed; nil when it worked or was not due.
    @discardableResult
    static func copyIfDue(_ file: URL, day: String, force: Bool = false, defaults: UserDefaults = .standard) -> Error? {
        guard let folder = folder(defaults: defaults), force || defaults.string(forKey: lastDayKey) != day else { return nil }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let target = folder.appendingPathComponent("\(prefix)\(day).json")
        var failure: Error?
        var coordination: NSError?
        // Coordinated, so a cloud provider sees one complete file and never a half-written one.
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordination) { url in
            do {
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                try FileManager.default.copyItem(at: file, to: url)
            } catch {
                failure = error
            }
        }
        if let error = coordination ?? failure {
            appLog.error("Backup copy failed: \(String(describing: error), privacy: .public)")
            defaults.set(true, forKey: failedKey)
            return error
        }
        defaults.set(day, forKey: lastDayKey)
        defaults.set(false, forKey: failedKey)
        prune(folder)
        return nil
    }

    private static func folder(defaults: UserDefaults) -> URL? {
        guard let bookmark = defaults.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(fresh, forKey: bookmarkKey)
        }
        return url
    }

    /// The day in the name sorts as text, so the oldest copies are the last ones.
    private static func prune(_ folder: URL) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names.filter({ $0.hasPrefix(prefix) && $0.hasSuffix(".json") }).sorted(by: >).dropFirst(kept) {
            do {
                try FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            } catch {
                appLog.error("Could not remove old backup \(name, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }
}

// MARK: - Spreadsheet export (CSV)
/// The history as two CSV files for a spreadsheet: every set of every session, and
/// one row per day. Comma separated, dot decimals, kg, km and minutes.
enum CSVExport {
    static func sessions(_ store: Store) -> String {
        var rows = ["date,session,sport,exercise,set,reps,weight_kg,seconds,effort,duration_min,avg_hr,distance_km,kcal"]
        for s in store.sessions.sorted(by: { $0.date < $1.date }) {
            let tail = [s.durationMinutesD.map { num($0) } ?? "", s.avgHR.map(String.init) ?? "",
                        s.distanceKm.map { num($0) } ?? "", String(store.estimateCalories(s))]
            let head = [s.date, field(s.planName), s.sportType.rawValue]
            if s.exercises.isEmpty { rows.append((head + ["", "", "", "", "", ""] + tail).joined(separator: ",")) }
            for e in s.exercises {
                for (i, set) in e.sets.enumerated() where set.filled {
                    let cells = [field(e.name), String(i + 1), plain(set.reps), plain(set.weight),
                                 set.seconds.map { num($0) } ?? "", set.effortVal.map(String.init) ?? ""]
                    rows.append((head + cells + tail).joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    static func daily(_ store: Store) -> String {
        var rows = ["date,weight_kg,body_fat_pct,sleep_hours,sleep_score,hrv_ms,resting_hr,steps,active_kcal,kcal_eaten,protein_g,carbs_g,fat_g"]
        for e in store.sortedDaily {
            let eaten = e.hasNutrition
            let cells: [String] = [
                e.date, e.weight.map { num($0) } ?? "", e.bodyFat.map { num($0) } ?? "", e.sleepHours.map { num($0) } ?? "",
                e.sleep.map(String.init) ?? "", e.hrvSleep.map { num($0) } ?? "", e.restHR.map(String.init) ?? "",
                e.steps.map(String.init) ?? "", e.activeKcal.map(String.init) ?? "",
                eaten ? String(e.totalKcal) : "", eaten ? num(e.totalProtein) : "", eaten ? num(e.totalCarbs) : "",
                eaten ? num(e.totalFat) : ""
            ]
            rows.append(cells.joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// Both files in a temporary folder, ready to share; nil when they could not be written.
    static func files(_ store: Store) -> [URL]? {
        let folder = FileManager.default.temporaryDirectory
        let pairs = [("fittracker-sessions-\(today()).csv", sessions(store)), ("fittracker-daily-\(today()).csv", daily(store))]
        do {
            return try pairs.map { name, text in
                let url = folder.appendingPathComponent(name)
                try text.write(to: url, atomically: true, encoding: .utf8)
                return url
            }
        } catch {
            appLog.error("CSV export failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func num(_ v: Double) -> String { trimNum((v * 100).rounded() / 100) }
    /// A typed number ("2,5") in dot form; empty when there is none.
    private static func plain(_ typed: String) -> String { pf(typed) > 0 ? num(pf(typed)) : "" }

    /// Quoted when it holds a comma, a quote or a line break; quotes doubled.
    private static func field(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
