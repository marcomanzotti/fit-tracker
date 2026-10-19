import Combine
import SwiftUI

// MARK: - Cardio logger (logs a session for a saved, customizable activity type)
// Mirrors strength days: every cardio activity is a saved CardioType with its own
// name and color. Calories are estimated from the user's global profile (weight,
// age, sex, and avg HR when provided).
struct CardioLoggerView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    let type: CardioType

    @State private var durationSec: Int? = nil
    @State private var distance = ""
    @State private var avgHR = ""
    @State private var calManual = ""
    @State private var paceManual: Double? = nil

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: type.sportType.icon)
                            .font(.system(size: 18, weight: .bold)).foregroundColor(Theme.bg)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: type.color))
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("wk.log_cardio").uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                            Text(type.name.uppercased()).font(.head(18, .bold)).tracking(0.5).foregroundColor(Color(hex: type.color))
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        }
                    }
                    .padding(.top, 18)

                    Card {
                        HMSField(label: t("wk.duration"), seconds: $durationSec)
                        Spacer().frame(height: 14)
                        HStack(alignment: .top, spacing: 12) {
                            FieldRow(label: "\(t("wk.distance")) (\(Units.distLabel))") { InputField(placeholder: "8", text: $distance) }
                            FieldRow(label: t("wk.avg_hr")) { InputField(placeholder: "150", text: $avgHR, keyboard: .numberPad) }
                        }
                        Spacer().frame(height: 14)
                        PaceField(session: buildSession(), manual: $paceManual)
                    }

                    // Live calorie estimate from the user's global data.
                    Card(accent: Theme.acc) {
                        HStack(spacing: 2) {
                            Lbl(text: t("wk.est_calories"), color: Theme.acc2)
                            InfoButton(id: .calories, color: Theme.acc2)
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(calManual.isEmpty ? (estCalories.map { "\($0)" } ?? "—") : calManual)
                                    .font(.num(28)).foregroundColor(Theme.acc)
                                Text("kcal").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                            }
                        }
                        .padding(.bottom, 10)
                        HStack(spacing: 8) {
                            Text(t("wk.cal_override").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                            Spacer()
                            InputField(placeholder: estCalories.map { "\($0)" } ?? "—", text: $calManual, keyboard: .numberPad)
                                .frame(width: 110)
                        }
                        Text(t("wk.est_cal_hint")).font(.system(size: 10)).foregroundColor(Theme.sub).padding(.top, 6)
                    }

                    BigButton(title: t("save")) { save() }
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
    }

    private func buildSession() -> WorkoutSession {
        WorkoutSession(
            date: today(), planId: "cardio-\(type.id)", planName: type.name, planColor: type.color,
            exercises: [], sport: type.sport, durationSec: durationSec,
            avgHR: Int(avgHR),
            distanceKm: distance.isEmpty ? nil : Units.distIn(pf(distance)),
            paceManual: paceManual,
            caloriesManual: Int(calManual).flatMap { $0 > 0 ? $0 : nil })
    }

    private var estCalories: Int? {
        guard let dur = durationSec, dur > 0 else { return nil }
        return store.estimateCalories(buildSession())
    }

    private func save() {
        guard let dur = durationSec, dur > 0 else { toast.show(t("wk.duration")); return }
        let session = buildSession()
        store.saveSession(session)
        if store.prefs.exportsToHealth {
            store.exportToHealth(session) { [toast] ok in toast.show(t(ok ? "hk.exported" : "hk.export_failed")) }
        }
        haptic(.success)
        toast.show(t("save"))
        dismiss()
    }
}

