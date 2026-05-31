import SwiftUI

// MARK: - Cardio session logger (running / swimming / cycling / walking)
struct CardioLoggerView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var sport = "running"
    @State private var duration = ""
    @State private var distance = ""
    @State private var avgHR = ""
    @State private var rpe = ""
    @State private var rmssd = ""

    private let sports = ["running", "swimming", "cycling", "walking", "other"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(t("wk.sport").uppercased()).font(.head(18, .bold)).tracking(1).foregroundColor(Theme.txt)
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    Card {
                        FieldRow(label: t("wk.sport")) {
                            PillSelect(options: sports, title: { sportLabel($0) }, selection: $sport)
                        }
                        Spacer().frame(height: 14)
                        HStack(spacing: 12) {
                            FieldRow(label: t("wk.duration")) { InputField(placeholder: "40", text: $duration, keyboard: .numberPad) }
                            FieldRow(label: t("wk.distance")) { InputField(placeholder: "8", text: $distance) }
                        }
                        Spacer().frame(height: 14)
                        HStack(spacing: 12) {
                            FieldRow(label: t("wk.avg_hr")) { InputField(placeholder: "150", text: $avgHR, keyboard: .numberPad) }
                            FieldRow(label: t("wk.rpe")) { InputField(placeholder: "6", text: $rpe, keyboard: .numberPad) }
                        }
                        Spacer().frame(height: 14)
                        FieldRow(label: t("wk.rmssd")) { InputField(placeholder: "—", text: $rmssd) }
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

    private func sportLabel(_ raw: String) -> String {
        Sport(rawValue: raw)?.label ?? raw
    }

    private func save() {
        guard let dur = Int(duration), dur > 0 else { toast.show(t("wk.duration")); return }
        let sp = Sport(rawValue: sport) ?? .running
        let sess = WorkoutSession(
            date: today(), planId: "cardio-\(sport)", planName: sp.label, planColor: sp.color,
            exercises: [], sport: sport, durationMin: dur,
            rpe: Int(rpe), avgHR: Int(avgHR),
            rmssd: rmssd.isEmpty ? nil : pf(rmssd),
            distanceKm: distance.isEmpty ? nil : pf(distance))
        store.sessions.append(sess)
        haptic(.success)
        toast.show(t("save"))
        dismiss()
    }
}
