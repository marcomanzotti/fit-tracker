import Foundation
import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

// MARK: - Watch visual identity
// A self-contained copy of the phone app's palette and font helpers so the wrist
// looks identical (dark surfaces, Lamborghini-bright yellow accent, rounded stat
// numbers). The phone's Theme/Components import UIKit and can't be shared with
// watchOS, so the small subset the watch needs is mirrored here.

enum T {
    static let bg   = Color(hex: "0b0b0d")
    static let c1   = Color(hex: "141417")
    static let c2   = Color(hex: "1f1f23")
    static let c3   = Color(hex: "2a2a30")
    static let brd  = Color(hex: "2a2a30")
    static let acc  = Color(hex: "ffe000")
    static let acc2 = Color(hex: "ffb000")
    static let txt  = Color(hex: "f4efe6")
    static let sub  = Color(hex: "9a958d")
    static let red  = Color(hex: "ff5a52")
    static let blue = Color(hex: "4fb8c4")
    static let good = Color(hex: "7fc950")
    static let radius: CGFloat = 14
}

// MARK: - SF Symbol per sport (mirrors the phone's Sport.icon)
func sportIcon(_ sport: String?) -> String {
    switch sport {
    case "running":  return "figure.run"
    case "swimming": return "figure.pool.swim"
    case "cycling":  return "figure.outdoor.cycle"
    case "walking":  return "figure.walk"
    case "other":    return "bolt.heart.fill"
    default:         return "dumbbell.fill"   // strength / unknown
    }
}

func watchIcon(for a: WatchActivity) -> String {
    a.kindValue == .strength ? "dumbbell.fill" : sportIcon(a.sport)
}

// MARK: - Haptics
func wkTap() {
    #if canImport(WatchKit)
    WKInterfaceDevice.current().play(.click)
    #endif
}
func wkSuccess() {
    #if canImport(WatchKit)
    WKInterfaceDevice.current().play(.success)
    #endif
}

// MARK: - Small date helper (yyyy-MM-dd, matches the phone)
let wkISO: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()
func wkToday() -> String { wkISO.string(from: Date()) }

func wkClock(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

// MARK: - Number parsing / formatting (for strength logging)
/// First number in a string like "8-10" or "12" -> 8 / 12.
func firstNumber(_ s: String) -> Double? {
    var out = ""
    for ch in s { if ch.isNumber || ch == "." || ch == "," { out.append(ch) } else if !out.isEmpty { break } }
    return parsedNumber(out)
}
/// Compact numeric string: integer when whole, else one decimal.
func fmtNum(_ v: Double) -> String { trimNum((v * 10).rounded() / 10) }

// MARK: - Minimal IT/EN strings for the watch
// The watch shows only a handful of words; rather than ship the phone's whole
// table we keep a tiny one here. The current language is pushed from the phone
// in the WatchContext (falling back to the device language).
enum WL {
    static var lang: String = Locale.preferredLanguages.first?.hasPrefix("it") == true ? "it" : "en"

    static func t(_ key: String) -> String {
        let e = table[key]
        return (lang == "en" ? e?.en : e?.it) ?? e?.it ?? key
    }

    typealias E = (it: String, en: String)
    static let table: [String: E] = [
        "title":        ("FIT TRACKER", "FIT TRACKER"),
        "strength":     ("Forza", "Strength"),
        "cardio":       ("Cardio", "Cardio"),
        "choose":       ("Scegli l'allenamento", "Choose your workout"),
        "no_act":       ("Apri l'app sull'iPhone per sincronizzare i tuoi allenamenti.",
                         "Open the iPhone app to sync your workouts."),
        "waiting":      ("In attesa dell'iPhone…", "Waiting for iPhone…"),
        "start":        ("Inizia", "Start"),
        "pause":        ("Pausa", "Pause"),
        "resume":       ("Riprendi", "Resume"),
        "end":          ("Termina", "End"),
        "save":         ("Salva", "Save"),
        "saved":        ("Inviato all'iPhone", "Sent to iPhone"),
        "discard":      ("Scarta", "Discard"),
        "summary":      ("Riepilogo", "Summary"),
        "hr":           ("FC", "HR"),
        "bpm":          ("bpm", "bpm"),
        "cal":          ("Calorie", "Calories"),
        "kcal":         ("kcal", "kcal"),
        "dist":         ("Distanza", "Distance"),
        "km":           ("km", "km"),
        "time":         ("Tempo", "Time"),
        "avg":          ("Media", "Avg"),
        "max":          ("Max", "Max"),
        "auth_needed":  ("Consenti l'accesso a Salute per tracciare l'allenamento.",
                         "Allow Health access to track the workout."),
        "preparing":    ("Preparazione…", "Preparing…"),
        "lock":         ("Blocca", "Lock"),
        "unlock":       ("Sblocca", "Unlock"),
        "swipe_unlock": ("Scorri per sbloccare", "Swipe to unlock"),
        "restart":      ("Ricomincia", "Restart"),
        "reps":         ("Rip", "Reps"),
        "weight":       ("Peso", "Weight"),
        "set":          ("Serie", "Set"),
        "done":         ("Fatto", "Done"),
        "controls":     ("Controlli", "Controls"),
        "stop":         ("Stop", "Stop"),
        "hold":         ("Tieni", "Hold"),
        "sec":          ("sec", "sec"),
        "ok":           ("OK", "OK"),
        "cancel":       ("Annulla", "Cancel"),
        "end_q":        ("Terminare l'allenamento?", "End the workout?"),
        "queued":       ("In coda: arriva all'iPhone appena è raggiungibile",
                         "Queued: reaches the iPhone as soon as it is in range"),
        "send_failed":  ("Invio non riuscito. Riprovo alla prossima apertura.",
                         "Sending failed. It will be retried next time the app opens."),
        "no_result":    ("Allenamento terminato senza dati da inviare", "Workout ended with nothing to send"),
        "health_failed": ("Non salvato in Salute", "Not saved to Health"),
        "err_health":   ("Salute non è disponibile su questo orologio", "Health isn't available on this watch"),
        "err_auth":     ("Accesso a Salute negato. Abilitalo in Impostazioni › Salute.",
                         "Health access denied. Turn it on in Settings › Health."),
        "err_start":    ("Impossibile avviare l'allenamento. Riprova.", "Couldn't start the workout. Try again."),

        // Sport labels (match the phone's sport.* keys)
        "sport.strength": ("Forza", "Strength"),
        "sport.running":  ("Corsa", "Running"),
        "sport.swimming": ("Nuoto", "Swimming"),
        "sport.cycling":  ("Bici", "Cycling"),
        "sport.walking":  ("Camminata", "Walking"),
        "sport.other":    ("Altro", "Other")
    ]
}

func wt(_ key: String) -> String { WL.t(key) }