// MARK: - Cardio type editor (create / edit / delete a saved activity)
struct CardioTypeEditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State var type: CardioType
    let isNew: Bool
    @State private var confirmDelete = false

    private let sportKinds = ["running", "swimming", "cycling", "walking", "other"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text((isNew ? t("wk.new_cardio") : t("wk.edit_cardio")).uppercased())
                            .font(.head(18, .bold)).tracking(0.5).foregroundColor(Color(hex: type.color))
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub).frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        }
                    }
                    .padding(.top, 18)

                    Card {
                        Lbl(text: t("wk.activity_name")).padding(.bottom, 8)
                        InputField(placeholder: t("wk.activity_name_ph"), text: $type.name, keyboard: .default)
                            .onChange(of: type.name) { _, v in
                                let tc = titleCased(v)
                                if tc != v { type.name = tc }
                            }
                            .padding(.bottom, 14)
                        Lbl(text: t("wk.activity_sub")).padding(.bottom, 8)
                        InputField(placeholder: t("wk.activity_sub_ph"),
                                   text: Binding(get: { type.sub ?? "" }, set: { type.sub = $0 }),
                                   keyboard: .default)
                            .padding(.bottom, 14)
                        Lbl(text: t("wk.cardio_kind")).padding(.bottom, 8)
                        PillSelect(options: sportKinds, title: { Sport(rawValue: $0)?.label ?? $0 }, selection: $type.sport)
                            .padding(.bottom, 14)
                        Lbl(text: t("pe.color")).padding(.bottom, 8)
                        FlexWrap(Theme.sportColors, spacing: 10) { c in
                            Circle().fill(Color(hex: c))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Theme.txt, lineWidth: type.color == c ? 2 : 0))
                                .onTapGesture { tap(); type.color = c }
                        }
                    }

                    BigButton(title: isNew ? t("add") : t("save")) { save() }

                    if !isNew {
                        Button { tap(); confirmDelete = true } label: {
                            Text(t("delete")).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.red.opacity(0.4), lineWidth: 1))
                        }
                        .confirmationDialog(t("wk.delete_cardio_q"), isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button(t("delete"), role: .destructive) {
                                if let removed = store.deleteCardioType(type.id) {
                                    toast.showUndo(t("wk.cardio_deleted")) { [store] in store.restoreCardioType(removed) }
                                }
                                dismiss()
                            }
                            Button(t("cancel"), role: .cancel) {}
                        }
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
    }

    private func save() {
        var ct = type
        if ct.name.trimmingCharacters(in: .whitespaces).isEmpty {
            ct.name = Sport(rawValue: ct.sport)?.label ?? t("wk.cardio")
        }
        store.commitCardioType(ct)
        toast.show(t("wk.cardio_saved"))
        dismiss()
    }
}

