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
    /// Set when the phone asks the wrist to start an activity (its id). The root
    /// view observes this and launches the matching workout.
    @Published var startRequest: String?

    func activate() {
        guard WCSession.isSupported() else {
            print("⌚️ WatchLink: WCSession not supported")
            return
        }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        print("⌚️ WatchLink: activate() called")
    }

    func send(_ result: WatchResult) {
        guard WCSession.isSupported() else { return }
        let payload = WatchWire.encode(result, key: WatchWire.resultKey)
        guard !payload.isEmpty else { return }
        let s = WCSession.default
        s.transferUserInfo(payload)                 // reliable, queued
        if s.isReachable { s.sendMessage(payload, replyHandler: nil, errorHandler: nil) }
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

    fileprivate func ingest(_ dict: [String: Any]) {
        guard let ctx = WatchWire.decode(WatchContext.self, from: dict, key: WatchWire.contextKey) else {
            print("⌚️ WatchLink: ingest() failed to decode context, keys=\(dict.keys)")
            return
        }
        print("⌚️ WatchLink: ingest() got \(ctx.activities.count) activities, lang=\(ctx.lang)")
        Task { @MainActor in
            WL.lang = ctx.lang
            self.activities = ctx.activities
            self.hasContext = true
        }
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        print("⌚️ WatchLink: activationDidCompleteWith state=\(state.rawValue) error=\(String(describing: error))")
        // Pull whatever catalog the phone last published.
        let ctx = session.receivedApplicationContext
        print("⌚️ WatchLink: receivedApplicationContext isEmpty=\(ctx.isEmpty)")
        if !ctx.isEmpty { Task { @MainActor in self.ingest(ctx) } }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("⌚️ WatchLink: didReceiveApplicationContext")
        Task { @MainActor in self.ingest(applicationContext) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // A "start this activity" command from the phone arrives as a plain string.
        if let actId = message[WatchWire.startKey] as? String {
            Task { @MainActor in self.startRequest = actId }
            return
        }
        Task { @MainActor in self.ingest(message) }
    }
}
