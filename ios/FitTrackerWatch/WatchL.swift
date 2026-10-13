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
