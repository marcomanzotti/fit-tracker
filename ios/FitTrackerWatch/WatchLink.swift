import Foundation
import Combine
import WatchConnectivity

// MARK: - Watch side of the iPhone link
// Receives the activity catalog (strength plans + cardio activities) the phone
// pushes, and sends a finished workout back. Sends use transferUserInfo, which
// is queued and delivered even if the phone app isn't reachable right now, and
// also try an immediate sendMessage when reachable for instant feedback.
@MainActor
final class WatchLink: NSObject, ObservableObject {
    static let shared = WatchLink()

    @Published var activities: [WatchActivity] = []
    @Published var hasContext = false

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    func send(_ result: WatchResult) {
        guard WCSession.isSupported() else { return }
        let payload = WatchWire.encode(result, key: WatchWire.resultKey)
        guard !payload.isEmpty else { return }
        let s = WCSession.default
        s.transferUserInfo(payload)                 // reliable, queued
        if s.isReachable { s.sendMessage(payload, replyHandler: nil, errorHandler: nil) }
    }

    fileprivate func ingest(_ dict: [String: Any]) {
        guard let ctx = WatchWire.decode(WatchContext.self, from: dict, key: WatchWire.contextKey) else { return }
        Task { @MainActor in
            WL.lang = ctx.lang
            self.activities = ctx.activities
            self.hasContext = true
        }
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // Pull whatever catalog the phone last published.
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty { Task { @MainActor in self.ingest(ctx) } }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.ingest(applicationContext) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.ingest(message) }
    }
}
