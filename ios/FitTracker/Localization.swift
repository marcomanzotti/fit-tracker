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
        "nav.home":      ("Home", "Home"),
        "nav.train":     ("Allena", "Train"),
        "nav.body":      ("Corpo", "Body"),
        "nav.nutrition": ("Nutrizione", "Nutrition"),
        "nav.stats":     ("Stats", "Stats"),
        "sub.home":      ("Dashboard", "Dashboard"),
        "sub.train":     ("Log allenamento", "Workout log"),
        "sub.body":      ("Misurazioni & Check-in", "Measurements & Check-in"),
        "sub.nutrition": ("Alimentazione", "Nutrition"),
        "sub.stats":     ("Statistiche", "Statistics"),
        // Nutrition page + body recovery
        "body.recovery":  ("Recupero", "Recovery"),
        "nutp.today":     ("Oggi", "Today"),
        "nutp.log_today": ("Registra oggi", "Log today"),
        "nutp.edit_today":("Modifica oggi", "Edit today"),
        "nutp.my_foods":  ("I miei alimenti", "My foods"),
        "nutp.no_foods":  ("Nessun alimento salvato. Scansiona o crea il primo.", "No foods saved yet. Scan or create your first one."),

        // --- Home -----------------------------------------------------------
        "home.checkin":      ("Check-in di oggi", "Today's check-in"),
        "home.weight":       ("Peso", "Weight"),
        "home.sleep":        ("Sonno", "Sleep"),
        "home.sleep_score":  ("Punteggio sonno", "Sleep score"),
        "home.save_checkin": ("Salva check-in", "Save check-in"),
        "home.streak":       ("Streak", "Streak"),
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
        "load.building":     ("Baseline in costruzione", "Building baseline"),
        "load.building_body": (
            "ACWR, monotonia e strain confrontano il carico recente (7 giorni) con quello abituale (28 giorni): con poche sessioni il valore è completamente fuori scala e non affidabile.\n\nServono almeno %d sessioni con durata + FC media, distribuite su almeno %d giorni. L'ideale sono circa 4 settimane di dati costanti.",
            "ACWR, monotony and strain compare your recent load (7 days) with your habitual load (28 days): with only a few sessions the value is completely out of scale and unreliable.\n\nYou need at least %d sessions with duration + average HR, spread over at least %d days. About 4 weeks of consistent data is ideal."),
        "load.sessions_logged": ("Sessioni con carico", "Load sessions"),
        "load.history_days":    ("Giorni di storico", "Days of history"),

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

        // --- Nutrition calendar & per-meal logging --------------------------
        "meal.breakfast":    ("Colazione", "Breakfast"),
        "meal.lunch":        ("Pranzo", "Lunch"),
        "meal.dinner":       ("Cena", "Dinner"),
        "meal.snacks":       ("Spuntini", "Snacks"),
        "nut.calendar":      ("Calendario nutrizione", "Nutrition calendar"),
        "nut.cal_hint_tap":  ("Tocca un giorno per inserire o modificare le calorie", "Tap a day to add or edit calories"),
        "nut.edit_day":      ("Modifica nutrizione", "Edit nutrition"),
        "nut.quick":         ("Totale rapido", "Quick total"),
        "nut.per_meal":      ("Per pasto", "Per meal"),
        "nut.foods":         ("Alimenti", "Foods"),
        "nut.entry_mode":    ("Modalità di inserimento", "Entry mode"),
        // --- Food logging (saved list + barcode) ----------------------------
        "food.title":        ("Alimenti", "Foods"),
        "food.search":       ("Cerca un alimento", "Search a food"),
        "food.scan":         ("Scansiona", "Scan"),
        "food.new":          ("Nuovo", "New"),
        "food.new_title":    ("Alimento", "Food"),
        "food.none":         ("Nessun alimento salvato. Creane uno o scansiona un barcode.",
                              "No saved foods yet. Create one or scan a barcode."),
        "food.add":          ("Aggiungi alimento", "Add food"),
        "food.name":         ("Nome", "Name"),
        "food.per100_label": ("Valori per 100", "Values per 100"),
        "food.liquid":       ("Liquido (misura in ml)", "Liquid (measured in ml)"),
        "food.save_food":    ("Salva alimento", "Save food"),
        "food.amount":       ("Quantità", "Amount"),
        "food.day_foods":    ("Alimenti di oggi", "Today's foods"),
        "food.looking":      ("Ricerca prodotto…", "Looking up product…"),
        "food.scan_hint":    ("Inquadra il codice a barre", "Point at the barcode"),
        "food.scan_unavailable": ("Scansione non disponibile su questo dispositivo. Inserisci l'alimento a mano.",
                                  "Scanning isn't available on this device. Add the food by hand."),
        "nut.day_total":     ("Totale giornaliero", "Daily total"),
        "nut.kcal":          ("Calorie", "Calories"),
        "nut.no_log":        ("Nessun dato nutrizionale", "No nutrition logged"),
        "nut.charts":        ("Grafici nutrizione", "Nutrition charts"),
        "nut.weekly_avg":    ("media sett.", "weekly avg"),
        "nut.charts_hint":   ("Registra le calorie per 2+ giorni per vedere i grafici.", "Log calories for 2+ days to see charts."),
        "nut.saved":         ("Nutrizione salvata", "Nutrition saved"),
        "nut.cleared":       ("Dati nutrizionali rimossi", "Nutrition cleared"),
        "st.section_workout":("Allenamento", "Workout"),
        "st.section_nutrition":("Nutrizione", "Nutrition"),

        // --- Workout / methods / sports ------------------------------------
        "wk.live":           ("Allenamento live", "Live workout"),
        "wk.add_ex":         ("Aggiungi esercizio", "Add exercise"),
        "wk.set":            ("Serie", "Set"),
        "wk.reps":           ("Rip", "Reps"),
        "wk.suggested":      ("Suggerito", "Suggested"),
        "wk.last_time":      ("Ultima volta", "Last time"),
        "wk.notes":          ("Note", "Notes"),
        "wk.rpe":            ("RPE sessione", "Session RPE"),
        "wk.duration":       ("Durata", "Duration"),
        "dur.h":             ("ore", "hrs"),
        "dur.m":             ("min", "min"),
        "dur.s":             ("sec", "sec"),
        "wk.avg_hr":         ("FC media", "Avg HR"),
        "wk.rmssd":          ("RMSSD", "RMSSD"),
        "wk.superset":       ("Superset", "Superset"),
        "wk.method":         ("Metodo", "Method"),
        "wk.sport":          ("Sport", "Sport"),
        "wk.distance":       ("Distanza", "Distance"),
        "wk.pace":           ("Ritmo", "Pace"),
        "wk.speed":          ("Velocità", "Speed"),
        "wk.pace_auto":      ("Auto da distanza e durata", "Auto from distance & duration"),
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
        "ob.height":         ("Altezza", "Height"),
        "ob.weight":         ("Peso attuale", "Current weight"),
        "ob.goal_weight":    ("Peso obiettivo", "Goal weight"),
        "ob.goal_mode":      ("Obiettivo", "Goal"),
        "ob.rate":           ("Ritmo", "Rate"),
        "ob.per_wk":         ("sett", "wk"),
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
        "set.units":         ("Unità di misura", "Units"),
        "set.metric":        ("Metrico (kg, cm, km)", "Metric (kg, cm, km)"),
        "set.imperial":      ("Imperiale (lb, in, mi)", "Imperial (lb, in, mi)"),

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
        "wk.finish_session": ("Termina sessione", "Finish session"),
        "wk.finish":         ("Termina", "Finish"),
        "wk.pause":          ("Pausa", "Pause"),
        "wk.resume":         ("Riprendi", "Resume"),
        "wk.paused":         ("In pausa", "Paused"),
        "wk.speed_pace":     ("Ritmo", "Pace"),
        "wk.gps_hint":       ("Attiva la posizione per misurare distanza e ritmo via GPS.",
                              "Enable location to measure distance and pace via GPS."),
        "wk.discard_session":("Elimina allenamento", "Discard workout"),
        "wk.discard_q":      ("Eliminare questo allenamento? L'operazione non può essere annullata.",
                              "Discard this workout? This can't be undone."),
        "wk.discarded":      ("Allenamento eliminato", "Workout discarded"),
        "wk.minimize":       ("Riduci", "Minimize"),
        "wk.cal_at_finish":  ("Le calorie vengono stimate al termine dell'allenamento.",
                              "Calories are estimated when you finish the workout."),
        "wk.last":           ("Ultima", "Last"),
        "wk.others":         ("altri", "others"),
        "wk.last_time_label":("Ultima volta", "Last time"),
        "wk.try":            ("Prova", "Try"),
        "wk.add_set":        ("+ Serie", "+ Set"),
        "wk.timer":          ("Timer", "Timer"),
        "wk.vol":            ("Vol", "Vol"),
        "wk.max":            ("Max", "Max"),
        "wk.round":          ("Round", "Round"),
        "wk.rounds_done":    ("Round fatti", "Rounds done"),
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
        // Exercise kinds (reps / timed hold / HIIT interval)
        "pe.kind":           ("Tipo", "Type"),
        "pe.target_sec":     ("Tempo (s)", "Time (s)"),
        "pe.work_sec":       ("Lavoro", "Work"),
        "pe.rest_sec":       ("Riposo", "Rest"),
        "pe.rounds":         ("Round", "Rounds"),
        "exkind.reps":       ("Ripetizioni", "Reps"),
        "exkind.timed":      ("A tempo", "Timed"),
        "exkind.interval":   ("Intervalli", "Interval"),
        "mg.title":          ("Gruppo muscolare", "Muscle group"),
        // Exercise browse / picker
        "pe.browse":         ("Sfoglia", "Browse"),
        "pe.blank":          ("Vuoto", "Blank"),
        "pe.search_ex":      ("Cerca esercizio…", "Search exercise…"),
        "pe.no_ex_found":    ("Nessun esercizio trovato", "No exercises found"),
        "pe.create":         ("Crea", "Create"),

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
        "st.bmi_time":       ("BMI", "BMI"),
        "st.composition":    ("Composizione corporea", "Body composition"),
        "st.lean":           ("Magra", "Lean"),
        "st.fat":            ("Grasso", "Fat"),
        "st.charts_hint":    ("Registra peso e sleep per 2+ giorni per vedere i grafici.", "Log weight and sleep for 2+ days to see charts."),

        // --- Profile card (legacy) ------------------------------------------
        "pc.title":          ("Obiettivi & profilo", "Goals & profile"),
        "pc.goal_weight":    ("Peso obiettivo", "Goal weight"),
        "pc.goal_bf":        ("Grasso obiettivo %", "Goal body fat %"),
        "pc.start_weight":   ("Peso iniziale", "Start weight"),
        "pc.height":         ("Altezza", "Height"),
        "pc.timer":          ("Recupero timer (s)", "Rest timer (s)"),
        "pc.save":           ("Salva profilo", "Save profile"),
        "pc.saved":          ("Profilo salvato", "Profile saved"),

        // --- BMI categories -------------------------------------------------
        "bmi.under":         ("Sottopeso", "Underweight"),
        "bmi.normal":        ("Normopeso", "Normal"),
        "bmi.over":          ("Sovrappeso", "Overweight"),
        "bmi.obese":         ("Obeso", "Obese"),

        // --- Body-fat categories (sex-specific) -----------------------------
        "bf.essential":      ("Essenziale", "Essential"),
        "bf.athlete":        ("Atleta", "Athlete"),
        "bf.fitness":        ("Fitness", "Fitness"),
        "bf.average":        ("Nella media", "Average"),
        "bf.overweight":     ("Sovrappeso", "Overweight"),
        "bf.obese":          ("Obeso", "Obese"),
        "bf.muscular":       ("Muscoloso (BMI alto, grasso basso)", "Muscular (high BMI, low fat)"),
        "bf.category":       ("Categoria grasso", "Body-fat category"),

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
        "wk.activity_sub":   ("Sottotitolo", "Subtitle"),
        "wk.activity_sub_ph": ("es. Lungo · Recupero · Soglia…", "e.g. Long · Recovery · Threshold…"),
        "chart.gran.day":    ("Giorno", "Day"),
        "chart.gran.week":   ("Settimana", "Week"),
        "chart.gran.month":  ("Mese", "Month"),
        "chart.gran.year":   ("Anno", "Year"),
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
        "goal.start_weight": ("Peso iniziale", "Start weight"),
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
        "hk.hint":           ("Importa automaticamente passi, energia attiva, minuti di attività, frequenza cardiaca a riposo e HRV, e gli allenamenti registrati da qualsiasi orologio abbinato all'iPhone (Apple Watch, Garmin, Fitbit, Polar, Coros, Huawei…). Tutto facoltativo.",
                              "Automatically imports steps, active energy, exercise minutes, resting heart rate and HRV, plus workouts recorded by any watch paired to your iPhone (Apple Watch, Garmin, Fitbit, Polar, Coros, Huawei…). All optional."),
        "hk.imported":       ("Da Apple Salute", "From Apple Health"),
        "hk.imported_n":     ("allenamenti importati", "workouts imported"),
        // --- Connect-your-watch guide ---------------------------------------
        "guide.open":        ("Collega il tuo orologio", "Connect your watch"),
        "guide.title":       ("Collega il tuo orologio", "Connect your watch"),
        "guide.intro":       ("Qualunque orologio abbinato all'iPhone può alimentare l'app passando da Apple Salute. Collega Salute qui, poi attiva la sincronizzazione nell'app del tuo orologio (sotto).",
                              "Any watch paired to your iPhone can feed the app through Apple Health. Connect Health here, then turn syncing on inside your watch's own app (below)."),
        "guide.health_group":("Orologi che inviano ad Apple Salute", "Watches that send to Apple Health"),
        "guide.other_group": ("Altri orologi (Huawei, Fitbit…)", "Other watches (Huawei, Fitbit…)"),
        "guide.other_note":  ("Alcuni orologi (Huawei e qualche brand) non scrivono su Apple Salute. Esporta l'allenamento dalla loro app come file .gpx o .tcx e importalo qui: lo trasformiamo in una sessione.",
                              "Some watches (Huawei and a few brands) don't write to Apple Health. Export the workout from their app as a .gpx or .tcx file and import it here — we'll turn it into a session."),
        "guide.import_file": ("Importa file (.gpx / .tcx)", "Import file (.gpx / .tcx)"),
        "guide.import_ok":   ("Allenamento importato", "Workout imported"),
        "guide.import_fail": ("File non riconosciuto. Usa un .gpx o .tcx valido.", "Unrecognized file. Use a valid .gpx or .tcx."),
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
        "info.trimp.title": ("TRIMP", "TRIMP"),
        "info.trimp.body": (
            "Il TRIMP (Training Impulse) è una metrica scientifica che quantifica il carico di allenamento interno di una sessione. Combina quanto a lungo hai allenato con quanto forte hai spinto, usando la frequenza cardiaca come misura dell'intensità. Il risultato è un singolo punteggio che rappresenta lo stress fisiologico totale imposto al corpo, indipendentemente dal tipo di sport.\n\nPerché è utile: è il modo più preciso per confrontare sessioni di tipo diverso — una corsa leggera da 60 minuti e un interval training da 30 producono carichi molto diversi, e il TRIMP li cattura correttamente.\n\nRange per singola sessione:\n• Recupero / molto facile: 30–80\n• Moderato: 80–150\n• Duro: 150–250\n• Massimale: 250–500+\n\nRange settimanale (volume totale):\n• Principianti: 500–1.000\n• Intermedi: 1.000–1.500\n• Avanzati: 1.500–2.000\n• Élite: oltre 2.000\n\nCosa influenza il valore: la durata della sessione, la frequenza cardiaca media, e la frequenza cardiaca a riposo e massima dal tuo profilo. Senza questi dati il TRIMP non può essere calcolato.",
            "TRIMP (Training Impulse) is a scientific metric that quantifies the internal training load of a session. It combines how long you trained with how hard you pushed, using heart rate as a measure of intensity. The result is a single score representing total physiological stress placed on the body, regardless of sport type.\n\nWhy it matters: it is the most precise way to compare sessions of different types — a 60-minute easy run and a 30-minute interval session carry very different loads, and TRIMP captures that correctly.\n\nSingle-session ranges:\n• Recovery / very easy: 30–80\n• Moderate: 80–150\n• Hard: 150–250\n• Maximal: 250–500+\n\nWeekly ranges (total volume):\n• Beginners: 500–1,000\n• Intermediate: 1,000–1,500\n• Advanced: 1,500–2,000\n• Elite: over 2,000\n\nWhat influences the value: session duration, average heart rate, and resting and maximum heart rate from your profile. Without these inputs TRIMP cannot be calculated."),

        "info.acwr.title": ("Carico acuto:cronico (ACWR)", "Acute:Chronic load (ACWR)"),
        "info.acwr.body": (
            "Il rapporto Acuto:Cronico (ACWR) misura il tuo equilibrio tra allenamento recente e capacità di recupero abituale. Confronta quanto hai fatto nell'ultima settimana rispetto a ciò che il tuo corpo è abituato a gestire nelle ultime quattro settimane, usando una media mobile che dà più peso ai giorni recenti.\n\nPerché è utile: è uno degli indicatori più studiati per prevenire gli infortuni da sovraccarico. Aumentare troppo il volume in poco tempo — senza aver costruito la base — è la causa più comune di infortuni da overuse nello sport.\n\nRange:\n• Sotto 0,8 — stai allenandoti meno del solito (detraining)\n• 0,8–1,3 — zona ottimale: stress sufficiente senza eccessivo rischio\n• 1,3–1,5 — attenzione, rischio infortuni in aumento\n• Sopra 1,5 — zona di rischio elevato\n\nCosa influenza il valore: il carico TRIMP di ogni sessione nelle ultime sette e ventotto settimane. Più sessioni registri con durata e frequenza cardiaca, più l'indicatore è preciso.",
            "The Acute:Chronic Workload Ratio (ACWR) measures the balance between your recent training and your habitual recovery capacity. It compares what you have done in the last week against what your body is used to handling over the last four weeks, using a rolling average that weights recent days more heavily.\n\nWhy it matters: it is one of the most researched indicators for preventing overuse injuries. Increasing volume too quickly — without having built the necessary base — is the most common cause of overuse injuries in sport.\n\nRanges:\n• Below 0.8 — you are training less than usual (detraining)\n• 0.8–1.3 — optimal zone: enough stress without excessive risk\n• 1.3–1.5 — caution, injury risk rising\n• Above 1.5 — high-risk zone\n\nWhat influences the value: the TRIMP load from each session over the last seven and twenty-eight days. The more sessions you log with duration and heart rate, the more accurate this indicator becomes."),

        // --- Phase 3 metrics: labels, trend words, and "i" explanations --------
        "metric.muscle_vol":      ("Volume per muscolo", "Volume per muscle"),
        "metric.muscle_vol_hint": ("Serie allenanti questa settimana. ~10–20 per muscolo è un buon range per l'ipertrofia.",
                                   "Working sets this week. ~10–20 per muscle is a good hypertrophy range."),
        "metric.vitals":          ("Recupero · trend", "Recovery · trend"),
        "metric.fitness":         ("Fitness cardio", "Cardio fitness"),
        "metric.hr_zones":        ("Zone FC", "HR zones"),
        "metric.estimated":       ("Stima", "Est."),
        "trend.improving":        ("In miglioramento", "Improving"),
        "trend.declining":        ("In calo", "Declining"),
        "trend.stable":           ("Stabile", "Stable"),
        "trend.none":             ("—", "—"),
        "info.muscle_vol.title":  ("Volume per gruppo muscolare", "Volume per muscle group"),
        "info.muscle_vol.body": (
            "Conta le serie allenanti che hai registrato questa settimana per ogni gruppo muscolare. Una serie conta quando ha ripetizioni o una tenuta a tempo.\n\nPerché è utile: il volume settimanale per muscolo è uno dei fattori più correlati alla crescita muscolare. La ricerca indica circa 10–20 serie a settimana per gruppo come range produttivo per la maggior parte delle persone.\n\nIl gruppo muscolare di ogni esercizio viene dalla classificazione in libreria, che puoi modificare nell'editor del piano.",
            "Counts the working sets you logged this week for each muscle group. A set counts when it has reps or a timed hold.\n\nWhy it matters: weekly volume per muscle is one of the factors most correlated with muscle growth. Research points to roughly 10–20 sets per week per group as a productive range for most people.\n\nEach exercise's muscle group comes from its library classification, which you can edit in the plan editor."),
        "info.vitals.title":      ("Trend recupero (FC riposo / HRV)", "Recovery trend (resting HR / HRV)"),
        "info.vitals.body": (
            "Mostra la direzione, nelle ultime settimane, della tua frequenza cardiaca a riposo e della variabilità (HRV), calcolata con una regressione lineare sui dati di Apple Salute.\n\nCome leggerla: una FC a riposo che scende e un'HRV che sale indicano in genere un miglioramento della forma e del recupero. L'opposto, prolungato, può segnalare affaticamento, stress o malattia in arrivo.\n\nServe qualche settimana di dati perché il trend sia affidabile.",
            "Shows the direction, over the last few weeks, of your resting heart rate and heart-rate variability (HRV), computed with a linear regression on Apple Health data.\n\nHow to read it: a falling resting HR and a rising HRV usually indicate improving fitness and recovery. The opposite, if sustained, can flag accumulated fatigue, stress, or oncoming illness.\n\nIt needs a few weeks of data before the trend is reliable."),
        "info.fitness.title":     ("Fitness cardio (VO₂max e zone)", "Cardio fitness (VO₂max & zones)"),
        "info.fitness.body": (
            "VO₂max stima la tua capacità aerobica massima. Se Apple Salute ne registra uno misurato, usiamo quello; altrimenti lo stimiamo dalla tua corsa più intensa recente combinando velocità e frequenza cardiaca media (equazione ACSM corretta per la riserva di FC).\n\nLe zone FC dividono lo sforzo in cinque fasce calcolate con il metodo di Karvonen (% della riserva di frequenza cardiaca), dalla FC a riposo alla FC massima del tuo profilo. Usale per dosare l'intensità: Z1–Z2 per il fondo aerobico, Z4–Z5 per il lavoro ad alta intensità.",
            "VO₂max estimates your maximal aerobic capacity. If Apple Health has a measured value we use it; otherwise we estimate it from your most intense recent run, combining speed and average heart rate (ACSM equation adjusted for heart-rate reserve).\n\nThe HR zones split effort into five bands using the Karvonen method (% of heart-rate reserve), from your profile's resting HR to max HR. Use them to dose intensity: Z1–Z2 for aerobic base, Z4–Z5 for high-intensity work."),

        "info.readiness.title": ("Prontezza", "Readiness"),
        "info.readiness.body": (
            "La Prontezza è un punteggio composito 0–100 che riassume quanto il tuo sistema nervoso e corporeo è recuperato in questo momento. Raccoglie i segnali del mattino — variabilità della frequenza cardiaca, frequenza a riposo e qualità del sonno — e li confronta con la tua media personale degli ultimi due mesi. In questo modo il punteggio è calibrato su di te, non su valori universali.\n\nPerché è utile: ti aiuta a decidere se spingere forte, allenarsi a un'intensità moderata o recuperare. Usarlo insieme all'ACWR e al carico settimanale rende le decisioni di allenamento più intelligenti.\n\nInterpretazione:\n• 70–100 — recupero ottimale, puoi spingere\n• 50–70 — nella tua norma, allenamento normale\n• 30–50 — leggermente sotto la norma, intensità moderata\n• 0–30 — recupero incompleto, preferisci riposo o attività leggera\n\nCosa influenza il valore: l'HRV del mattino ha il peso maggiore, seguito dalla frequenza a riposo e dalle ore di sonno. Con un solo segnale disponibile il punteggio funziona comunque, ma con tutti e tre è molto più affidabile.",
            "Readiness is a composite score from 0 to 100 that summarises how well your nervous system and body have recovered at this moment. It collects your morning signals — heart rate variability, resting heart rate and sleep quality — and compares them to your personal average over the last two months. This way the score is calibrated to you, not to universal reference values.\n\nWhy it matters: it helps you decide whether to train hard, at moderate intensity, or to recover. Using it alongside ACWR and weekly load makes training decisions smarter and more data-driven.\n\nInterpretation:\n• 70–100 — optimal recovery, you can push hard\n• 50–70 — within your normal range, train as planned\n• 30–50 — slightly below normal, keep intensity moderate\n• 0–30 — incomplete recovery, prefer rest or light activity\n\nWhat influences the value: morning HRV carries the most weight, followed by resting heart rate and sleep hours. The score works with just one signal, but it becomes significantly more reliable with all three."),

        "info.load.title": ("Carico interno · 14 giorni", "Internal load · 14 days"),
        "info.load.body": (
            "Il Carico interno misura lo stress cumulativo che gli allenamenti degli ultimi 14 giorni hanno imposto al tuo corpo. Ogni sessione contribuisce con il proprio TRIMP — che dipende da durata e frequenza cardiaca media — e i valori si sommano nel tempo per mostrarti l'andamento del volume di allenamento.\n\nPerché è utile: vedere il carico nel tempo ti permette di riconoscere settimane di picco, periodi di scarico e progressioni troppo rapide prima che diventino infortuni.\n\nNon esiste un valore assoluto ottimale: dipende dal tuo sport, dal tuo livello e dalla fase di allenamento in cui sei. Usa il grafico per confrontare la settimana attuale con le precedenti e per valutare la coerenza del volume nel tempo.\n\nCosa influenza il valore: la durata di ogni sessione e la frequenza cardiaca media registrata. Sessioni senza questi dati non contribuiscono al carico.",
            "Internal load measures the cumulative stress that your training sessions over the last 14 days have placed on your body. Each session contributes its own TRIMP — which depends on duration and average heart rate — and the values accumulate over time to show you how your training volume is developing.\n\nWhy it matters: seeing load over time lets you recognise peak weeks, deload periods and progressions that are too rapid before they become injuries.\n\nThere is no universal optimal value: it depends on your sport, your level and the training phase you are in. Use the chart to compare the current week to previous ones and to evaluate consistency of volume over time.\n\nWhat influences the value: the duration of each session and the average heart rate recorded. Sessions without these data do not contribute to the load."),

        "info.monotony.title": ("Monotonia", "Monotony"),
        "info.monotony.body": (
            "La Monotonia misura quanto variato è il tuo allenamento durante la settimana. Confronta il carico medio giornaliero con la variabilità tra i giorni: se alleni sempre alla stessa intensità senza alternare sessioni dure e leggere, la monotonia sale.\n\nPerché è utile: un allenamento monotono affatica il sistema nervoso in modo cumulativo anche quando il volume totale non è eccessivo. Alternare giorni pesanti, medi e di recupero mantiene la monotonia bassa e riduce il rischio di burnout e sovraccarico.\n\nRange:\n• Sotto 1,5 — variazione sufficiente\n• 1,5–2,0 — attenzione, il programma è abbastanza ripetitivo\n• Sopra 2,0 — alta monotonia, considera di variare l'intensità\n\nCosa influenza il valore: la distribuzione del carico TRIMP tra i giorni della settimana. Più i valori giornalieri si assomigliano, più alta è la monotonia.",
            "Monotony measures how varied your training is during the week. It compares the average daily load against the variation between days: if you always train at the same intensity without alternating hard and easy sessions, monotony rises.\n\nWhy it matters: monotonous training fatigues the nervous system cumulatively even when total volume is not excessive. Alternating heavy, moderate and recovery days keeps monotony low and reduces the risk of burnout and overreaching.\n\nRanges:\n• Below 1.5 — sufficient variation\n• 1.5–2.0 — caution, the programme is fairly repetitive\n• Above 2.0 — high monotony, consider varying intensity\n\nWhat influences the value: the distribution of TRIMP load across the days of the week. The more similar the daily values, the higher the monotony."),

        "info.strain.title": ("Strain settimanale", "Weekly strain"),
        "info.strain.body": (
            "Lo Strain combina il volume totale di allenamento della settimana con la sua monotonia per dare un indice complessivo dello stress accumulato. Non è il semplice totale delle sessioni: due settimane con lo stesso carico totale ma distribuzioni diverse possono avere strain molto differenti.\n\nPerché è utile: è un indicatore precoce di sovraccarico. Valori elevati precedono spesso affaticamento profondo, calo della performance o malanni. Usalo per pianificare le settimane di scarico prima che il corpo te lo chieda da solo.\n\nNon esistono range assoluti validi per tutti: dipende dal tuo livello e dal tuo sport. Ciò che conta è monitorare il trend nel tempo — uno strain in costante aumento senza settimane di recupero è il segnale da tenere d'occhio.\n\nCosa influenza il valore: il carico TRIMP totale della settimana e la monotonia. Settimane ad alta monotonia amplificano lo strain anche con lo stesso volume.",
            "Strain combines the total training volume of the week with its monotony to give an overall index of accumulated stress. It is not a simple sum of sessions: two weeks with the same total load but different distributions can have very different strain values.\n\nWhy it matters: it is an early indicator of overreaching. High values often precede deep fatigue, performance drops or illness. Use it to plan deload weeks before your body forces one on you.\n\nThere are no absolute ranges valid for everyone: it depends on your level and your sport. What matters is monitoring the trend over time — a strain that keeps rising without recovery weeks is the signal to watch.\n\nWhat influences the value: total TRIMP load for the week and monotony. High-monotony weeks amplify strain even with the same volume."),

        "info.hrv.title": ("HRV — Variabilità della frequenza cardiaca", "HRV — Heart rate variability"),
        "info.hrv.body": (
            "L'HRV (variabilità della frequenza cardiaca) misura la variazione negli intervalli di tempo tra battiti consecutivi, espressa in millisecondi. Valori più alti indicano una maggiore attività del sistema nervoso parasimpatico, associata a un buon recupero, bassa fatica e buona salute cardiovascolare.\n\nPerché è utile: l'HRV è uno dei pochi marcatori fisiologici che cambia giorno per giorno in risposta ad allenamento, sonno, stress e salute generale. Monitorarlo nel tempo permette di individuare stati di sovraccarico prima che diventino infortuni o malanni.\n\nNon esistono valori assoluti ottimali: l'HRV varia enormemente tra individui. Un atleta può avere 80–100 ms, una persona sedentaria 20–30 ms, ed entrambi essere nella propria norma. Ciò che conta è il confronto con la tua media personale nel tempo, non un numero fisso.\n\nDa dove arriva: l'app importa automaticamente l'HRV da Apple Salute / dal tuo orologio (Apple Watch, Garmin, Polar…) e la usa per calcolare il punteggio di Prontezza. Non devi inserirla a mano.",
            "HRV (heart rate variability) measures the variation in time intervals between consecutive heartbeats, expressed in milliseconds. Higher values indicate greater parasympathetic nervous system activity, associated with good recovery, low fatigue and cardiovascular health.\n\nWhy it matters: HRV is one of the few physiological markers that changes day to day in response to training, sleep, stress and general health. Tracking it over time lets you spot overreaching before it becomes injury or illness.\n\nThere are no universal optimal values: HRV varies enormously between individuals. An athlete may have 80–100 ms, a sedentary person 20–30 ms, and both can be within their own normal range. What matters is comparing against your personal average over time, not a fixed number.\n\nWhere it comes from: the app automatically imports HRV from Apple Health / your watch (Apple Watch, Garmin, Polar…) and uses it to compute your Readiness score. You never have to type it in."),

        "info.bmi.title": ("BMI — Indice di massa corporea", "BMI — Body mass index"),
        "info.bmi.body": (
            "Il BMI è un indice che mette in relazione il peso corporeo con l'altezza per fornire una stima rapida della composizione corporea a livello di popolazione. È calcolato a partire dal peso e dall'altezza inseriti nel tuo profilo.\n\nPerché è utile: dà un riferimento rapido e standardizzato, usato globalmente in ambito sanitario per identificare persone a rischio di patologie legate al peso.\n\nCategorie standard (OMS):\n• Sotto 18,5 — sottopeso\n• 18,5–24,9 — normopeso\n• 25,0–29,9 — sovrappeso\n• 30,0 e oltre — obesità\n\nLimiti importanti: il BMI non distingue massa muscolare da massa grassa. Un atleta molto muscoloso può avere un BMI nella fascia sovrappeso pur avendo una composizione corporea eccellente. Viceversa, una persona con poco muscolo e molto grasso può risultare normopeso. Quando registri il grasso corporeo, l'app classifica la tua composizione in base a quello, che è un indicatore molto più preciso.",
            "BMI is an index that relates body weight to height to provide a quick population-level estimate of body composition. It is calculated from the weight and height entered in your profile.\n\nWhy it matters: it provides a quick, standardised reference used globally in healthcare to identify people at risk from weight-related conditions.\n\nStandard categories (WHO):\n• Below 18.5 — underweight\n• 18.5–24.9 — normal weight\n• 25.0–29.9 — overweight\n• 30.0 and above — obesity\n\nImportant limitations: BMI does not distinguish muscle mass from fat mass. A highly muscular athlete may have a BMI in the overweight range while having an excellent body composition. Conversely, someone with little muscle and high fat may appear normal weight. When you log body fat, the app classifies your composition based on that, which is a far more accurate indicator."),

        "info.bodyfat.title": ("Grasso corporeo", "Body fat"),
        "info.bodyfat.body": (
            "Il grasso corporeo è la percentuale del tuo peso totale composta da tessuto adiposo. È un indicatore molto più preciso del BMI per valutare la composizione corporea, perché distingue la massa grassa da quella magra (muscoli, ossa, organi).\n\nPerché è utile: monitorare il grasso corporeo nel tempo è il modo più diretto per capire se stai perdendo grasso mantenendo il muscolo, o stai semplicemente perdendo peso. È anche rilevante per la salute metabolica e cardiovascolare.\n\nRange di riferimento per adulti:\n• Donne: 20–32% normale, 14–20% atletico, sotto 14% essenziale\n• Uomini: 10–22% normale, 6–13% atletico, sotto 6% essenziale\n\nCome inserirlo: puoi misurarlo con plicometro, bilancia smart con bioimpedenza, o DEXA. In alternativa usa la stima Navy dell'app, calcolata dalle misure di collo, vita e (per le donne) fianchi. La stima Navy ha un margine di errore di ±3–4%, quindi usa il trend nel tempo piuttosto che il valore assoluto di una singola misurazione.",
            "Body fat is the percentage of your total weight made up of adipose tissue. It is a far more accurate indicator than BMI for evaluating body composition, because it distinguishes fat mass from lean mass (muscles, bones, organs).\n\nWhy it matters: tracking body fat over time is the most direct way to understand whether you are losing fat while preserving muscle, or simply losing weight. It is also relevant for metabolic and cardiovascular health.\n\nReference ranges for adults:\n• Women: 20–32% normal, 14–20% athletic, below 14% essential\n• Men: 10–22% normal, 6–13% athletic, below 6% essential\n\nHow to measure: you can use calipers, a smart scale with bioimpedance, or DEXA. Alternatively use the app's Navy estimate, calculated from neck, waist and (for women) hip measurements. The Navy estimate has a ±3–4% margin of error, so track the trend over time rather than relying on any single measurement."),

        "info.tdee.title": ("TDEE & metabolismo basale", "TDEE & basal metabolism"),
        "info.tdee.body": (
            "Il metabolismo basale (BMR) è la quantità di energia che il tuo corpo consuma in uno stato di completo riposo solo per mantenere le funzioni vitali — respirazione, circolazione, termoregolazione. È influenzato dal peso corporeo, dall'altezza, dall'età e dal sesso biologico.\n\nIl TDEE (Total Daily Energy Expenditure) è il tuo consumo calorico reale nell'arco della giornata, cioè il BMR moltiplicato per un fattore che tiene conto del tuo livello di attività fisica. È il numero di calorie attorno al quale ruota tutta la pianificazione nutrizionale: per perdere peso devi stare sotto, per aumentare sopra, per mantenere intorno a esso.\n\nPerché è utile: avere un punto di partenza preciso per le calorie giornaliere evita di affidarsi a stime generiche che spesso sottostimano o sovrastimano il consumo reale di una persona attiva.\n\nCosa influenza il valore: peso corporeo, altezza, età, sesso biologico e il livello di attività selezionato nel tuo profilo. Cambiando il livello di attività il TDEE cambia immediatamente.",
            "Basal metabolic rate (BMR) is the amount of energy your body uses at complete rest just to maintain vital functions — breathing, circulation, thermoregulation. It is influenced by body weight, height, age and biological sex.\n\nTDEE (Total Daily Energy Expenditure) is your actual daily calorie burn, meaning BMR multiplied by a factor that accounts for your physical activity level. It is the calorie number around which all nutritional planning revolves: to lose weight you need to stay below it, to gain weight above it, to maintain around it.\n\nWhy it matters: having an accurate calorie starting point avoids relying on generic estimates that often under- or overestimate the real consumption of an active person.\n\nWhat influences the value: body weight, height, age, biological sex and the activity level selected in your profile. Changing the activity level updates the TDEE immediately."),

        "info.macros.title": ("Macronutrienti", "Macronutrients"),
        "info.macros.body": (
            "I macronutrienti — proteine, carboidrati e grassi — sono le tre classi di nutrienti che forniscono energia e costruiscono il corpo. Ogni obiettivo nutrizionale (definizione, mantenimento, massa) richiede una distribuzione diversa tra i tre.\n\nPerché è utile: tracciare i macronutrienti separatamente è molto più efficace che contare solo le calorie, perché due diete con le stesse calorie ma macronutrienti diversi producono effetti molto diversi sulla composizione corporea e sulle performance.\n\nRange di riferimento per atleti e persone attive:\n• Proteine: 1,8–2,2 g per kg di peso corporeo. In fase di definizione si sale verso il limite superiore per proteggere la massa muscolare durante il deficit calorico.\n• Grassi: almeno 0,8–1,0 g per kg. I grassi sono essenziali per la produzione ormonale e l'assorbimento delle vitamine liposolubili. Non scendere troppo.\n• Carboidrati: riempiono le calorie rimanenti. Sono il carburante principale per l'allenamento ad alta intensità.\n\nCosa influenza i valori: il tuo peso corporeo, il TDEE, l'obiettivo selezionato (taglio calorico, mantenimento o surplus) e il livello di attività.",
            "Macronutrients — protein, carbohydrates and fat — are the three classes of nutrients that provide energy and build the body. Each nutritional goal (fat loss, maintenance, muscle gain) requires a different distribution among the three.\n\nWhy it matters: tracking macronutrients separately is far more effective than counting calories alone, because two diets with the same calories but different macros produce very different effects on body composition and performance.\n\nReference ranges for athletes and active people:\n• Protein: 1.8–2.2 g per kg of body weight. During a cut, aim toward the upper end to protect muscle mass in a caloric deficit.\n• Fat: at least 0.8–1.0 g per kg. Fats are essential for hormone production and absorption of fat-soluble vitamins. Do not go too low.\n• Carbohydrates: fill the remaining calories. They are the primary fuel for high-intensity training.\n\nWhat influences the values: your body weight, TDEE, selected goal (caloric cut, maintenance or surplus) and activity level."),

        "info.carbcycle.title": ("Ciclizzazione dei carboidrati", "Carb cycling"),
        "info.carbcycle.body": (
            "La ciclizzazione dei carboidrati consiste nel variare l'apporto di carboidrati in base ai giorni di allenamento, mantenendo invariata la media settimanale. Nei giorni in cui ti alleni i carboidrati aumentano per fornire energia e supportare il recupero muscolare; nei giorni di riposo diminuiscono.\n\nPerché è utile: permette di restare in deficit calorico settimanale per perdere grasso, senza però dover affrontare le sessioni di allenamento con poca energia. È particolarmente efficace per chi si allena 3–5 volte a settimana e vuole ottimizzare sia la composizione corporea che la performance.\n\nIl ciclo dell'app aumenta i carboidrati del 30% nei giorni ON e li riduce del 35% nei giorni OFF. Le calorie totali e le proteine restano costanti ogni giorno: solo i carboidrati e, in misura minore, i grassi variano.\n\nCosa influenza i valori: il tuo piano settimanale (giorni ON e OFF) e i macronutrienti calcolati dal tuo TDEE e obiettivo.",
            "Carb cycling means varying carbohydrate intake based on training days while keeping the weekly average unchanged. On training days carbs increase to provide energy and support muscle recovery; on rest days they decrease.\n\nWhy it matters: it allows you to stay in a weekly caloric deficit for fat loss, without having to face training sessions with low energy. It is particularly effective for people training 3–5 times per week who want to optimise both body composition and performance.\n\nThe app's cycle increases carbs by 30% on ON days and reduces them by 35% on OFF days. Total calories and protein stay constant every day — only carbohydrates and, to a lesser extent, fats vary.\n\nWhat influences the values: your weekly plan (ON and OFF days) and the macronutrients calculated from your TDEE and goal."),

        "info.lea.title": ("Disponibilità energetica (EA)", "Energy availability (EA)"),
        "info.lea.body": (
            "La disponibilità energetica (EA) misura quanta energia rimane disponibile per le funzioni corporee vitali dopo aver sottratto quella consumata durante l'allenamento. È calcolata come media degli ultimi 7 giorni e normalizzata sulla massa magra, rendendola comparabile tra persone di diversa corporatura.\n\nPerché è utile: è l'indicatore più diretto per identificare la Low Energy Availability (LEA), anche nota come RED-S (Relative Energy Deficiency in Sport). La LEA è spesso invisibile dall'esterno ma ha conseguenze gravi: alterazioni ormonali, riduzione della densità ossea, immunosoppressione, cali cognitivi e di performance. È frequente sia negli sport di resistenza che in chi è in deficit calorico prolungato.\n\nRange clinici:\n• Sopra 45 kcal/kg di massa magra/giorno — zona ottimale\n• 30–45 kcal/kg/giorno — zona di cautela sotto carichi elevati\n• Sotto 30 kcal/kg/giorno — rischio clinico di LEA/RED-S\n\nCosa influenza il valore: le calorie assunte ogni giorno, le calorie stimate bruciate durante l'allenamento e la tua massa magra. Senza tracciare la nutrizione e le sessioni questo dato non può essere calcolato.",
            "Energy availability (EA) measures how much energy remains for vital body functions after subtracting what was burned during training. It is calculated as a 7-day rolling average and normalised to lean body mass, making it comparable between people of different sizes.\n\nWhy it matters: it is the most direct indicator for identifying Low Energy Availability (LEA), also known as RED-S (Relative Energy Deficiency in Sport). LEA is often invisible from the outside but has serious consequences: hormonal disruption, reduced bone density, immune suppression, and cognitive and performance decline. It is common both in endurance sports and in anyone in prolonged caloric deficit.\n\nClinical ranges:\n• Above 45 kcal/kg lean mass/day — optimal zone\n• 30–45 kcal/kg/day — caution zone under high training loads\n• Below 30 kcal/kg/day — clinical risk of LEA/RED-S\n\nWhat influences the value: calories consumed each day, estimated calories burned during training and your lean body mass. Without tracking both nutrition and sessions this indicator cannot be calculated."),

        "info.trend.title": ("Trend del peso", "Weight trend"),
        "info.trend.body": (
            "Il trend del peso filtra il rumore delle fluttuazioni quotidiane — causate da idratazione, sale, glicogeno e digestione — per mostrare la variazione di peso reale e pulita nel tempo. Usa le tue ultime pesate per stimare a quale ritmo stai davvero guadagnando o perdendo peso.\n\nPerché è utile: il peso giornaliero da solo può essere fuorviante. Può salire di 1–2 kg in 24 ore per semplice ritenzione idrica anche se sei in deficit, oppure scendere rapidamente per poca acqua senza perdita reale di grasso. Il trend è l'unico dato su cui ha senso prendere decisioni nutrizionali.\n\nNon esiste un valore ottimale universale: dipende dal tuo obiettivo. In definizione un ritmo di −0,5/−1,0% del peso corporeo a settimana è considerato ottimale per preservare la massa muscolare. In massa +0,25/+0,5% a settimana minimizza l'accumulo di grasso.\n\nCosa influenza il valore: la frequenza e la consistenza delle pesate (ideale: mattina, a stomaco vuoto, ogni giorno o quasi) e il numero di misurazioni disponibili. Servono almeno 4 pesate per avere una stima affidabile.",
            "The weight trend filters out the noise of daily fluctuations — caused by hydration, salt, glycogen and digestion — to show your real, clean weight change over time. It uses your recent weigh-ins to estimate at what rate you are actually gaining or losing weight.\n\nWhy it matters: daily weight alone can be misleading. It can rise by 1–2 kg in 24 hours from simple water retention even when you are in a deficit, or drop rapidly from dehydration without any real fat loss. The trend is the only number on which it makes sense to base nutritional decisions.\n\nThere is no universal optimal value: it depends on your goal. On a cut, a rate of −0.5/−1.0% of body weight per week is considered optimal for preserving muscle mass. On a bulk, +0.25/+0.5% per week minimises fat gain.\n\nWhat influences the value: the frequency and consistency of your weigh-ins (ideal: morning, fasted, daily or near-daily) and the number of measurements available. At least 4 weigh-ins are needed for a reliable estimate."),

        "info.overload.title": ("Sovraccarico progressivo", "Progressive overload"),
        "info.overload.body": (
            "Il sovraccarico progressivo è il principio fondamentale dell'allenamento con i pesi: per continuare a crescere in forza e massa muscolare, il corpo deve essere esposto a uno stimolo via via maggiore nel tempo. Stagnare con gli stessi pesi e ripetizioni per settimane significa smettere di progredire.\n\nPerché è utile: l'app confronta la tua ultima sessione con il range di ripetizioni obiettivo per suggerirti il passo successivo in modo oggettivo, riducendo l'incertezza sulla gestione dei carichi.\n\nLogica di progressione:\n• Hai completato tutte le serie nel range alto o superiore → è il momento di aumentare il peso\n• Sei dentro il range ma non al limite → cerca di fare più ripetizioni mantenendo la tecnica\n• Sei sotto il range → mantieni il peso attuale e concentrati sulla qualità del movimento\n• Regressione significativa rispetto alla sessione precedente → considera uno scarico\n\nCosa influenza il suggerimento: il numero di serie, le ripetizioni completate e il peso usato nell'ultima sessione, confrontati con il range obiettivo impostato nel piano.",
            "Progressive overload is the fundamental principle of resistance training: to keep growing in strength and muscle mass, the body must be exposed to a progressively greater stimulus over time. Staying with the same weights and reps for weeks means stopping progress.\n\nWhy it matters: the app compares your last session against the target rep range to suggest the next step objectively, reducing uncertainty about load management.\n\nProgression logic:\n• You completed all sets at the top of the range or above → time to increase the weight\n• You are within the range but not at the limit → chase more reps while maintaining technique\n• You are below the range → keep the current weight and focus on movement quality\n• Significant regression compared to the previous session → consider a deload\n\nWhat influences the suggestion: the number of sets, reps completed and weight used in the last session, compared against the target range set in your plan."),

        "info.calories.title": ("Calorie bruciate", "Calories burned"),
        "info.calories.body": (
            "Le calorie bruciate mostrate nell'app si riferiscono all'energia attiva consumata durante la sessione di allenamento, escludendo la quota basale che il corpo brucerebbe comunque a riposo. Questo è lo stesso approccio usato dagli smartwatch sportivi, e rende il valore direttamente sommabile al TDEE senza doppio conteggio.\n\nPerché è utile: avere una stima del consumo calorico per sessione aiuta a calibrare l'apporto nutrizionale nei giorni di allenamento, a pianificare il deficit o il surplus, e a monitorare il volume di lavoro nel tempo.\n\nLa stima dipende dal tipo di sport: per la corsa e il ciclismo si usa la distanza percorsa insieme alla durata per stimare l'intensità; per gli sport di forza si tiene conto della durata, della frequenza cardiaca e del volume di lavoro. Se un dispositivo esterno (orologio o fascia cardio) fornisce un dato più preciso, puoi inserirlo manualmente per sovrascrivere la stima.\n\nCosa influenza il valore: il tipo di sport, la durata, la frequenza cardiaca media, la distanza (dove disponibile) e i dati del tuo profilo come peso e età.",
            "The calories burned shown in the app refer to the active energy consumed during the training session, excluding the basal portion the body would burn at rest anyway. This is the same approach used by sports smartwatches, and it makes the value directly addable to your TDEE without double-counting.\n\nWhy it matters: having a calorie estimate per session helps you calibrate nutritional intake on training days, plan your deficit or surplus, and monitor training volume over time.\n\nThe estimate depends on sport type: for running and cycling, distance and duration are combined to estimate intensity; for strength training, duration, heart rate and training volume are taken into account. If an external device (watch or chest strap) provides a more accurate number, you can enter it manually to override the estimate.\n\nWhat influences the value: sport type, duration, average heart rate, distance where available, and profile data such as weight and age."),

        "info.pace.title": ("Ritmo & velocità", "Pace & speed"),
        "info.pace.body": (
            "Il ritmo (per la corsa e il nuoto) e la velocità (per il ciclismo) sono calcolati automaticamente a partire dalla distanza e dalla durata che inserisci al termine della sessione. L'app sceglie automaticamente l'unità di misura più appropriata per ogni sport: km/h per il ciclismo, min/km per la corsa e la camminata, min/100m per il nuoto.\n\nPerché è utile: monitorare il ritmo nel tempo permette di misurare i miglioramenti di performance in modo oggettivo, indipendentemente dal tipo di percorso o dalle condizioni della sessione. Puoi confrontare sessioni diverse e vedere se a parità di sforzo (frequenza cardiaca simile) stai diventando più veloce.\n\nNon esiste un range ottimale universale: il ritmo dipende dal livello dell'atleta, dal tipo di sessione (facile, soglia, intervalli) e dall'obiettivo specifico. Confronta il tuo ritmo con le tue sessioni precedenti dello stesso tipo per valutare i progressi nel tempo.\n\nCome funziona: inserendo distanza e durata il valore viene calcolato e mostrato automaticamente. Se preferisci inserire direttamente il ritmo medio, puoi farlo sovrascrivendo il calcolo automatico.",
            "Pace (for running and swimming) and speed (for cycling) are calculated automatically from the distance and duration you enter at the end of a session. The app automatically selects the most appropriate unit for each sport: km/h for cycling, min/km for running and walking, min/100m for swimming.\n\nWhy it matters: tracking pace over time allows you to measure performance improvements objectively, regardless of the route type or session conditions. You can compare different sessions and see whether at the same effort level (similar heart rate) you are getting faster.\n\nThere is no universal optimal range: pace depends on the athlete's level, the type of session (easy, threshold, intervals) and the specific goal. Compare your pace against your previous sessions of the same type to evaluate progress over time.\n\nHow it works: enter distance and duration and the value is calculated and displayed automatically. If you prefer to enter the average pace directly, you can do so by overriding the automatic calculation."),

        "info.activity.title": ("Livello di attività", "Activity level"),
        "info.activity.body": (
            "Il livello di attività è un moltiplicatore che viene applicato al metabolismo basale per stimare il consumo calorico totale giornaliero (TDEE). Tiene conto del fatto che una persona che si allena 5 volte a settimana brucia molte più calorie di una persona sedentaria, anche a parità di corporatura.\n\nPerché è utile: scegliere il livello corretto è il passo più importante per ottenere un TDEE accurato. Un errore qui si traduce in obiettivi calorici troppo bassi (che causano perdita di muscolo e affaticamento cronico) o troppo alti (che rendono impossibile il taglio calorico).\n\nLivelli disponibili:\n• Sedentario — lavoro d'ufficio, poco o nessun movimento extra\n• Leggero — 1–2 sessioni di allenamento a settimana\n• Moderato — 3–4 sessioni a settimana\n• Alto — 5–6 sessioni a settimana\n• Atleta — 6–7 sessioni a settimana, o lavoro fisico intenso, o doppie sedute\n\nCosa influenza il valore: il livello selezionato e il metabolismo basale calcolato dal tuo profilo. Puoi cambiarlo in qualsiasi momento dal tuo profilo.",
            "The activity level is a multiplier applied to your basal metabolic rate to estimate your total daily calorie expenditure (TDEE). It accounts for the fact that a person training five times per week burns far more calories than a sedentary person of the same size.\n\nWhy it matters: choosing the correct level is the most important step for getting an accurate TDEE. An error here translates into calorie targets that are too low (causing muscle loss and chronic fatigue) or too high (making a caloric cut impossible).\n\nAvailable levels:\n• Sedentary — desk job, little or no extra movement\n• Light — 1–2 training sessions per week\n• Moderate — 3–4 sessions per week\n• High — 5–6 sessions per week\n• Athlete — 6–7 sessions per week, or physically demanding job, or twice-daily sessions\n\nWhat influences the value: the selected level and the basal metabolic rate calculated from your profile. You can change it at any time from your profile."),

        "info.srpe.title": ("sRPE — Carico percepito", "sRPE — Perceived load"),
        "info.srpe.body": (
            "L'sRPE (session Rate of Perceived Exertion) combina la durata della sessione con quanto ti sei sentito sotto sforzo, su una scala da 1 a 10. È il metodo più semplice per quantificare il carico interno di qualsiasi tipo di allenamento, anche senza un cardiofrequenzimetro.\n\nPerché è utile: permette di stimare il carico di sessioni per cui non hai dati di frequenza cardiaca — allenamenti con i pesi, yoga, sport di squadra, sessioni all'aperto. È meno preciso del TRIMP ma universalmente applicabile.\n\nScala RPE (Borg CR10):\n• 1–2 — sforzo molto lieve (passeggiata)\n• 3–4 — moderato (puoi parlare comodamente)\n• 5–6 — impegnativo (parli a fatica)\n• 7–8 — molto duro (poche parole per volta)\n• 9–10 — massimale (impossibile parlare)\n\nNella versione attuale dell'app l'sRPE è usato principalmente per i dati storici. Il carico delle sessioni nuove si basa sul TRIMP (frequenza cardiaca media), che è più preciso quando i dati cardio sono disponibili.",
            "sRPE (session Rate of Perceived Exertion) combines session duration with how hard you felt you were working, on a scale from 1 to 10. It is the simplest method to quantify the internal load of any type of training, even without a heart rate monitor.\n\nWhy it matters: it allows you to estimate the load of sessions for which you have no heart rate data — weight training, yoga, team sports, outdoor sessions. It is less precise than TRIMP but universally applicable.\n\nRPE scale (Borg CR10):\n• 1–2 — very light effort (walking)\n• 3–4 — moderate (can speak comfortably)\n• 5–6 — challenging (speaking is effortful)\n• 7–8 — very hard (only a few words at a time)\n• 9–10 — maximal (impossible to speak)\n\nIn the current version of the app sRPE is used primarily for historical data. The load of new sessions is based on TRIMP (average heart rate), which is more precise when cardiac data is available."),

        "info.dfa.title": ("DFA-alpha1 (soglia aerobica)", "DFA-alpha1 (aerobic threshold)"),
        "info.dfa.body": (
            "Il DFA-alpha1 è un indice avanzato che analizza la natura frattale degli intervalli tra i battiti cardiaci. Quando l'intensità dell'esercizio sale e si avvicina alla soglia aerobica (la prima soglia di lattato), il pattern dei battiti cardiaci perde progressivamente la sua complessità frattale. Questo cambiamento è misurabile e permette di individuare la soglia aerobica in tempo reale durante lo sforzo, senza bisogno di un test in laboratorio.\n\nPerché è utile: la soglia aerobica è uno dei marker di fitness più importanti per gli sport di resistenza. Sapere quando la superi durante l'allenamento permette di ottimizzare la distribuzione dell'intensità, una delle strategie più efficaci per migliorare la performance a lungo termine.\n\nRange:\n• DFA-alpha1 sopra 0,75 — intensità sotto soglia aerobica\n• DFA-alpha1 intorno a 0,75 — zona di soglia aerobica\n• DFA-alpha1 sotto 0,75 — intensità sopra soglia aerobica\n\nQuesta funzione richiede un flusso continuo di dati battito-battito da una fascia cardio Bluetooth (non è supportata dagli smartwatch ottici). È in arrivo con il supporto BLE dell'app.",
            "DFA-alpha1 is an advanced index that analyses the fractal nature of the intervals between heartbeats. When exercise intensity rises and approaches the aerobic threshold (the first lactate threshold), the heartbeat pattern progressively loses its fractal complexity. This change is measurable and allows the aerobic threshold to be identified in real time during exercise, without the need for a laboratory test.\n\nWhy it matters: the aerobic threshold is one of the most important fitness markers for endurance sports. Knowing when you cross it during training allows you to optimise intensity distribution, one of the most effective strategies for improving long-term performance.\n\nRanges:\n• DFA-alpha1 above 0.75 — intensity below the aerobic threshold\n• DFA-alpha1 around 0.75 — aerobic threshold zone\n• DFA-alpha1 below 0.75 — intensity above the aerobic threshold\n\nThis feature requires a continuous beat-to-beat data stream from a Bluetooth chest strap (optical smartwatches are not supported). It is coming with the app's BLE support."),

        "info.weekplan.title": ("Piano settimanale", "Weekly plan"),
        "info.weekplan.body": (
            "Il piano settimanale ti permette di assegnare uno specifico allenamento, attività cardio o giorno di riposo a ciascun giorno della settimana. Una volta configurato, l'app sa già cosa ti aspetta il giorno successivo e ti mostra il prossimo allenamento in Home.\n\nPerché è utile: avere una struttura fissa riduce il carico decisionale quotidiano e migliora la consistenza — uno dei fattori più importanti per i progressi a lungo termine. Sapere in anticipo cosa si farà il lunedì, il mercoledì e il venerdì elimina il rischio di saltare allenamenti per indecisione.\n\nSe non imposti un piano, l'app ruota automaticamente tra i tuoi giorni di allenamento in ordine. Lasciare il piano vuoto fa tornare alla rotazione automatica.\n\nPuoi modificare il piano in qualsiasi momento senza perdere nessun dato storico.",
            "The weekly plan lets you assign a specific workout, cardio activity or rest day to each day of the week. Once configured, the app already knows what awaits you the next day and shows the upcoming workout on the Home screen.\n\nWhy it matters: having a fixed structure reduces daily decision fatigue and improves consistency — one of the most important factors for long-term progress. Knowing in advance what you will do on Monday, Wednesday and Friday eliminates the risk of skipping sessions from indecision.\n\nIf you do not set a plan, the app automatically rotates through your training days in order. Leaving the plan empty returns to automatic rotation.\n\nYou can modify the plan at any time without losing any historical data."),

        "info.adherence.title": ("Costanza & TDEE adattivo", "Adherence & adaptive TDEE"),
        "info.adherence.body": (
            "Il TDEE adattivo è una stima del tuo consumo calorico reale calcolata direttamente dai tuoi dati registrati, invece di basarsi solo su formule generiche. Quando tracci sia l'alimentazione che il peso per un numero sufficiente di giorni, l'app confronta la variazione di peso osservata con l'apporto calorico medio, tenendo conto anche dei passi e del volume di allenamento, per stimare quante calorie stai davvero bruciando ogni giorno.\n\nPerché è utile: le formule standard come il TDEE calcolato dal moltiplicatore di attività sono medie di popolazione che possono discostarsi significativamente dal tuo metabolismo reale. Il TDEE adattivo apprende dal tuo corpo specifico e migliora nel tempo.\n\nCosa influenza la stima: la frequenza e la consistenza con cui registri peso, calorie, passi e sessioni di allenamento. Tracciare in modo intermittente riduce l'affidabilità della stima — più sei costante, più il valore è preciso e utile.\n\nLa costanza è anche il fattore più predittivo del raggiungimento degli obiettivi a lungo termine, indipendentemente da qualsiasi metrica.",
            "The adaptive TDEE is an estimate of your real calorie expenditure calculated directly from your logged data, instead of relying solely on generic formulas. When you track both nutrition and weight for a sufficient number of days, the app compares the observed weight change with average caloric intake, also accounting for steps and training volume, to estimate how many calories you are actually burning each day.\n\nWhy it matters: standard formulas like the activity-multiplier TDEE are population averages that can differ significantly from your actual metabolism. The adaptive TDEE learns from your specific body and improves over time.\n\nWhat influences the estimate: the frequency and consistency with which you log weight, calories, steps and training sessions. Intermittent tracking reduces the reliability of the estimate — the more consistent you are, the more accurate and useful the value becomes.\n\nConsistency is also the single most predictive factor for achieving long-term goals, regardless of any metric."),

        "info.steps.title": ("Passi giornalieri", "Daily steps"),
        "info.steps.body": (
            "I passi giornalieri sono una misura dell'attività fisica non strutturata — tutto il movimento che fai al di fuori dell'allenamento formale: camminare, salire le scale, muoversi in casa o al lavoro. Questa componente è chiamata NEAT (Non-Exercise Activity Thermogenesis) e può incidere sul consumo calorico giornaliero totale anche più dell'allenamento stesso.\n\nPerché è utile: molte persone si concentrano esclusivamente sulle sessioni di allenamento trascurando il resto della giornata. Tenere traccia dei passi aiuta a mantenere un livello di attività complessiva sufficiente, specialmente in periodi di allenamento ridotto, e migliora la precisione del TDEE adattivo.\n\nRange di riferimento:\n• Sotto 5.000 passi/giorno — livello molto sedentario\n• 5.000–7.500 — poco attivo\n• 7.500–10.000 — moderatamente attivo\n• Sopra 10.000 — attivo\n\nQuesti range sono indicativi: il valore ottimale dipende dal tuo stile di vita e da quanto ti alleni. Un atleta che si allena intensamente potrebbe avere meno bisogno di camminare molto; una persona sedentaria che aumenta i passi può ottenere benefici metabolici significativi.\n\nI passi vengono importati automaticamente da Apple Salute se l'integrazione è attiva, oppure puoi inserirli manualmente.",
            "Daily steps are a measure of unstructured physical activity — all the movement you do outside of formal training: walking, climbing stairs, moving around at home or at work. This component is called NEAT (Non-Exercise Activity Thermogenesis) and can contribute to total daily calorie expenditure even more than training itself.\n\nWhy it matters: many people focus exclusively on training sessions while neglecting the rest of the day. Tracking steps helps maintain a sufficient overall activity level, especially during periods of reduced training, and improves the accuracy of the adaptive TDEE.\n\nReference ranges:\n• Below 5,000 steps/day — very sedentary\n• 5,000–7,500 — lightly active\n• 7,500–10,000 — moderately active\n• Above 10,000 — active\n\nThese ranges are indicative: the optimal value depends on your lifestyle and how much you train. An athlete training intensely may need fewer steps; a sedentary person who increases daily steps can achieve significant metabolic benefits.\n\nSteps are imported automatically from Apple Health if the integration is active, or you can enter them manually."),

        "info.sleep.title": ("Sonno & recupero", "Sleep & recovery"),
        "info.sleep.body": (
            "Il punteggio del sonno rappresenta la qualità complessiva della notte, tenendo conto sia della durata che della qualità percepita del riposo. Il sonno è il fattore di recupero più importante in assoluto: è durante le ore di sonno che avvengono la sintesi proteica muscolare, il ripristino ormonale, la consolidazione della memoria motoria e la rigenerazione del sistema nervoso.\n\nPerché è utile: la qualità del sonno influenza quasi ogni altro indicatore monitorato nell'app — la prontezza, la variabilità della frequenza cardiaca, la performance negli allenamenti e la composizione corporea nel tempo. Capire come il sonno si correla con gli altri dati aiuta a prendere decisioni migliori su quando spingere e quando recuperare.\n\nLe ore di sonno vengono importate automaticamente da Apple Salute se l'integrazione è attiva (Apple Watch o app di tracking del sonno). Il punteggio soggettivo 0–100 puoi inserirlo manualmente per catturare la qualità percepita anche quando non hai sensori.\n\nNon esiste un punteggio ottimale fisso: confronta il tuo valore con la tua media personale e osserva come le notti migliori si riflettono sugli allenamenti successivi.",
            "The sleep score represents the overall quality of the night, taking into account both duration and perceived quality of rest. Sleep is by far the most important recovery factor: it is during sleep hours that muscle protein synthesis, hormonal restoration, motor memory consolidation and nervous system regeneration occur.\n\nWhy it matters: sleep quality influences almost every other indicator monitored in the app — readiness, heart rate variability, training performance and body composition over time. Understanding how sleep correlates with other data helps you make better decisions about when to push and when to recover.\n\nSleep hours are imported automatically from Apple Health if the integration is active (Apple Watch or sleep tracking apps). The subjective 0–100 score can be entered manually to capture perceived quality even when you have no sensors.\n\nThere is no fixed optimal score: compare your value against your personal average and observe how better nights reflect on subsequent training sessions."),

        "info.goal.title": ("Obiettivo & progressi", "Goal & progress"),
        "info.goal.body": (
            "L'obiettivo è il peso corporeo o la percentuale di grasso che vuoi raggiungere. Lo imposti una volta e rimane fisso come riferimento stabile, indipendentemente dalle fluttuazioni quotidiane del peso. La barra di progresso mostra quanto sei avanzato dal tuo punto di partenza verso l'obiettivo.\n\nPerché è utile: avere un obiettivo esplicito e visualizzato consente di valutare i progressi in modo oggettivo, senza farsi ingannare dalle variazioni giornaliere o settimanali del peso. Dà anche un contesto alle raccomandazioni nutrizionali e al ritmo di variazione suggerito.\n\nCome funziona:\n• Il punto di partenza è il peso iniziale registrato al momento dell'impostazione dell'obiettivo\n• La barra riflette la posizione attuale tra il punto di partenza e l'obiettivo\n• L'obiettivo rimane fisso finché non lo modifichi manualmente con il pulsante 'Cambia obiettivo'\n\nPuoi modificare l'obiettivo in qualsiasi momento. Cambierà anche la direzione suggerita per la nutrizione e il ritmo di progresso atteso.",
            "The goal is the body weight or body fat percentage you want to reach. You set it once and it remains fixed as a stable reference, regardless of daily weight fluctuations. The progress bar shows how far you have come from your starting point toward the goal.\n\nWhy it matters: having an explicit, visualised goal allows you to evaluate progress objectively, without being misled by daily or weekly weight variations. It also gives context to nutritional recommendations and the suggested rate of change.\n\nHow it works:\n• The starting point is the initial weight recorded when the goal was set\n• The bar reflects your current position between the starting point and the goal\n• The goal stays fixed until you change it manually with the 'Change goal' button\n\nYou can change the goal at any time. It will also update the suggested nutritional direction and expected progress rate."),

        "info.streak.title": ("Streak di allenamento", "Training streak"),
        "info.streak.body": (
            "La streak conta il numero di giorni consecutivi in cui hai registrato almeno un check-in del peso o una sessione di allenamento. È un indicatore della tua consistenza nel tempo, che è il fattore più importante per i progressi a lungo termine indipendentemente dall'obiettivo.\n\nPerché è utile: la consistenza batte quasi sempre l'intensità sporadica. Una persona che si allena 3 volte a settimana ogni settimana per un anno ottiene risultati nettamente superiori a chi si allena intensamente per 2 mesi e poi si ferma. La streak rende questa consistenza visibile e misurabile.\n\nCome funziona:\n• Si incrementa ogni giorno in cui registri almeno un check-in o una sessione\n• Rimane attiva per tutto il giorno corrente — non si azzera finché la giornata non è finita\n• Si interrompe solo quando un giorno intero passa senza nessuna registrazione\n\nNon esiste un numero magico di giorni da raggiungere: l'obiettivo è che il valore cresca nel tempo. Se si interrompe, l'importante è ricominciare subito — anche una sessione breve o un semplice check-in del peso conta.",
            "The streak counts the number of consecutive days in which you logged at least one weight check-in or a training session. It is an indicator of your consistency over time, which is the single most important factor for long-term progress regardless of goal.\n\nWhy it matters: consistency almost always beats sporadic intensity. A person who trains three times a week every week for a year achieves far better results than someone who trains intensely for two months and then stops. The streak makes this consistency visible and measurable.\n\nHow it works:\n• It increments every day you log at least one check-in or session\n• It stays alive for the entire current day — it does not reset before the day is over\n• It breaks only when a full day passes with nothing logged\n\nThere is no magic number of days to reach: the goal is for the value to grow over time. If it breaks, the important thing is to restart immediately — even a short session or a simple weight check-in counts."),

        "info.sessions.title": ("Sessioni totali", "Total sessions"),
        "info.sessions.body": (
            "Il contatore delle sessioni totali registra tutte le sessioni di forza e di cardio salvate dall'inizio dell'utilizzo dell'app. Ogni sessione completata e salvata contribuisce al totale, indipendentemente dalla durata o dall'intensità.\n\nPerché è utile: è una misura diretta del volume di lavoro accumulato nel tempo. Un numero in crescita costante è la conferma più semplice e inequivocabile che ti stai allenando con regolarità.\n\nNon esiste un numero ottimale: dipende dalla frequenza di allenamento settimanale e da quanto tempo usi l'app. Ciò che conta è la tendenza nel tempo — un plateau prolungato nel contatore può indicare un periodo di pausa non intenzionale.\n\nTutte le sessioni rimangono accessibili dalla sezione storico e dal calendario. Puoi modificarle o completarle in qualsiasi momento dopo averle salvate.",
            "The total sessions counter records all strength and cardio sessions saved since you started using the app. Every completed and saved session contributes to the total, regardless of duration or intensity.\n\nWhy it matters: it is a direct measure of the work volume accumulated over time. A steadily growing number is the simplest and most unambiguous confirmation that you are training regularly.\n\nThere is no optimal number: it depends on your weekly training frequency and how long you have been using the app. What matters is the trend over time — a prolonged plateau in the counter may indicate an unintentional rest period.\n\nAll sessions remain accessible from the history section and the calendar. You can edit or complete them at any time after saving."),

        // --- Day logging / rest / recommended fields ------------------------
        "home.tap_to_log":   ("Tocca un giorno per registrare", "Tap a day to log"),
        "day.title":         ("Registra giornata", "Log day"),
        "day.hint":          ("Scegli cosa hai fatto in questo giorno: un allenamento di forza, un'attività cardio o riposo. I dati partono dall'ultima volta e restano modificabili.",
                              "Choose what you did on this day: a strength workout, a cardio activity or rest. Data starts from last time and stays editable."),
        "day.logged":        ("Allenamenti di questo giorno", "Workouts on this day"),
        "day.mark_rest":     ("Segna come riposo", "Mark as rest"),
        "day.clear_rest":    ("Rimuovi riposo", "Remove rest"),
        "day.import_health": ("Importa da Apple Salute", "Import from Apple Health"),
        "day.health_loading": ("Cerco allenamenti in Apple Salute…", "Checking Apple Health…"),
        "day.health_none":   ("Nessun allenamento da importare per questo giorno. Assicurati che l'app abbia accesso ad Apple Salute (Impostazioni › Privacy › Salute).",
                              "No workouts to import for this day. Make sure the app has access to Apple Health (Settings › Privacy › Health)."),
        "day.health_recheck": ("Ricontrolla", "Re-check"),
        "day.health_unavailable": ("Apple Salute non è disponibile su questo dispositivo.", "Apple Health isn't available on this device."),
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

        // --- Exercise library -----------------------------------------------
        "ex.library":         ("Libreria esercizi", "Exercise library"),

        // --- Per-set effort tracking ----------------------------------------
        "wk.effort":          ("Sforzo", "Effort"),
        "wk.effort.off":      ("—", "—"),
        "wk.effort.rir":      ("RIR", "RIR"),
        "wk.effort.rpe":      ("RPE", "RPE"),
        "wk.effort.fail":     ("FAIL", "FAIL"),
        "wk.effort.hint":     ("RIR = ripetizioni prima del cedimento · RPE = sforzo 1-10 · FAIL = cedimento raggiunto",
                               "RIR = reps before failure · RPE = perceived effort 1-10 · FAIL = hit failure"),

        // --- Bodyweight exercise --------------------------------------------
        "wk.bodyweight":      ("Corpo libero", "Bodyweight"),
        "wk.bw_hint":         ("Il campo peso è il carico aggiunto. 0 = solo peso corporeo, negativo = macchina assistita.",
                               "Weight field is added load. 0 = pure bodyweight, negative = machine-assisted."),

        // --- Food sort options ----------------------------------------------
        "food.sort":          ("Ordina", "Sort"),
        "food.sort.recent":   ("Recenti", "Recent"),
        "food.sort.alpha":    ("A-Z", "A-Z"),
        "food.sort.kcal":     ("Kcal/100g", "Kcal/100g"),
        "food.sort.ratio":    ("Kcal:Prot", "Kcal:Prot"),

        // --- Stats / exercise search ----------------------------------------
        "st.search_ex":       ("Cerca esercizio", "Search exercise"),
        "st.all_exercises":   ("Tutti gli esercizi", "All exercises"),

        // --- v8.1: recovery inputs, daily-metric history --------------------
        "home.wake_hr":       ("FC riposo/risveglio", "Resting/waking HR"),
        "home.health_autofill": ("Compilato da Apple Salute quando disponibile · modificabile",
                                 "Filled from Apple Health when available · editable"),
        "body.sleep_hr":      ("FC nel sonno", "Sleeping HR"),
        "body.hips":          ("Fianchi", "Hips"),
        "body.navy_need_hips": ("Aggiungi la misura dei fianchi per stimare il grasso (formula femminile Navy).",
                                "Add your hip measurement to estimate body fat (women's Navy formula)."),
        "st.steps_time":      ("Passi", "Steps"),
        "st.hr_time":         ("Frequenza cardiaca", "Heart rate"),
        "st.hrv_time":        ("HRV", "HRV"),
        "st.rest_hr":         ("Riposo", "Resting"),
        "st.sleep_hr":        ("Sonno", "Sleep"),

        // --- v8.1: readiness factor chips -----------------------------------
        "load.from":          ("Da", "From"),
        "load.sig.hrv":       ("HRV", "HRV"),
        "load.sig.hr":        ("FC", "HR"),
        "load.sig.sleep":     ("Sonno", "Sleep"),

        // --- v8.1: Apple Health categories ----------------------------------
        "hk.choose":          ("Cosa importare", "What to import"),
        "hk.import_workouts": ("Importa allenamenti passati", "Import past workouts"),
        "hk.import_workouts_hint": ("Importa gli allenamenti già registrati in Apple Salute — quelli dell'app Allenamento di Apple e di altri orologi (Garmin, ecc.). L'importazione non è ancora pienamente ottimizzata: alcuni dati potrebbero non convertirsi alla perfezione.",
                                    "Import workouts already recorded in Apple Health — both Apple's own Workout app and other watches (Garmin, etc.). Importing isn't fully optimized yet, so some data may not convert perfectly."),
        "hk.from_health":     ("Da Apple Salute", "From Apple Health"),
        "hk.cat.steps":       ("Passi", "Steps"),
        "hk.cat.restHR":      ("FC a riposo", "Resting heart rate"),
        "hk.cat.hrv":         ("HRV (SDNN)", "HRV (SDNN)"),
        "hk.cat.sleep":       ("Sonno", "Sleep"),
        "hk.cat.sleepHR":     ("FC nel sonno", "Sleeping heart rate"),
        "hk.cat.activeKcal":  ("Energia attiva", "Active energy"),
        "hk.cat.exerciseMin": ("Minuti di attività", "Exercise minutes"),

        // --- v8.1: Apple Watch live sync ------------------------------------
        "wk.start":           ("Inizia", "Start"),
        "wk.workout_live":    ("Allenamento in corso", "Workout in progress"),
        "wk.watch_live":      ("In diretta da Apple Watch", "Live from Apple Watch"),
        "wk.watch_synced":    ("Allenamento sincronizzato dall'orologio", "Workout synced from your watch"),
        "wk.started_on_watch": ("Avviato su Apple Watch", "Started on Apple Watch"),
        "wk.watch_unreachable": ("Apple Watch non raggiungibile", "Apple Watch not reachable"),

        // --- v8.1: muscle groups + exercise families ------------------------
        "mg.chest":           ("Petto", "Chest"),
        "mg.back":            ("Schiena", "Back"),
        "mg.legs":            ("Gambe", "Legs"),
        "mg.shoulders":       ("Spalle", "Shoulders"),
        "mg.arms":            ("Braccia", "Arms"),
        "mg.core":            ("Core", "Core"),
        "mg.fullbody":        ("Tutto il corpo", "Full body"),
        "mg.cardio":          ("Cardio", "Cardio"),
        "mg.other":           ("Altro", "Other"),
        "st.variants":        ("varianti", "variants"),
        "st.edit_family":     ("Famiglia esercizio", "Exercise family"),
        "st.family_hint":     ("Le varianti che condividono la stessa famiglia hanno una sola linea di progressi. Cambia famiglia per unirle o separarle.",
                               "Variants sharing a family share one progress line. Change the family to merge or split them."),
        "st.family":          ("Famiglia (movimento base)", "Family (base movement)"),
        "st.muscle":          ("Muscolo", "Muscle"),

        // --- Manage exercises: rename / merge similar / delete --------------
        "st.manage":          ("Gestisci", "Manage"),
        "st.manage_hint":     ("Unisci esercizi salvati con nomi simili, rinominane uno in tutto lo storico, o cancellalo del tutto. Le azioni riscrivono allenamenti, schede e libreria.",
                               "Merge exercises saved under similar names, rename one across the whole history, or delete it. Actions rewrite workouts, plans and the library."),
        "st.all_exercises":   ("Tutti gli esercizi", "All exercises"),
        "st.dupes":           ("Possibili duplicati", "Possible duplicates"),
        "st.variants_similar":("nomi simili", "similar names"),
        "st.merge":           ("Unisci", "Merge"),
        "st.merge_into":      ("Unisci negli altri", "Merge the rest into it"),
        "st.merge_pick":      ("Scegli il nome da mantenere. Gli altri verranno uniti in questo, con tutta la loro cronologia.",
                               "Pick the name to keep. The others are merged into it, with all their history."),
        "st.merge_warn":      ("Questo nome esiste già: gli storici verranno uniti.",
                               "This name already exists: the histories will be merged."),
        "st.merged":          ("Esercizi uniti", "Exercises merged"),
        "st.rename":          ("Rinomina", "Rename"),
        "st.rename_from":     ("Rinomina", "Rename"),
        "st.renamed":         ("Esercizio rinominato", "Exercise renamed"),
        "st.delete":          ("Cancella", "Delete"),
        "st.delete_q":        ("Cancellare questo esercizio?", "Delete this exercise?"),
        "st.deleted":         ("Esercizio cancellato", "Exercise deleted"),
        "st.sessions_affected":("sessioni interessate", "sessions affected"),
        "st.session_one":     ("sessione", "session"),
        "st.sessions_n":      ("sessioni", "sessions"),

        // --- v8.2: sleep card, steps card, VO2 max, variant picker -----------
        "body.sleep":         ("Sonno", "Sleep"),
        "hk.cat.vo2max":      ("VO₂ max", "VO₂ max"),
        "st.vo2_time":        ("VO₂ max", "VO₂ max"),
        "st.hrv_sdnn":        ("SDNN", "SDNN"),
        "st.sort.sessions":   ("Sessioni", "Sessions"),
        "st.all_variants":    ("Tutte", "All"),
        "wk.recreate_plan":   ("Ricrea come scheda", "Recreate as plan"),

        // --- Food brand (v10) -----------------------------------------------
        "food.brand":         ("Marca", "Brand"),

        // --- Recipe (v10) ---------------------------------------------------
        "recipe.title":       ("Ricette", "Recipes"),
        "recipe.new":         ("Nuova ricetta", "New recipe"),
        "recipe.edit":        ("Modifica ricetta", "Edit recipe"),
        "recipe.none":        ("Nessuna ricetta salvata. Creane una.", "No saved recipes. Create one."),
        "recipe.name_placeholder": ("es. Pasta al pesto", "e.g. Pasta with pesto"),
        "recipe.input_mode":  ("Modalità di creazione", "Creation mode"),
        "recipe.manual":      ("Manuale", "Manual"),
        "recipe.from_ingredients": ("Da alimenti", "From foods"),
        "recipe.per_serving_toggle": ("Valori totali ricetta + porzioni", "Total recipe values + servings"),
        "recipe.per_serving_hint": ("Inserisci i valori totali e quante porzioni fa la ricetta", "Enter total values and how many servings the recipe makes"),
        "recipe.servings":    ("Porzioni", "Servings"),
        "recipe.total_macros_label": ("Valori totali ricetta", "Total recipe values"),
        "recipe.ingredients": ("Ingredienti", "Ingredients"),
        "recipe.add_ingredient": ("Aggiungi ingrediente", "Add ingredient"),
        "recipe.serving":     ("porzione", "serving"),
        "recipe.servings_short": ("porz", "srv"),

        // --- Sleep manual entry (v10) ----------------------------------------
        "body.sleep_manual":  ("Inserimento manuale", "Manual entry"),
        "body.sleep_hours":   ("Ore di sonno", "Sleep hours"),
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
