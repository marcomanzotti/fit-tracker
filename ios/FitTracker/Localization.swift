import Foundation

// MARK: - Lightweight runtime localization (IT / EN)
// The user can switch language at any time. `L.lang` is kept in sync with
// prefs.language by the Store; because views observe the Store, flipping the
// language re-renders the whole tree and every L.t(...) call returns the new
// string. Free helper functions (month names, etc.) read L.lang directly.

enum L {
    static var lang: String = "it"   // "it" | "en"

    /// Raw localized string for the current language (no formatting).
    static func t(_ key: String) -> String {
        let entry = table[key]
        return (lang == "en" ? entry?.en : entry?.it) ?? entry?.it ?? key
    }

    // Localized month / weekday abbreviations.
    static var months: [String] {
        lang == "en"
            ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            : ["Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic"]
    }
    static var days: [String] {
        lang == "en"
            ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            : ["Dom", "Lun", "Mar", "Mer", "Gio", "Ven", "Sab"]
    }
    /// Monday-first weekday headers for the calendar grid.
    static var weekHeaders: [String] {
        lang == "en"
            ? ["M", "T", "W", "T", "F", "S", "S"]
            : ["L", "M", "M", "G", "V", "S", "D"]
    }

    typealias E = (it: String, en: String)
    static let table: [String: E] = [
        // --- Common ---------------------------------------------------------
        "save":        ("Salva", "Save"),
        "cancel":      ("Annulla", "Cancel"),
        "delete":      ("Elimina", "Delete"),
        "edit":        ("Modifica", "Edit"),
        "done":        ("Fatto", "Done"),
        "add":         ("Aggiungi", "Add"),
        "close":       ("Chiudi", "Close"),
        "next":        ("Avanti", "Next"),
        "back":        ("Indietro", "Back"),
        "start":       ("Inizia", "Start"),
        "finish":      ("Termina", "Finish"),
        "today":       ("Oggi", "Today"),
        "optional":    ("opzionale", "optional"),
        "none":        ("Nessuno", "None"),
        "kg":          ("kg", "kg"),
        "confirm_delete": ("Confermi l'eliminazione?", "Confirm deletion?"),

        // --- Navigation -----------------------------------------------------
        "nav.home":    ("Home", "Home"),
        "nav.train":   ("Allena", "Train"),
        "nav.body":    ("Corpo", "Body"),
        "nav.stats":   ("Stats", "Stats"),
        "sub.home":    ("Dashboard", "Dashboard"),
        "sub.train":   ("Log allenamento", "Workout log"),
        "sub.body":    ("Misurazioni & Check-in", "Measurements & Check-in"),
        "sub.stats":   ("Statistiche", "Statistics"),

        // --- Home -----------------------------------------------------------
        "home.checkin":      ("Check-in di oggi", "Today's check-in"),
        "home.weight":       ("Peso", "Weight"),
        "home.sleep":        ("Sonno", "Sleep"),
        "home.sleep_score":  ("Punteggio sonno", "Sleep score"),
        "home.save_checkin": ("Salva check-in", "Save check-in"),
        "home.streak":       ("Striscia", "Streak"),
        "home.days":         ("giorni", "days"),
        "home.bmi":          ("BMI", "BMI"),
        "home.goal_weight":  ("Obiettivo peso", "Weight goal"),
        "home.goal_bf":      ("Obiettivo grasso", "Body-fat goal"),
        "home.next_workout": ("Prossimo allenamento", "Next workout"),
        "home.weight_14":    ("Peso ultimi 14 giorni", "Weight last 14 days"),
        "home.recent_pr":    ("Record recenti", "Recent PRs"),
        "home.week_cmp":     ("Confronto settimanale", "Weekly comparison"),
        "home.backup":       ("Backup dati", "Data backup"),
        "home.export":       ("Esporta JSON", "Export JSON"),
        "home.import":       ("Importa JSON", "Import JSON"),

        // --- Readiness / load (Home + Stats) --------------------------------
        "load.readiness":    ("Prontezza (HRV)", "Readiness (HRV)"),
        "load.ready":        ("Pronto: puoi spingere", "Ready: you can push"),
        "load.easy":         ("Vai leggero oggi", "Go easy today"),
        "load.rest":         ("Meglio recuperare", "Better to rest"),
        "load.need_data":    ("Inserisci l'RMSSD per qualche giorno", "Log RMSSD for a few days"),
        "load.acwr":         ("Carico acuto/cronico (ACWR)", "Acute:chronic load (ACWR)"),
        "load.acwr_low":     ("Carico basso: rischio detraining", "Low load: detraining risk"),
        "load.acwr_ok":      ("Zona ottimale", "Sweet spot"),
        "load.acwr_high":    ("Carico alto: rischio infortunio", "High load: injury risk"),
        "load.monotony":     ("Monotonia", "Monotony"),
        "load.strain":       ("Strain", "Strain"),
        "load.weekly":       ("Carico settimanale", "Weekly load"),
        "load.deload":       ("Valuta una settimana di scarico", "Consider a deload week"),
        "load.title":        ("Carico interno", "Internal load"),
        "load.srpe":         ("sRPE (durata × RPE)", "sRPE (duration × RPE)"),
        "load.trimp":        ("TRIMP", "TRIMP"),

        // --- Nutrition ------------------------------------------------------
        "nut.title":         ("Nutrizione", "Nutrition"),
        "nut.mode":          ("Modalità energetica", "Energy mode"),
        "nut.cut":           ("Definizione", "Cut"),
        "nut.maintain":      ("Mantenimento", "Maintenance"),
        "nut.bulk":          ("Massa", "Bulk"),
        "nut.target":        ("Calorie obiettivo", "Calorie target"),
        "nut.tdee":          ("TDEE", "TDEE"),
        "nut.bmr":           ("Metabolismo basale", "Basal metabolism"),
        "nut.protein":       ("Proteine", "Protein"),
        "nut.carbs":         ("Carboidrati", "Carbs"),
        "nut.fat":           ("Grassi", "Fat"),
        "nut.salt":          ("Sale (max)", "Salt (max)"),
        "nut.carb_high":     ("Carbo giorno ON", "Carbs training day"),
        "nut.carb_low":      ("Carbo giorno OFF", "Carbs rest day"),
        "nut.rate_target":   ("Variazione obiettivo", "Target change"),
        "nut.per_week":      ("kg/sett", "kg/wk"),
        "nut.trend":         ("Trend peso reale", "Real weight trend"),
        "nut.trend_ok":      ("In linea con l'obiettivo", "On target"),
        "nut.trend_fast":    ("Troppo veloce", "Too fast"),
        "nut.trend_slow":    ("Troppo lento", "Too slow"),
        "nut.trend_wrong":   ("Direzione sbagliata", "Wrong direction"),
        "nut.adjust":        ("Aggiusta di %d kcal", "Adjust by %d kcal"),
        "nut.lea":           ("Disponibilità energetica", "Energy availability"),
        "nut.lea_risk":      ("Rischio bassa disponibilità energetica", "Low energy availability risk"),
        "nut.lea_warn":      ("Disponibilità energetica bassa sotto carico", "Low energy availability under load"),
        "nut.intake_today":  ("Assunzione di oggi", "Today's intake"),
        "nut.who_note":      ("Range basati su linee guida WHO / ISSN", "Ranges based on WHO / ISSN guidance"),

        // --- Workout / methods / sports ------------------------------------
        "wk.live":           ("Allenamento live", "Live workout"),
        "wk.add_ex":         ("Aggiungi esercizio", "Add exercise"),
        "wk.set":            ("Serie", "Set"),
        "wk.reps":           ("Rip", "Reps"),
        "wk.suggested":      ("Suggerito", "Suggested"),
        "wk.last_time":      ("Ultima volta", "Last time"),
        "wk.notes":          ("Note", "Notes"),
        "wk.rpe":            ("RPE sessione", "Session RPE"),
        "wk.duration":       ("Durata (min)", "Duration (min)"),
        "wk.avg_hr":         ("FC media", "Avg HR"),
        "wk.rmssd":          ("RMSSD", "RMSSD"),
        "wk.superset":       ("Superset", "Superset"),
        "wk.method":         ("Metodo", "Method"),
        "wk.sport":          ("Sport", "Sport"),
        "wk.distance":       ("Distanza (km)", "Distance (km)"),
        "wk.pace":           ("Ritmo", "Pace"),
        "wk.finish_ask":     ("Terminare e salvare la sessione?", "Finish and save the session?"),
        "wk.edit_session":   ("Modifica sessione", "Edit session"),
        "wk.del_session":    ("Elimina sessione", "Delete session"),
        "wk.add_reps":       ("Aumenta le ripetizioni", "Add reps"),
        "wk.add_load":       ("Aumenta il carico", "Add load"),
        "wk.hold":           ("Mantieni il carico", "Hold the load"),
        "wk.deload_ex":      ("Scarica / tecnica", "Deload / technique"),

        // --- Calendar -------------------------------------------------------
        "cal.title":         ("Calendario", "Calendar"),
        "cal.no_sessions":   ("Nessuna sessione questo mese", "No sessions this month"),

        // --- Stats tabs -----------------------------------------------------
        "st.overview":       ("Panoramica", "Overview"),
        "st.records":        ("Record", "Records"),
        "st.progress":       ("Progressi", "Progress"),
        "st.history":        ("Storico", "History"),
        "st.profile":        ("Profilo", "Profile"),

        // --- Onboarding -----------------------------------------------------
        "ob.welcome":        ("Benvenuto", "Welcome"),
        "ob.intro":          ("Configura il tuo profilo per personalizzare obiettivi, calorie e carichi.",
                              "Set up your profile to personalize goals, calories and load."),
        "ob.language":       ("Lingua", "Language"),
        "ob.sex":            ("Sesso", "Sex"),
        "ob.male":           ("Uomo", "Male"),
        "ob.female":         ("Donna", "Female"),
        "ob.birth":          ("Data di nascita", "Date of birth"),
        "ob.height":         ("Altezza (cm)", "Height (cm)"),
        "ob.weight":         ("Peso attuale (kg)", "Current weight (kg)"),
        "ob.goal_weight":    ("Peso obiettivo (kg)", "Goal weight (kg)"),
        "ob.goal_mode":      ("Obiettivo", "Goal"),
        "ob.rate":           ("Ritmo (kg/sett)", "Rate (kg/wk)"),
        "ob.activity":       ("Livello di attività", "Activity level"),
        "ob.act_sed":        ("Sedentario", "Sedentary"),
        "ob.act_light":      ("Leggero", "Light"),
        "ob.act_mod":        ("Moderato", "Moderate"),
        "ob.act_high":       ("Alto", "High"),
        "ob.act_athlete":    ("Atleta", "Athlete"),
        "ob.train_days":     ("Giorni di allenamento", "Training days/week"),
        "ob.rest_hr":        ("FC a riposo", "Resting HR"),
        "ob.max_hr":         ("FC max (opzionale)", "Max HR (optional)"),
        "ob.finish":         ("Inizia ad allenarti", "Start training"),

        // --- Settings / profile --------------------------------------------
        "set.title":         ("Impostazioni", "Settings"),
        "set.profile":       ("Profilo & obiettivi", "Profile & goals"),
        "set.language":      ("Lingua", "Language"),
        "set.sleep_track":   ("Traccia il sonno", "Track sleep"),
        "set.timer":         ("Timer recupero (s)", "Rest timer (s)"),
        "set.edit_profile":  ("Modifica profilo", "Edit profile"),
    ]
}

// Convenience: t("key") as a free function for brevity in views, with optional
// printf-style arguments (e.g. t("nut.adjust", 150)).
func t(_ key: String, _ args: CVarArg...) -> String {
    let s = L.t(key)
    return args.isEmpty ? s : String(format: s, arguments: args)
}
