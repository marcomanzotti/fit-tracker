import SwiftUI

// MARK: - Isometric hold timer (phone)
// Timed exercises used to be logged by typing a number of seconds after the fact,
// which meant either guessing or watching a separate stopwatch. This runs the hold
// for you: a preparation countdown (default 7 s) to get into position, then the
// hold itself, and the seconds actually held are written straight into the set.
//
// With a target it counts DOWN to zero (plank for 45 s); without one it counts UP
// and you stop when you drop. The wrist version lives in FitTrackerWatch and shares
// the idea, not the code — the watch has a digital crown and no room for a header.

/// Which set the sheet is running for, and where its clock starts.
struct HoldTarget: Identifiable {
    let id = UUID()
    let setId: UUID
    let exerciseId: UUID
    let name: String
    /// Seconds to count down from. 0 => free hold (counts up).
    let target: Double
}

struct HoldTimerSheet: View {
    let title: String
    /// Starting target in seconds (0 = free hold).
    let target: Double
    /// Seconds of "get into position" lead-in before the hold starts (0 = skip).
    let prepSeconds: Int
    /// Called with the seconds actually held.
    var onDone: (Double) -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Phase { case idle, prep, holding, done }
    @State private var phase: Phase = .idle
    @State private var editableTarget: Double = 0
    @State private var prepLeft: Double = 0
    @State private var elapsed: Double = 0
    @State private var held: Double = 0

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    /// Free hold once the target has been dialled to zero.
    private var isFree: Bool { editableTarget <= 0 }
    /// Seconds still to hold (countdown mode only).
    private var remaining: Double { max(0, editableTarget - elapsed) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                Spacer(minLength: 0)
                ring
                phaseCaption
                Spacer(minLength: 0)
                if phase == .idle { targetStepper }
                controls
            }
            .padding(.horizontal, 22).padding(.bottom, 26)
        }
        .preferredColorScheme(.dark)
        .onAppear { editableTarget = target.rounded() }
        .onReceive(tick) { _ in step() }
        // The screen must stay awake through a 60 s plank.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("hold.title").uppercased()).font(.head(15, .bold)).tracking(1).foregroundColor(Theme.txt)
                Text(title).font(.system(size: 12)).foregroundColor(Theme.sub).lineLimit(1)
            }
            Spacer()
            Button { tap(); finish(save: false) } label: {
                Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 18)
    }

    // MARK: The dial
    private var ring: some View {
        ZStack {
            Circle().stroke(Theme.c3, lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
            VStack(spacing: 2) {
                Text(bigNumber).font(.num(64)).foregroundColor(ringColor).monospacedDigit()
                Text("SEC").font(.head(11, .semibold)).tracking(3).foregroundColor(Theme.sub)
            }
        }
        .frame(width: 240, height: 240)
    }

    private var progress: CGFloat {
        switch phase {
        case .prep:
            return prepSeconds > 0 ? CGFloat(prepLeft / Double(prepSeconds)) : 0
        case .holding:
            // Countdown drains the ring; a free hold fills it once per minute so
            // there's still visible motion without a fixed end point.
            return isFree ? CGFloat((elapsed.truncatingRemainder(dividingBy: 60)) / 60)
                          : CGFloat(editableTarget > 0 ? remaining / editableTarget : 0)
        case .done:
            return 1
        case .idle:
            return isFree ? 0 : 1
        }
    }

    private var ringColor: Color {
        switch phase {
        case .prep:    return Theme.acc2
        case .holding: return Theme.acc
        case .done:    return Theme.good
        case .idle:    return Theme.acc
        }
    }

    private var bigNumber: String {
        switch phase {
        case .prep:    return "\(Int(prepLeft.rounded(.up)))"
        case .holding: return isFree ? "\(Int(elapsed))" : "\(Int(remaining.rounded(.up)))"
        case .done:    return "\(Int(held.rounded()))"
        case .idle:    return isFree ? "0" : "\(Int(editableTarget))"
        }
    }

    @ViewBuilder private var phaseCaption: some View {
        switch phase {
        case .prep:
            Text(t("hold.get_ready").uppercased()).font(.head(13, .bold)).tracking(2).foregroundColor(Theme.acc2)
        case .holding:
            Text(t("hold.hold_now").uppercased()).font(.head(13, .bold)).tracking(2).foregroundColor(Theme.acc)
        case .done:
            Text(t("hold.done").uppercased()).font(.head(13, .bold)).tracking(2).foregroundColor(Theme.good)
        case .idle:
            Text(isFree ? t("hold.free_hint") : "\(t("hold.prep")) \(prepSeconds)s")
                .font(.system(size: 11)).foregroundColor(Theme.sub)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Target adjustment (before starting only)
    private var targetStepper: some View {
        HStack(spacing: 12) {
            Text(t("hold.target").uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
            Spacer()
            stepButton("minus") { editableTarget = max(0, editableTarget - 5) }
            Text(isFree ? t("hold.free") : "\(Int(editableTarget))s")
                .font(.num(18)).foregroundColor(Theme.txt).frame(minWidth: 62)
            stepButton("plus") { editableTarget += 5 }
        }
    }

    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button { tap(); action() } label: {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.txt)
                .frame(width: 38, height: 38).background(Theme.c3).clipShape(Circle())
        }.buttonStyle(.plain)
    }

    // MARK: Controls
    @ViewBuilder private var controls: some View {
        switch phase {
        case .idle:
            BigButton(title: t("wk.hold_start")) { start() }
        case .prep, .holding:
            Button { tap(); stopHold() } label: {
                Text(t("hold.stop").uppercased()).font(.head(15, .bold)).tracking(2).foregroundColor(Theme.red)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Theme.red.opacity(0.5), lineWidth: 1))
            }.buttonStyle(.plain)
        case .done:
            BigButton(title: t("save"), color: Theme.good) { finish(save: true) }
        }
    }

    // MARK: Clock
    private func start() {
        elapsed = 0
        held = 0
        if prepSeconds > 0 {
            prepLeft = Double(prepSeconds)
            phase = .prep
        } else {
            phase = .holding
            haptic(.success)
        }
    }

    private func step() {
        switch phase {
        case .prep:
            let before = Int(prepLeft.rounded(.up))
            prepLeft = max(0, prepLeft - 0.1)
            let after = Int(prepLeft.rounded(.up))
            if after != before && after > 0 { tap() }     // one tick per second
            if prepLeft <= 0 {
                phase = .holding
                haptic(.success)                          // "go" is unmistakable
            }
        case .holding:
            let before = Int(remaining.rounded(.up))
            elapsed += 0.1
            if !isFree {
                let after = Int(remaining.rounded(.up))
                if after != before && after > 0 && after <= 3 { tap() }
                if remaining <= 0 { stopHold() }
            }
        case .idle, .done:
            break
        }
    }

    /// Stop the hold and record it. Stopping during the preparation phase logs
    /// nothing — the hold never started.
    private func stopHold() {
        guard phase == .prep || phase == .holding else { return }
        if phase == .prep { finish(save: false); return }
        held = max(1, elapsed.rounded())
        phase = .done
        haptic(.success)
    }

    private func finish(save: Bool) {
        if save && held > 0 { onDone(held) }
        dismiss()
    }
}
