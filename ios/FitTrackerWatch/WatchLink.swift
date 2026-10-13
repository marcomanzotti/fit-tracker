import Foundation
import Combine
import WatchConnectivity

// MARK: - Watch side of the iPhone link
// Receives the activity catalog (strength plans + cardio activities) the phone
// pushes, and sends a finished workout back. A result is kept on disk from the
// moment it exists until the system confirms the phone received it, and is sent
// again at the next launch if that confirmation never came.
@MainActor
final class WatchLink: NSObject, ObservableObject {
    static let shared = WatchLink()

    /// Where the last finished workout stands on its way to the phone.
    enum Delivery: Equatable { case none, queued, delivered, failed }

    @Published var activities: [WatchActivity] = []
    @Published var hasContext = false
    /// Set when the phone asks the wrist to start an activity (its id). The root
    /// view observes this and launches the matching workout.
    @Published var startRequest: String?
    @Published private(set) var delivery: Delivery = .none

    private static let pendingKey = "fittracker.watch.pendingResult"

    func activate() {
        guard WCSession.isSupported() else {
            appLog.error("WatchConnectivity is not supported on this device")
            return
        }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    /// Hand a finished workout to the phone. `transferUserInfo` is queued by the
    /// system and delivered even if the phone app is not running; an immediate
    /// `sendMessage` is added when the phone is reachable, for instant feedback.
    func queue(_ result: WatchResult) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(result), forKey: Self.pendingKey)
        } catch {
            appLog.error("Result not kept for resending: \(String(describing: error), privacy: .public)")
        }
        transfer(result)
    }

    private func transfer(_ result: WatchResult) {
        let payload = WatchWire.encode(result, key: WatchWire.resultKey)
        guard WCSession.isSupported(), !payload.isEmpty else { delivery = .failed; return }
        delivery = .queued
        let s = WCSession.default
        // Not activated yet: resendPending() sends it once activation completes.
        guard s.activationState == .activated else { return }
        s.transferUserInfo(payload)
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { error in
                // The queued transfer above still carries it.
                appLog.error("Immediate result send failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private var pendingResult: WatchResult? {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingKey) else { return nil }
        do {
            return try JSONDecoder().decode(WatchResult.self, from: data)
        } catch {
            appLog.error("Pending result unreadable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Send again a result whose delivery was never confirmed, unless the system is
    /// already holding a transfer for it.
    fileprivate func resendPending() {
        guard let pending = pendingResult else { return }
        let alreadyQueued = WCSession.default.outstandingUserInfoTransfers.contains {
            WatchWire.decode(WatchResult.self, from: $0.userInfo, key: WatchWire.resultKey)?.id == pending.id
        }
        if alreadyQueued { delivery = .queued } else { transfer(pending) }
    }

    fileprivate func transferFinished(_ userInfo: [String: Any], error: Error?) {
        guard let sent = WatchWire.decode(WatchResult.self, from: userInfo, key: WatchWire.resultKey),
              sent.id == pendingResult?.id else { return }
        if let error {
            // Stays on disk: resendPending() tries again at the next launch.
            appLog.error("Result transfer failed: \(String(describing: error), privacy: .public)")
            delivery = .failed
        } else {
            UserDefaults.standard.removeObject(forKey: Self.pendingKey)
            delivery = .delivered
        }
    }

    /// Best-effort live telemetry — only when the phone is reachable. Dropping a
    /// sample is fine; the next one (or the final result) corrects the picture.
    func sendLive(_ sample: WatchLiveSample) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.isReachable else { return }
        let payload = WatchWire.encode(sample, key: WatchWire.liveKey)
        guard !payload.isEmpty else { return }
        s.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    fileprivate func route(_ message: [String: Any]) {
        // A "start this activity" command from the phone arrives as a plain string.
        if let actId = message[WatchWire.startKey] as? String {
            startRequest = actId
            return
        }
        guard let ctx = WatchWire.decode(WatchContext.self, from: message, key: WatchWire.contextKey) else {
            appLog.error("Unrecognised message from the phone, keys: \(message.keys.sorted().joined(separator: ","), privacy: .public)")
            return
        }
        WL.lang = ctx.lang
        activities = ctx.activities
        hasContext = true
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            appLog.error("WatchConnectivity activation failed: \(String(describing: error), privacy: .public)")
        }
        // Pull whatever catalog the phone last published, then retry an unconfirmed result.
        let ctx = session.receivedApplicationContext
        Task { @MainActor in
            if !ctx.isEmpty { self.route(ctx) }
            if state == .activated { self.resendPending() }
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.route(applicationContext) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.route(message) }
    }
    /// The phone asks for a reply when it wants to know the command arrived.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in self.route(message) }
        replyHandler(["ok": true])
    }
    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let userInfo = userInfoTransfer.userInfo
        Task { @MainActor in self.transferFinished(userInfo, error: error) }
    }
}
