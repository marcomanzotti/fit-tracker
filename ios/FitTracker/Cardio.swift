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
    @State private var rmssd = ""
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
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
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
                        Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 13)
                        HStack(spacing: 7) {
                            Text(t("load.recommended").uppercased()).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
                            Badge(text: t("load.sensor"), color: Theme.blue, bg: Theme.blue.opacity(0.12))
                            Spacer()
                        }
                        .padding(.bottom, 9)
                        FieldRow(label: t("wk.rmssd")) { InputField(placeholder: "—", text: $rmssd) }
                    }

                    // Live calorie estimate from the user's global data.
                    Card(accent: Theme.acc) {
                        HStack(spacing: 2) {
                            Lbl(text: t("wk.est_calories"), color: Theme.acc2)
                            InfoButton(id: "calories", color: Theme.acc2)
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(calManual.isEmpty ? (estCalories.map { "\($0)" } ?? "—") : calManual)
                                    .font(.num(28)).foregroundColor(Theme.acc)
                                Text("kcal").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                            }
                        }
                        .padding(.bottom, 10)
                        HStack(spacing: 8) {
                            Text(t("wk.cal_override").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
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
    }

    private func buildSession() -> WorkoutSession {
        WorkoutSession(
            date: today(), planId: "cardio-\(type.id)", planName: type.name, planColor: type.color,
            exercises: [], sport: type.sport, durationSec: durationSec,
            avgHR: Int(avgHR),
            rmssd: rmssd.isEmpty ? nil : pf(rmssd),
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
        store.sessions.append(buildSession())
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
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    Card {
                        Lbl(text: t("wk.activity_name")).padding(.bottom, 8)
                        InputField(placeholder: t("wk.activity_name_ph"), text: $type.name, keyboard: .default)
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
                            Button(t("delete"), role: .destructive) { store.deleteCardioType(type.id); toast.show(t("wk.cardio_deleted")); dismiss() }
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
