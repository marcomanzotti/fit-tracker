import Foundation

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