// MARK: - Live cardio session (real running tracker, mirrors LiveWorkoutView)
// Starting a cardio activity opens this full live screen: a running clock,
// GPS-tracked distance + live pace/speed for outdoor sports, live HR + calories
// from a paired watch when present, and pause/resume. Ending builds a real
// WorkoutSession with everything tracked — cardio is a first-class session, not
// a manual after-the-fact form.
struct LiveCardioView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @EnvironmentObject var activeCardio: ActiveCardio
    @ObservedObject private var watch = WatchSync.shared

    let type: CardioType
    let onBack: () -> Void      // minimize, keep running
    let onSaved: () -> Void     // finish / discard ends it

    @State private var confirmDiscard = false
    // Only redraws the clock: the time itself is kept by ActiveCardio from dates,
    // so it is right whether or not this screen was showing.
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var accent: Color { Color(hex: type.color) }
    private var isWatchLive: Bool { watch.liveActive && watch.live?.activityId == activeCardio.activityId }
    private var liveSample: WatchLiveSample? { isWatchLive ? watch.live : nil }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    clockCard
                    metricsCard
                    caloriesCard
                    controls
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18).padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(tick) { now = $0 }
    }

    private var elapsed: Int { activeCardio.elapsedSec(at: now) }
    private var distanceKm: Double? { activeCardio.distanceKm(live: liveSample) }
    private var liveHR: Int? {
        guard let hr = liveSample?.hr, hr > 0 else { return nil }
        return hr
    }
    /// Measured by the watch when there is one, else estimated from the data so far.
    private var liveKcal: Int? { session.caloriesManual ?? estCalories }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: type.sportType.icon)
                .font(.system(size: 18, weight: .bold)).foregroundColor(Theme.bg)
                .frame(width: 44, height: 44).background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t("wk.live").uppercased()).font(.head(10, .semibold)).tracking(1.5).foregroundColor(Theme.sub)
                    if isWatchLive {
                        Image(systemName: "applewatch").font(.system(size: 10)).foregroundColor(Theme.good)
                    }
                }
                Text(type.name.uppercased()).font(.head(20, .bold)).tracking(0.5).foregroundColor(accent).lineLimit(1)
            }
            Spacer()
            // Minimize — keep running in the background, return to the app.
            Button { tap(); onBack() } label: {
                Image(systemName: "chevron.down").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 10)
    }

    private var clockCard: some View {
        Card(accent: accent) {
            VStack(spacing: 4) {
                Text(t("wk.duration").uppercased()).font(.head(10, .semibold)).tracking(2).foregroundColor(Theme.sub)
                Text(fmtClock(elapsed)).font(.num(46)).foregroundColor(Theme.txt).monospacedDigit()
                if activeCardio.paused {
                    Text(t("wk.paused").uppercased()).font(.head(10, .bold)).tracking(2).foregroundColor(Theme.acc2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var metricsCard: some View {
        Card {
            HStack(spacing: 10) {
                liveTile(label: t("wk.distance"), value: distanceKm.map { dispDist($0) } ?? "—",
                         unit: Units.distLabel, color: accent)
                liveTile(label: t("wk.speed_pace"), value: paceValue, unit: paceUnit, color: Theme.acc2)
                liveTile(label: t("wk.avg_hr"), value: liveHR.map { "\($0)" } ?? "—",
                         unit: liveHR != nil ? "bpm" : nil, color: Theme.red)
            }
            if activeCardio.usesGPS && !activeCardio.gpsAuthorized {
                Text(t("wk.gps_hint")).font(.system(size: 10)).foregroundColor(Theme.sub)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
            }
        }
    }

    private func liveTile(label: String, value: String, unit: String?, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(label.uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.num(22)).foregroundColor(color)
                if let unit { Text(unit).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }

    private var caloriesCard: some View {
        Card(accent: Theme.acc) {
            HStack(spacing: 2) {
                Lbl(text: t("wk.est_calories"), color: Theme.acc2)
                InfoButton(id: .calories, color: Theme.acc2)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(liveKcal.map { "\($0)" } ?? "—").font(.num(28)).foregroundColor(Theme.acc)
                    Text("kcal").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            // Pause / resume
            Button { tap(); activeCardio.togglePause() } label: {
                HStack(spacing: 8) {
                    Image(systemName: activeCardio.paused ? "play.fill" : "pause.fill").font(.system(size: 15, weight: .bold))
                    Text((activeCardio.paused ? t("wk.resume") : t("wk.pause")).uppercased())
                        .font(.head(13, .semibold)).tracking(1)
                }
                .foregroundColor(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.acc2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            }
            .buttonStyle(PressableStyle())

            // Finish → save the session.
            Button { tap(); finish() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                    Text(t("wk.finish").uppercased()).font(.head(13, .semibold)).tracking(1)
                }
                .foregroundColor(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Button { tap(); confirmDiscard = true } label: {
                Text(t("wk.discard_session")).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.red)
            }
            .buttonStyle(PressableStyle())
            .offset(y: 40)
        }
        .padding(.bottom, 40)
        .confirmationDialog(t("wk.discard_q"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(t("wk.discard_session"), role: .destructive) { discard() }
            Button(t("cancel"), role: .cancel) {}
        }
    }

    // MARK: Pace/speed display in the sport's native unit.
    private var paceUnit: String { session.paceUnit }
    private var paceValue: String {
        let s = session
        guard let p = s.effectivePace, p > 0, p.isFinite else { return "—" }
        if s.paceIsSpeed { return trimNum((p * 10).rounded() / 10) }   // km/h
        return paceStr(p)                                             // min/km or /100m
    }

    private var estCalories: Int? {
        let s = session
        guard (s.durationSeconds ?? 0) > 0 else { return nil }
        return store.estimateCalories(s)
    }

    /// The session as it stands now. Before any time has been recorded there is
    /// nothing to save yet, so an empty stand-in feeds the pace and calorie labels.
    private var session: WorkoutSession {
        activeCardio.finishedSession(live: liveSample)
            ?? WorkoutSession(date: today(), planId: activeCardio.activityId ?? "", planName: type.name,
                              planColor: type.color, exercises: [], sport: type.sport)
    }

    private func finish() {
        guard var s = activeCardio.finishedSession(live: liveSample) else { discard(); return }
        // The watch's measured energy is already on the session; else the estimate.
        if s.caloriesManual == nil, let k = estCalories, k > 0 { s.caloriesManual = k }
        store.saveSession(s)
        store.flushNow()            // before the draft is removed
        // To Health with its GPS track, when the user opted in. A session the
        // paired watch recorded is already there (it carries its UUID).
        if store.prefs.exportsToHealth {
            store.exportToHealth(s, route: activeCardio.route) { [toast] ok in
                toast.show(t(ok ? "hk.exported" : "hk.export_failed"))
            }
        }
        haptic(.success)
        toast.show(t("wk.session_saved"))
        onSaved()
    }

    private func discard() { onSaved() }
}
