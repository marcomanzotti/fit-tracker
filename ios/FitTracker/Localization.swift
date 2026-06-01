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
        "home.week_activity": ("Attività settimana", "This week"),
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
        "ob.act_sed_d":      ("Lavoro d'ufficio, nessun allenamento (×1.2)", "Desk job, no training (×1.2)"),
        "ob.act_light_d":    ("1-2 allenamenti a settimana (×1.375)", "1-2 workouts per week (×1.375)"),
        "ob.act_mod_d":      ("3-4 allenamenti a settimana (×1.55)", "3-4 workouts per week (×1.55)"),
        "ob.act_high_d":     ("5-6 allenamenti a settimana (×1.725)", "5-6 workouts per week (×1.725)"),
        "ob.act_athlete_d":  ("6-7 + lavoro fisico o doppie sedute (×1.9)", "6-7 + physical job or 2x/day (×1.9)"),
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

        // --- Home (legacy) --------------------------------------------------
        "home.day":          ("giorno", "day"),
        "home.sessions":     ("Sessioni", "Sessions"),
        "home.total":        ("totali", "total"),
        "home.goals":        ("Obiettivi", "Goals"),
        "home.fat":          ("Grasso", "Body fat"),
        "home.exercises":    ("esercizi", "exercises"),
        "home.week_cmp_title": ("Confronto settimane", "Weekly comparison"),
        "home.avg_weight":   ("Peso medio", "Avg weight"),
        "home.workouts":     ("Allenamenti", "Workouts"),
        "home.total_volume": ("Volume totale", "Total volume"),
        "home.prev":         ("prec.", "prev"),
        "home.lifetime":     ("lifetime", "lifetime"),
        "home.backup_auto":  ("Salvataggio automatico locale", "Automatic local save"),
        "home.export_data":  ("Esporta dati", "Export data"),
        "home.checkin_done": ("Check-in completato", "Check-in done"),
        "home.checkin_saved":("Check-in salvato", "Check-in saved"),
        "home.weight14":     ("Peso · ultimi 14 giorni", "Weight · last 14 days"),

        // --- Body (legacy) --------------------------------------------------
        "body.analysis":     ("Analisi corporea", "Body analysis"),
        "body.fat":          ("Grasso", "Fat"),
        "body.lean":         ("Magra", "Lean"),
        "body.goal":         ("goal", "goal"),
        "body.fat_input":    ("Grasso % · manuale o Navy (collo + vita)", "Body fat % · manual or Navy (neck + waist)"),
        "body.measures":     ("Misurazioni settimanali", "Weekly measurements"),
        "body.save_measures":("Salva misurazioni", "Save measurements"),
        "body.no_data":      ("Nessun dato", "No data"),
        "body.stable":       ("stabile", "stable"),
        "body.all_measures": ("Tutte le misurazioni", "All measurements"),
        "body.measures_saved":("Misurazioni salvate", "Measurements saved"),
        "body.fat_saved":    ("Grasso % salvato", "Body fat % saved"),
        "body.neck":         ("collo", "neck"),
        "body.waist":        ("vita", "waist"),
        "body.imported":     ("Dati importati", "Data imported"),
        "body.invalid_file": ("File non valido", "Invalid file"),
        "body.import_cancelled": ("Importazione annullata", "Import cancelled"),
        "meas.waist":        ("Vita", "Waist"),
        "meas.chest":        ("Petto", "Chest"),
        "meas.arms":         ("Braccia", "Arms"),
        "meas.legs":         ("Gambe", "Legs"),
        "meas.neck":         ("Collo", "Neck"),
        "meas.hips":         ("Fianchi", "Hips"),

        // --- Workout grid (legacy) ------------------------------------------
        "wk.select_day":     ("Seleziona giorno", "Select day"),
        "wk.new_day":        ("Nuovo giorno", "New day"),
        "wk.edit_day":       ("Modifica giorno", "Edit day"),
        "wk.day":            ("Giorno", "Day"),
        "wk.create_day":     ("Crea giorno", "Create day"),
        "wk.recent":         ("Sessioni recenti", "Recent sessions"),
        "wk.sets_n":         ("serie", "sets"),
        "wk.exercises_n":    ("esercizi", "exercises"),
        "wk.day_created":    ("Giorno creato", "Day created"),
        "wk.day_updated":    ("Giorno aggiornato", "Day updated"),
        "wk.day_deleted":    ("Giorno eliminato", "Day deleted"),

        // --- Live workout (legacy) ------------------------------------------
        "wk.saved":          ("Salvata", "Saved"),
        "wk.save_session":   ("Salva sessione", "Save session"),
        "wk.last":           ("Ultima", "Last"),
        "wk.others":         ("altri", "others"),
        "wk.last_time_label":("Ultima volta", "Last time"),
        "wk.try":            ("Prova", "Try"),
        "wk.add_set":        ("+ Serie", "+ Set"),
        "wk.timer":          ("Timer", "Timer"),
        "wk.vol":            ("Vol", "Vol"),
        "wk.max":            ("Max", "Max"),
        "wk.add_note":       ("+ Note", "+ Note"),
        "wk.note_ph":        ("Note…", "Notes…"),
        "wk.add_ex_ph":      ("es. Dip alle parallele", "e.g. Parallel bar dips"),
        "wk.add_ex_hint":    ("Aggiunto alla sessione e salvato nel giorno per le prossime volte.",
                              "Added to the session and saved to the day for next time."),
        "wk.ex_added":       ("Esercizio aggiunto", "Exercise added"),
        "wk.nothing_save":   ("Nessuna serie da salvare", "No sets to save"),
        "wk.session_saved":  ("Sessione salvata", "Session saved"),

        // --- Plan editor (legacy) -------------------------------------------
        "pe.subtitle_hint":  ("Personalizza esercizi, serie e ripetizioni", "Customize exercises, sets and reps"),
        "pe.day_name":       ("Nome giorno", "Day name"),
        "pe.day_name_ph":    ("es. Push, Petto, Gambe…", "e.g. Push, Chest, Legs…"),
        "pe.subtitle":       ("Sottotitolo", "Subtitle"),
        "pe.subtitle_ph":    ("es. Spalle + Petto", "e.g. Shoulders + Chest"),
        "pe.color":          ("Colore", "Color"),
        "pe.exercises":      ("Esercizi", "Exercises"),
        "pe.no_ex":          ("Nessun esercizio. Aggiungine uno qui sotto.", "No exercises. Add one below."),
        "pe.ex_name_ph":     ("Nome esercizio", "Exercise name"),
        "pe.sets":           ("Serie", "Sets"),
        "pe.save_changes":   ("Salva modifiche", "Save changes"),
        "pe.delete_day":     ("Elimina giorno", "Delete day"),
        "pe.delete_day_q":   ("Eliminare questo giorno?", "Delete this day?"),
        "pe.group":          ("Gruppo", "Group"),

        // --- Stats (legacy) -------------------------------------------------
        "st.maxes":          ("I tuoi massimali", "Your maxes"),
        "st.maxes_hint":     ("Crea un giorno con esercizi per tracciare i record.", "Create a day with exercises to track records."),
        "st.select_ex":      ("Seleziona esercizio", "Select exercise"),
        "st.choose":         ("— Scegli —", "— Choose —"),
        "st.max_per_session":("Peso massimo per sessione", "Max weight per session"),
        "st.vol_per_session":("Volume totale per sessione", "Total volume per session"),
        "st.first":          ("Prima", "First"),
        "st.last":           ("Ultima", "Last"),
        "st.delta":          ("Delta", "Delta"),
        "st.progress_hint":  ("Seleziona un esercizio per vedere la progressione.", "Select an exercise to see progression."),
        "st.no_data":        ("Nessun dato", "No data"),
        "st.empty_history":  ("Storico vuoto", "No history"),
        "st.no_workouts":    ("Nessun allenamento registrato.", "No workouts logged."),
        "st.weight90":       ("Peso · 90 giorni", "Weight · 90 days"),
        "st.sleep":          ("Sleep score", "Sleep score"),
        "st.bmi_time":       ("BMI nel tempo", "BMI over time"),
        "st.composition":    ("Composizione corporea", "Body composition"),
        "st.lean":           ("Magra", "Lean"),
        "st.fat":            ("Grasso", "Fat"),
        "st.charts_hint":    ("Registra peso e sleep per 2+ giorni per vedere i grafici.", "Log weight and sleep for 2+ days to see charts."),

        // --- Profile card (legacy) ------------------------------------------
        "pc.title":          ("Obiettivi & profilo", "Goals & profile"),
        "pc.goal_weight":    ("Peso obiettivo", "Goal weight"),
        "pc.goal_bf":        ("Grasso obiettivo %", "Goal body fat %"),
        "pc.start_weight":   ("Peso iniziale", "Start weight"),
        "pc.height":         ("Altezza (m)", "Height (m)"),
        "pc.timer":          ("Recupero timer (s)", "Rest timer (s)"),
        "pc.save":           ("Salva profilo", "Save profile"),
        "pc.saved":          ("Profilo salvato", "Profile saved"),

        // --- BMI categories -------------------------------------------------
        "bmi.under":         ("Sottopeso", "Underweight"),
        "bmi.normal":        ("Normopeso", "Normal"),
        "bmi.over":          ("Sovrappeso", "Overweight"),
        "bmi.obese":         ("Obeso", "Obese"),

        // --- Sports ---------------------------------------------------------
        "sport.strength":    ("Forza", "Strength"),
        "sport.running":     ("Corsa", "Running"),
        "sport.swimming":    ("Nuoto", "Swimming"),
        "sport.cycling":     ("Bici", "Cycling"),
        "sport.walking":     ("Camminata", "Walking"),
        "sport.other":       ("Altro", "Other"),

        // --- Cardio types (saveable, like strength days) --------------------
        "wk.cardio":         ("Cardio", "Cardio"),
        "wk.cardio_types":   ("Attività cardio", "Cardio activities"),
        "wk.new_cardio":     ("Nuova attività", "New activity"),
        "wk.edit_cardio":    ("Modifica attività", "Edit activity"),
        "wk.add_cardio":     ("Aggiungi attività", "Add activity"),
        "wk.cardio_kind":    ("Tipo di sport", "Sport kind"),
        "wk.activity_name":  ("Nome attività", "Activity name"),
        "wk.activity_name_ph": ("es. Padel, Sci, HIIT…", "e.g. Padel, Ski, HIIT…"),
        "wk.cardio_saved":   ("Attività salvata", "Activity saved"),
        "wk.cardio_deleted": ("Attività eliminata", "Activity deleted"),
        "wk.delete_cardio_q":("Eliminare questa attività?", "Delete this activity?"),
        "wk.log_cardio":     ("Registra cardio", "Log cardio"),
        "wk.est_calories":   ("Calorie stimate", "Estimated calories"),
        "wk.est_cal_hint":   ("Calcolate dai tuoi dati (peso, età, sesso, FC).",
                              "Computed from your profile (weight, age, sex, HR)."),
        "wk.calories":       ("Calorie bruciate", "Calories burned"),
        "wk.cal_override":   ("Modifica manuale", "Manual override"),
        "wk.cal_hint":       ("Stima dai tuoi dati: con FC più precisa, altrimenti da durata e tipo di attività. Puoi sovrascriverla.",
                              "Estimated from your data: sharper with HR, otherwise from duration and activity type. You can override it."),

        // --- Goal editor ----------------------------------------------------
        "goal.change":       ("Cambia obiettivo", "Change goal"),
        "goal.title":        ("Modifica obiettivo", "Edit goal"),
        "goal.hint":         ("L'obiettivo resta fisso finché non lo cambi qui. Il peso iniziale è il punto di partenza dei progressi.",
                              "Your goal stays fixed until you change it here. Start weight is the baseline your progress is measured from."),
        "goal.start_weight": ("Peso iniziale (kg)", "Start weight (kg)"),
        "goal.saved":        ("Obiettivo aggiornato", "Goal updated"),

        // --- Weekly plan / next workout -------------------------------------
        "plan.week":         ("Piano settimanale", "Weekly plan"),
        "plan.week_hint":    ("Assegna un allenamento a ogni giorno. Il prossimo allenamento seguirà quest'ordine. Lascia vuoto per la rotazione automatica.",
                              "Assign a workout to each day. The next workout follows this order. Leave empty for automatic rotation."),
        "plan.rest":         ("Riposo", "Rest"),
        "plan.auto":         ("Automatico", "Auto"),
        "plan.none":         ("—", "—"),
        "plan.rotation":     ("Rotazione automatica", "Automatic rotation"),
        "plan.scheduled":    ("Da piano settimanale", "From weekly plan"),
        "plan.edit_week":    ("Pianifica la settimana", "Plan your week"),
        "plan.clear":        ("Azzera piano", "Clear plan"),
        "plan.today":        ("Oggi", "Today"),
        "plan.saved":        ("Piano salvato", "Plan saved"),

        // --- Train page hint ------------------------------------------------
        "wk.edit_hint":      ("Tocca l'icona di modifica su un giorno per rinominarlo, cambiarne colore ed esercizi o eliminarlo. Anche i giorni predefiniti sono completamente personalizzabili.",
                              "Tap the edit icon on a day to rename it, change its color and exercises, or delete it. The default days are fully customizable too."),
        "wk.edit":           ("Modifica", "Edit"),

        // --- Adherence / adaptive nutrition ---------------------------------
        "nut.adaptive":      ("Adattivo", "Adaptive"),
        "nut.adaptive_on":   ("TDEE appreso dai tuoi dati reali", "TDEE learned from your real data"),
        "nut.adherence":     ("Costanza", "Adherence"),
        "nut.logging":       ("Giorni con dieta tracciata", "Days nutrition logged"),
        "nut.steps_avg":     ("Passi medi", "Avg steps"),
        "nut.vol_sessions":  ("Allenamenti (2 sett.)", "Workouts (2 wks)"),
        "nut.low_logging":   ("Traccia la dieta più spesso per stime più precise", "Log nutrition more often for sharper estimates"),

        // --- HealthKit / data sources ---------------------------------------
        "hk.connect":        ("Collega Apple Salute", "Connect Apple Health"),
        "hk.connected":      ("Apple Salute collegata", "Apple Health connected"),
        "hk.sync":           ("Sincronizza ora", "Sync now"),
        "hk.synced":         ("Dati sincronizzati", "Data synced"),
        "hk.hint":           ("Importa automaticamente passi, frequenza cardiaca a riposo e HRV (RMSSD). Tutto facoltativo: puoi sempre inserirli a mano.",
                              "Automatically imports steps, resting heart rate and HRV (RMSSD). All optional: you can always enter them by hand."),
        "hk.unavailable":    ("Apple Salute non disponibile su questo dispositivo", "Apple Health unavailable on this device"),
        "hk.optional_note":  ("Questi dati non sono obbligatori ma migliorano prontezza, carico e nutrizione.",
                              "This data is not required but improves readiness, load and nutrition."),

        // --- Sleep / steps quick labels -------------------------------------
        "lbl.steps":         ("Passi", "Steps"),
        "metric.dfa":        ("DFA-alpha1 (soglia aerobica)", "DFA-alpha1 (aerobic threshold)"),
        "metric.dfa_soon":   ("Richiede una fascia cardio Bluetooth · in arrivo", "Needs a Bluetooth chest strap · coming soon"),
        "load.trend_title":  ("Andamento carico · 14 giorni", "Load trend · 14 days"),
        "load.no_load_yet":  ("Inserisci durata + RPE (o FC) per vedere il carico", "Enter duration + RPE (or HR) to see load"),

        // --- Info popups (scientific metrics) -------------------------------
        "info.readiness.title": ("Prontezza (HRV)", "Readiness (HRV)"),
        "info.readiness.body": (
            "Stima quanto sei recuperato a partire dalla variabilità della frequenza cardiaca (HRV), misurata come RMSSD che inserisci al mattino.\n\nUsiamo il logaritmo naturale dell'RMSSD (lnRMSSD), più stabile, e lo confrontiamo con la tua media degli ultimi ~60 giorni calcolando uno z-score. Il punteggio 0-100 è 50 + 20 × z.\n\nAlto = sistema nervoso recuperato, puoi spingere. Basso = sotto la tua norma, meglio andare leggeri o recuperare. Servono almeno 5 misurazioni per costruire la baseline.",
            "Estimates how recovered you are from heart-rate variability (HRV), measured as the RMSSD you type in each morning.\n\nWe take the natural log of RMSSD (lnRMSSD, which is more stable) and compare it to your ~60-day average as a z-score. The 0-100 score is 50 + 20 × z.\n\nHigh = nervous system recovered, you can push. Low = below your norm, better to go easy or rest. At least 5 readings are needed to build the baseline."),
        "info.acwr.title": ("Carico acuto:cronico (ACWR)", "Acute:Chronic load (ACWR)"),
        "info.acwr.body": (
            "Rapporto tra il carico recente (acuto, ultimi 7 giorni) e quello abituale (cronico, ultimi 28 giorni), entrambi calcolati con una media mobile esponenziale (EWMA).\n\nIl carico viene dal TRIMP, quindi compare solo dopo che inserisci durata + FC media della sessione (serve un orologio o una fascia cardio).\n\nZona indicativa: 0,8-1,3 = ottimale; sotto 0,8 = stai scaricando (rischio detraining); sopra 1,3 = picco di carico e maggior rischio infortuni.",
            "Ratio between recent load (acute, last 7 days) and habitual load (chronic, last 28 days), both computed with an exponentially weighted moving average (EWMA).\n\nLoad comes from TRIMP, so it only appears once you enter the session's duration + average HR (a watch or chest strap is needed).\n\nGuide: 0.8-1.3 = sweet spot; below 0.8 = detraining/unloading; above 1.3 = a load spike and higher injury risk."),
        "info.monotony.title": ("Monotonia", "Monotony"),
        "info.monotony.body": (
            "Quanto è uniforme il carico nei giorni della settimana: media giornaliera divisa per la sua deviazione standard (metodo di Foster).\n\nValori alti (sopra ~2) significano allenamenti tutti simili, senza alternanza tra giorni duri e leggeri: è associato a maggior affaticamento. Variare l'intensità abbassa la monotonia.\n\nServono almeno 2 giorni di allenamento con RPE/FC nella settimana per calcolarla.",
            "How even your load is across the week: mean daily load divided by its standard deviation (Foster's method).\n\nHigh values (above ~2) mean every session looks the same, with no hard/easy alternation, which is linked to more fatigue. Varying intensity lowers monotony.\n\nNeeds at least 2 training days with RPE/HR in the week to be computed."),
        "info.strain.title": ("Strain", "Strain"),
        "info.strain.body": (
            "Carico totale della settimana moltiplicato per la monotonia (metodo di Foster).\n\nRiassume in un solo numero quanto stress complessivo stai accumulando: alto quando alleni molto E in modo monotono. Picchi di strain precedono spesso sovraccarico, malanni o cali di forma, quindi è un buon segnale per inserire una settimana di scarico.",
            "The week's total load multiplied by monotony (Foster's method).\n\nIt sums up your overall accumulated stress in one number: high when you train a lot AND monotonously. Strain spikes often precede overreaching, illness or performance dips, so it's a good cue to schedule a deload week."),
        "info.load.title": ("Carico interno", "Internal load"),
        "info.load.body": (
            "Il carico interno misura lo stress dell'allenamento percepito dal tuo corpo, non i kg sollevati.\n\nLo calcoliamo come TRIMP a partire dalla durata e dalla frequenza cardiaca media della sessione. Da qui derivano ACWR, monotonia e strain.\n\nImportante: senza durata + FC media una sessione non genera carico interno, quindi queste metriche restano vuote finché non inserisci quei dati (serve un orologio o una fascia cardio).",
            "Internal load measures the training stress your body actually experiences, not the kilos lifted.\n\nWe compute it as TRIMP from the session's duration and average heart rate. ACWR, monotony and strain all build on it.\n\nImportant: without duration + average HR a session produces no internal load, so these metrics stay empty until you enter that data (a watch or chest strap is needed). If you ever saw a very high load with no HR, that came from an old session's manual effort rating: internal load is now based on heart rate alone, so it can no longer be inflated without it."),
        "info.activity.title": ("Livello di attività", "Activity level"),
        "info.activity.body": (
            "Il livello di attività moltiplica il tuo metabolismo basale (BMR) per stimare quante calorie bruci ogni giorno (TDEE). Più ti muovi e ti alleni, più alto è il moltiplicatore.\n\nSedentario (×1.2): lavoro d'ufficio, nessun allenamento.\nLeggero (×1.375): 1-2 allenamenti a settimana.\nModerato (×1.55): 3-4 allenamenti a settimana.\nAlto (×1.725): 5-6 allenamenti a settimana.\nAtleta (×1.9): 6-7 allenamenti a settimana più un lavoro fisico o doppie sedute giornaliere.\n\nScegli in base ai giorni reali di allenamento: è il punto di partenza per calorie e macro.",
            "Your activity level multiplies your basal metabolism (BMR) to estimate how many calories you burn each day (TDEE). The more you move and train, the higher the multiplier.\n\nSedentary (×1.2): desk job, no training.\nLight (×1.375): 1-2 workouts per week.\nModerate (×1.55): 3-4 workouts per week.\nHigh (×1.725): 5-6 workouts per week.\nAthlete (×1.9): 6-7 workouts per week plus a physical job or twice-daily sessions.\n\nPick it from your real training days: it's the basis for your calories and macros."),
        "info.srpe.title": ("sRPE (durata × RPE)", "sRPE (duration × RPE)"),
        "info.srpe.body": (
            "Session-RPE: durata della sessione in minuti moltiplicata per lo sforzo percepito (RPE 1-10, scala di Borg CR10).\n\nÈ il modo più semplice e validato per quantificare il carico interno di qualsiasi allenamento, di forza o cardio. Inserisci durata e RPE a fine sessione.",
            "Session-RPE: session duration in minutes multiplied by perceived effort (RPE 1-10, Borg CR10 scale).\n\nIt's the simplest validated way to quantify the internal load of any session, strength or cardio. Enter duration and RPE at the end of the session."),
        "info.trimp.title": ("TRIMP", "TRIMP"),
        "info.trimp.body": (
            "Training Impulse (Banister): pesa la durata con la frequenza cardiaca di riserva e un fattore esponenziale diverso per uomo e donna.\n\nRichiede FC media e durata della sessione, oltre alla FC a riposo e massima del tuo profilo. È più preciso dell'sRPE per il cardio, perché tiene conto dell'intensità cardiovascolare reale.",
            "Training Impulse (Banister): weights duration by heart-rate reserve and a sex-specific exponential factor.\n\nIt needs average HR and session duration, plus your resting and max HR from the profile. It's more precise than sRPE for cardio because it accounts for real cardiovascular intensity."),
        "info.bmi.title": ("BMI", "BMI"),
        "info.bmi.body": (
            "Indice di massa corporea: peso (kg) diviso per il quadrato dell'altezza (m). Categorie OMS: <18,5 sottopeso, 18,5-25 normopeso, 25-30 sovrappeso, >30 obeso.\n\nÈ un indicatore di massima: non distingue muscolo da grasso, quindi per chi è molto muscoloso può risultare alto pur con poco grasso. Per la composizione usa il grasso corporeo.",
            "Body Mass Index: weight (kg) divided by height (m) squared. WHO categories: <18.5 underweight, 18.5-25 normal, 25-30 overweight, >30 obese.\n\nIt's a rough screen: it can't tell muscle from fat, so very muscular people can read high with little fat. Use body fat for composition."),
        "info.bodyfat.title": ("Grasso corporeo", "Body fat"),
        "info.bodyfat.body": (
            "Percentuale di massa grassa sul peso totale. Puoi inserirla manualmente (da plicometro o bilancia) oppure lasciare la stima Navy, basata su circonferenze di collo e vita più l'altezza.\n\nLa stima Navy è comoda ma indicativa (±3-4%): l'importante è misurare sempre allo stesso modo e seguire il trend.",
            "Share of fat mass over total weight. Enter it manually (from calipers or a scale) or use the Navy estimate, based on neck and waist circumferences plus height.\n\nThe Navy estimate is handy but approximate (±3-4%): what matters is measuring the same way every time and following the trend."),
        "info.tdee.title": ("TDEE & BMR", "TDEE & BMR"),
        "info.tdee.body": (
            "Il BMR (metabolismo basale) è l'energia che bruci a riposo, calcolata con la formula di Mifflin-St Jeor da peso, altezza, età e sesso.\n\nIl TDEE è il dispendio totale giornaliero: BMR × un moltiplicatore di attività (1,2 sedentario → 1,9 atleta). È il punto di partenza per impostare le calorie obiettivo di definizione, mantenimento o massa.",
            "BMR (basal metabolic rate) is the energy you burn at rest, from the Mifflin-St Jeor formula using weight, height, age and sex.\n\nTDEE is your total daily expenditure: BMR × an activity multiplier (1.2 sedentary → 1.9 athlete). It's the basis for setting cut, maintenance or bulk calorie targets."),
        "info.macros.title": ("Macronutrienti", "Macronutrients"),
        "info.macros.body": (
            "La ripartizione di proteine, carboidrati e grassi che compone le calorie obiettivo, su range ISSN.\n\nProteine ~1,8-2,2 g/kg (più alte in definizione per proteggere la massa magra). Grassi ~0,8 g/kg come minimo ormonale. I carboidrati riempiono le calorie restanti e alimentano la prestazione.",
            "How protein, carbs and fat split up your calorie target, on ISSN ranges.\n\nProtein ~1.8-2.2 g/kg (higher on a cut to protect lean mass). Fat ~0.8 g/kg as a hormonal floor. Carbs fill the remaining calories and fuel performance."),
        "info.carbcycle.title": ("Ciclizzazione dei carboidrati", "Carb cycling"),
        "info.carbcycle.body": (
            "Sposta i carboidrati verso i giorni di allenamento mantenendo la media settimanale: più carbo nei giorni ON (×1,30) per la prestazione, meno nei giorni OFF (×0,65).\n\nUtile soprattutto in definizione per allenarsi con energia pur restando in deficit. Le proteine restano costanti ogni giorno.",
            "Shuttles carbs toward training days while keeping the weekly average: more carbs on training (ON) days (×1.30) for performance, fewer on rest (OFF) days (×0.65).\n\nMost useful on a cut, to train with energy while staying in a deficit. Protein stays constant every day."),
        "info.lea.title": ("Disponibilità energetica (EA)", "Energy availability (EA)"),
        "info.lea.body": (
            "Energia che resta per le funzioni vitali dopo l'allenamento: (calorie assunte − energia spesa con l'esercizio) ÷ massa magra, mediata sugli ultimi 7 giorni.\n\nSotto 30 kcal/kg di massa magra al giorno c'è rischio di bassa disponibilità energetica (LEA/RED-S): cali ormonali, ossei e di prestazione. 30-45 è una zona di cautela sotto carichi alti. Richiede calorie e grasso corporeo inseriti.",
            "The energy left for vital functions after training: (calories eaten − exercise energy) ÷ fat-free mass, averaged over the last 7 days.\n\nBelow 30 kcal per kg of lean mass per day there's a risk of low energy availability (LEA/RED-S): hormonal, bone and performance decline. 30-45 is a caution zone under heavy load. Needs logged calories and body fat."),
        "info.trend.title": ("Trend del peso", "Weight trend"),
        "info.trend.body": (
            "Stima la tua reale variazione di peso (kg/settimana) con una regressione lineare sugli ultimi ~21 pesi, eliminando il rumore quotidiano da acqua e sale.\n\nConfronta il ritmo reale con l'obiettivo e suggerisce un aggiustamento calorico se vai troppo veloce, troppo lento o nella direzione sbagliata. Servono almeno 4 pesate.",
            "Estimates your real weight change (kg/week) with a linear regression over your last ~21 weigh-ins, filtering out daily water/salt noise.\n\nIt compares the real rate to your target and suggests a calorie adjustment if you're too fast, too slow or going the wrong way. Needs at least 4 weigh-ins."),
        "info.overload.title": ("Sovraccarico progressivo", "Progressive overload"),
        "info.overload.body": (
            "Suggerimenti di doppia progressione per il prossimo allenamento, confrontando l'ultima sessione con il range di ripetizioni obiettivo.\n\nSe hai raggiunto il massimo del range su tutte le serie → aumenta il carico. Se sei dentro al range → cerca più ripetizioni. Se sei sotto → mantieni e cura la tecnica. Così cresci in modo graduale e misurabile.",
            "Double-progression hints for your next workout, comparing your last session to the target rep range.\n\nIf you hit the top of the range on every set → add load. If you're inside the range → chase more reps. If you're below → hold and refine technique. This grows you gradually and measurably."),
        "info.calories.title": ("Calorie bruciate", "Calories burned"),
        "info.calories.body": (
            "Stima dell'energia spesa nella sessione a partire dai tuoi dati (peso, età, sesso).\n\nSe hai inserito la FC media usiamo la formula di Keytel basata sulla frequenza cardiaca; per il cardio senza FC usiamo i MET dell'attività × peso × durata; per la forza una stima da volume e serie. È un'approssimazione, non una misura da metabolimetro.",
            "An estimate of the energy spent in the session, derived from your profile (weight, age, sex). The app always uses the most precise formula your data allows.\n\nWith average HR we use the Keytel heart-rate equation (most precise). For cardio without HR we use a sport-specific MET — cycling, running, walking and swimming each have their own formula, refined by your real speed when a distance is logged. For strength we use a resistance-training MET over the session duration, or a volume estimate. You can always type your own number to override the estimate. It's an approximation, not a lab measurement."),
        "info.rmssd.title": ("RMSSD (HRV)", "RMSSD (HRV)"),
        "info.rmssd.body": (
            "L'RMSSD è la principale misura della variabilità della frequenza cardiaca (HRV): la radice quadrata della media dei quadrati delle differenze tra battiti consecutivi (intervalli R-R), in millisecondi.\n\nRiflette l'attività del sistema nervoso parasimpatico (recupero). Valori più alti del tuo solito indicano buon recupero; valori bassi indicano stress o affaticamento. Misuralo al mattino, da sdraiato, sempre nello stesso modo, con un'app HRV o una fascia cardio, e inseriscilo qui. L'app lo trasforma poi nel punteggio di Prontezza.",
            "RMSSD is the main heart-rate variability (HRV) metric: the root mean square of successive differences between consecutive heartbeats (R-R intervals), in milliseconds.\n\nIt reflects parasympathetic (recovery) nervous-system activity. Higher than your usual means good recovery; low means stress or fatigue. Measure it in the morning, lying down, the same way each time, with an HRV app or chest strap, and enter it here. The app then turns it into your Readiness score."),
        "info.dfa.title": ("DFA-alpha1 (soglia aerobica)", "DFA-alpha1 (aerobic threshold)"),
        "info.dfa.body": (
            "La DFA-alpha1 è un indice ricavato dall'analisi frattale (detrended fluctuation analysis) della serie di intervalli R-R durante la corsa. Quando scende intorno a 0,75 segnala il primo soglia ventilatoria/aerobica, permettendo di stimarla senza test di laboratorio.\n\nRichiede un flusso continuo e accurato di intervalli R-R battito-battito da una fascia cardiaca Bluetooth, quindi è in arrivo insieme al supporto Bluetooth. La frequenza cardiaca da polso non è abbastanza precisa per questo calcolo.",
            "DFA-alpha1 is an index from fractal (detrended fluctuation) analysis of the R-R interval series during running. When it drops to around 0.75 it marks the first ventilatory/aerobic threshold, letting you estimate it without a lab test.\n\nIt needs a continuous, accurate beat-to-beat R-R stream from a Bluetooth chest strap, so it's coming together with Bluetooth support. Wrist heart rate is not precise enough for this calculation."),
        "info.weekplan.title": ("Piano settimanale", "Weekly plan"),
        "info.weekplan.body": (
            "Decide quale sarà il tuo prossimo allenamento. Senza piano, l'app ruota automaticamente tra i giorni nell'ordine in cui appaiono nella pagina Allena (dopo Push viene Pull, ecc., poi ricomincia).\n\nCon il piano settimanale assegni a ogni giorno della settimana un allenamento di forza, un'attività cardio o riposo: il prossimo allenamento seguirà esattamente l'ordine che preferisci (es. Lunedì Push, Martedì Corsa, Giovedì Pull…). Lascia tutto vuoto per tornare alla rotazione automatica.",
            "Decides what your next workout will be. Without a plan, the app rotates automatically through your days in the order they appear on the Train page (after Push comes Pull, etc., then loops).\n\nWith the weekly plan you assign each weekday a strength workout, a cardio activity or rest: the next workout follows exactly the order you prefer (e.g. Monday Push, Tuesday Running, Thursday Pull…). Leave it all empty to go back to automatic rotation."),
        "info.adherence.title": ("Costanza & TDEE adattivo", "Adherence & adaptive TDEE"),
        "info.adherence.body": (
            "Le calorie obiettivo non si basano solo sul peso. Quando registri la dieta e il peso per abbastanza giorni, l'app calcola il tuo mantenimento reale (TDEE adattivo) = calorie medie assunte − energia implicata dal trend di peso. Così impara la tua spesa energetica vera invece di fidarsi solo del moltiplicatore di attività.\n\nConsidera anche costanza di tracciamento, passi medi e volume di allenamento delle ultime 2-3 settimane. Se tracci poco, le stime sono meno affidabili e l'app te lo segnala.",
            "Your calorie target isn't based on weight alone. Once you log nutrition and weight for enough days, the app computes your real maintenance (adaptive TDEE) = average intake − the energy implied by your weight trend. So it learns your true expenditure instead of trusting only the activity multiplier.\n\nIt also considers logging consistency, average steps and training volume over the last 2-3 weeks. If you log little, estimates are less reliable and the app flags it."),
        "info.steps.title": ("Passi", "Steps"),
        "info.steps.body": (
            "I passi giornalieri sono una misura dell'attività non sportiva (NEAT), che incide molto sul dispendio energetico totale. Inseriscili a mano o, se attivi Apple Salute, vengono importati automaticamente.\n\nServono per valutare la tua costanza di movimento e per rendere più precise le stime caloriche adattive.",
            "Daily steps measure your non-exercise activity (NEAT), which heavily affects total energy expenditure. Enter them by hand or, if you connect Apple Health, they're imported automatically.\n\nThey help gauge how consistently you move and make the adaptive calorie estimates more accurate."),
        "info.sleep.title": ("Punteggio sonno", "Sleep score"),
        "info.sleep.body": (
            "Un punteggio 0-100 che riassume quanto bene hai dormito (durata e qualità percepita). Il sonno è uno dei fattori più importanti per recupero, prestazione e composizione corporea.\n\nInseriscilo ogni mattina insieme al peso: nel tempo potrai vedere come il sonno si correla con prontezza e progressi.",
            "A 0-100 score summarizing how well you slept (duration and perceived quality). Sleep is one of the biggest drivers of recovery, performance and body composition.\n\nLog it each morning with your weight: over time you'll see how sleep relates to readiness and progress."),
        "info.goal.title": ("Obiettivo & progressi", "Goal & progress"),
        "info.goal.body": (
            "Il tuo obiettivo (peso e grasso) viene fissato al primo accesso e NON cambia automaticamente a ogni check-in: resta stabile finché non lo modifichi tu con il pulsante Cambia obiettivo.\n\nLa barra di avanzamento parte dal tuo peso iniziale e arriva al peso obiettivo, quindi si riempie man mano che ti avvicini, in salita o in discesa. Il numero a sinistra è il tuo peso attuale, che ovviamente cambia ad ogni pesata: è normale, l'obiettivo a destra resta fisso.",
            "Your goal (weight and body fat) is set at first launch and does NOT change automatically at every check-in: it stays fixed until you change it with the Change goal button.\n\nThe progress bar runs from your start weight to your goal weight, filling as you get closer, whether losing or gaining. The number on the left is your current weight, which of course changes with each weigh-in: that's normal, the goal on the right stays put."),
        "info.streak.title": ("Striscia", "Streak"),
        "info.streak.body": (
            "I giorni consecutivi in cui hai fatto un check-in o un allenamento. La striscia resta attiva per tutta la giornata di oggi: non si azzera solo perché non hai ancora fatto il check-in di oggi.\n\nSi interrompe soltanto quando passa un giorno intero senza alcun check-in né allenamento.",
            "The consecutive days you've done a check-in or a workout. The streak stays active for the whole of today: it doesn't reset just because you haven't checked in yet today.\n\nIt only breaks once a full day passes with no check-in and no workout."),

        // --- Day logging / rest / recommended fields ------------------------
        "home.tap_to_log":   ("Tocca un giorno per registrare", "Tap a day to log"),
        "day.title":         ("Registra giornata", "Log day"),
        "day.hint":          ("Scegli cosa hai fatto in questo giorno: un allenamento di forza, un'attività cardio o riposo. I dati partono dall'ultima volta e restano modificabili.",
                              "Choose what you did on this day: a strength workout, a cardio activity or rest. Data starts from last time and stays editable."),
        "day.mark_rest":     ("Segna come riposo", "Mark as rest"),
        "day.clear_rest":    ("Rimuovi riposo", "Remove rest"),
        "cal.tap_hint":      ("Tocca un giorno per registrare un allenamento o il riposo", "Tap a day to log a workout or rest"),
        "load.recommended":  ("Consigliato", "Recommended"),
        "load.sensor":       ("Sensore HRV", "HRV sensor"),
        "load.trimp_hint":   ("Carico cardio della sessione", "Session cardio load"),

        // --- TRIMP card -----------------------------------------------------
        "trimp.title":       ("Carico cardio (TRIMP)", "Cardio load (TRIMP)"),
        "trimp.this_week":   ("Questa settimana", "This week"),
        "trimp.last_week":   ("Settimana scorsa", "Last week"),
        "trimp.last":        ("Ultima:", "Last:"),
        "trimp.note":        ("Somma del TRIMP delle sessioni con FC media. Più alto = più stress cardiovascolare.",
                              "Sum of session TRIMP from average HR. Higher = more cardiovascular stress."),
    ]
}

/// Localized label for a measurement field key (waist/chest/…).
func measLabel(_ key: String) -> String { L.t("meas." + key) }

// Convenience: t("key") as a free function for brevity in views, with optional
// printf-style arguments (e.g. t("nut.adjust", 150)).
func t(_ key: String, _ args: CVarArg...) -> String {
    let s = L.t(key)
    return args.isEmpty ? s : String(format: s, arguments: args)
}
