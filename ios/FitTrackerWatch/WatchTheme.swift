import Foundation
import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

// MARK: - Watch visual identity
// The phone's palette (Shared/Style.swift), under the short names the watch
// views use, so the wrist looks identical.
enum T {
    static let bg   = Palette.bg
    static let c1   = Palette.c1
    static let c2   = Palette.c2
    static let c3   = Palette.c3
    static let brd  = Palette.c3
    static let acc  = Palette.acc
    static let acc2 = Palette.acc2
    static let txt  = Palette.txt
    static let sub  = Palette.sub
    static let red  = Palette.red
    static let blue = Palette.blue
    static let good = Palette.good
    static let radius: CGFloat = 14
}


func watchIcon(for a: WatchActivity) -> String {
    a.kindValue == .strength ? "dumbbell.fill" : sportSymbol(a.sport)
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
        "restart_q":    ("Ricominciare da zero? Il tempo e le serie di ora si perdono.", "Start over? The time and sets so far are lost."),
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
