import Foundation

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
