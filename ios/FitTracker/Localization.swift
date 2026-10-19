import Foundation

// MARK: - Lightweight runtime localization (IT / EN)
// The user can switch language at any time. `L.lang` is kept in sync with
// prefs.language by the Store; because views observe the Store, flipping the
// language re-renders the whole tree and every L.t(...) call returns the new
// string. Free helper functions (month names, etc.) read L.lang directly.

enum L {
    static var lang: String = "it"   // "it" | "en"

    /// Raw localized string for the current language (no formatting).
    static func t(_ key: String) -> String { t(key, lang: lang) }

    /// The string in a given language, whatever the app's (the info sheets let the
    /// user read the other one).
    static func t(_ key: String, lang: String) -> String {
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
    /// Monday-first two-letter weekday headers (one letter was ambiguous: M/M, T/T, S/S).
    static var weekHeaders: [String] {
        lang == "en"
            ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            : ["Lu", "Ma", "Me", "Gi", "Ve", "Sa", "Do"]
    }

    typealias E = (it: String, en: String)
    static let table: [String: E] = [
        // --- Common ---------------------------------------------------------
        "save":        ("Salva", "Save"),
        "cancel":      ("Annulla", "Cancel"),
        "delete":      ("Elimina", "Delete"),
        "ok":          ("OK", "OK"),
        "kb.done":     ("Fine", "Done"),
        "undo":        ("Annulla", "Undo"),
        "wk.set_removed": ("Serie rimossa", "Set removed"),
        "food.deleted": ("Alimento eliminato", "Food deleted"),
        "recipe.deleted": ("Ricetta eliminata", "Recipe deleted"),
        "sum.title":   ("Seduta completata", "Workout complete"),
        "sum.sets":    ("Serie", "Sets"),
        "sum.vs_last": ("rispetto all'ultima", "vs last time"),
        "sum.records": ("Record battuti", "Records beaten"),
        "sum.done":    ("Fatto", "Done"),
        "kb.next":     ("Avanti", "Next"),
        "pe.discard_q": ("Scartare le modifiche a questo giorno?", "Discard the changes to this day?"),
        "pe.discard":  ("Scarta modifiche", "Discard changes"),
        "pe.keep_editing": ("Continua a modificare", "Keep editing"),
        "ring.done":   ("fatto", "done"),
        "wk.rest_label": ("Recupero", "Rest"),
        "wk.go":       ("Vai", "Go"),
        "a11y.close":  ("Chiudi", "Close"),
        "a11y.expand": ("Ingrandisci il grafico", "Expand the chart"),
        "a11y.remove": ("Rimuovi", "Remove"),
        "a11y.info":   ("Spiegazione", "Explanation"),
        "a11y.restart_rest": ("Ricomincia il recupero", "Restart rest"),
        "a11y.start":  ("Avvia", "Start"),
        "a11y.edit":   ("Modifica", "Edit"),
        "a11y.plates": ("Dischi da caricare", "Plates to load"),
        "a11y.prev_day": ("Giorno precedente", "Previous day"),
        "a11y.next_day": ("Giorno successivo", "Next day"),
        "a11y.prev_month": ("Mese precedente", "Previous month"),
        "a11y.next_month": ("Mese successivo", "Next month"),
        "home.weight_invalid": ("Peso non valido: deve essere tra %@ e %@ %@", "Invalid weight: it must be between %@ and %@ %@"),
        "body.steps_invalid": ("Inserisci un numero di passi", "Enter a step count"),

        // --- Workout in progress, restored ------------------------------------
        "wk.restored":           ("Allenamento ripristinato", "Workout restored"),
        "wk.restored_paused":    ("Allenamento ripristinato in pausa", "Workout restored, paused"),
        "wk.stale_q":            ("Hai un allenamento rimasto aperto", "You left a workout open"),
        "wk.stale_body":         ("%@ del %@ non è mai stato chiuso. Vuoi riprenderlo, salvarlo così com'è o scartarlo?",
                                  "%@ from %@ was never closed. Resume it, save it as it is, or discard it?"),
        "wk.stale_resume":       ("Riprendi", "Resume"),
        "wk.stale_save":         ("Salva com'è", "Save as it is"),
        "wk.watch_start_failed": ("L'orologio non ha risposto: avvia l'allenamento dal polso", "The watch didn't respond: start the workout from your wrist"),
        "wk.draft_save_failed":  ("Impossibile salvare l'allenamento in corso sul disco", "Couldn't save the workout in progress to disk"),
        "wk.draft_unreadable":   ("L'allenamento in corso salvato non è leggibile", "The saved workout in progress can't be read"),

        // --- Storage problems ------------------------------------------------
        "store.unreadable_title": ("Dati non leggibili", "Data could not be read"),
        "store.unreadable_body":  ("Il file dei dati non è leggibile e non c'è un backup valido da cui ripartire. Non è stato cancellato: lo trovi in File › Fit Tracker con il nome fittracker.corrupt-…. L'app riparte vuota; puoi importare un backup da Corpo › Backup.",
                                   "The data file can't be read and there is no valid backup to start from. It was not deleted: you'll find it in Files › Fit Tracker as fittracker.corrupt-…. The app starts empty; you can import a backup from Body › Backup."),
        "store.recovered_body":   ("Il file dei dati non era leggibile, quindi è stato caricato il backup %@. Il file originale è conservato in File › Fit Tracker con il nome fittracker.corrupt-….",
                                   "The data file couldn't be read, so the backup %@ was loaded instead. The original file is kept in Files › Fit Tracker as fittracker.corrupt-…."),
        "store.saving_off":       ("salvataggio sospeso finché il file dei dati non torna leggibile; chiudi e riapri l'app", "saving is off until the data file can be read again; close and reopen the app"),
        "wk.already_running":     ("C'è già un allenamento in corso", "A workout is already in progress"),
        "store.save_failed":      ("Salvataggio non riuscito: %@", "Couldn't save: %@"),
        "home.export_failed":     ("Esportazione non riuscita", "Export failed"),
        "body.import_q":          ("Sostituire tutti i dati con questo backup?", "Replace all data with this backup?"),
        "body.import_q_body":     ("I dati attuali vengono prima copiati in File › Fit Tracker (pre-import-…), così puoi tornare indietro.",
                                   "Your current data is first copied to Files › Fit Tracker (pre-import-…), so you can go back."),
        "body.import_replace":    ("Sostituisci", "Replace"),
        "body.import_snapshot_failed": ("Importazione annullata: non è stato possibile salvare una copia dei dati attuali",
                                        "Import cancelled: a copy of your current data couldn't be saved"),
        "add":         ("Aggiungi", "Add"),
        "close":       ("Chiudi", "Close"),
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
        "nutp.today":     ("Oggi", "Today"),
        "nutp.log_today": ("Registra oggi", "Log today"),
        "nutp.edit_today":("Modifica oggi", "Edit today"),
        "nutp.my_foods":  ("I miei alimenti", "My foods"),
        "nutp.no_foods":  ("Nessun alimento salvato. Scansiona o crea il primo.", "No foods saved yet. Scan or create your first one."),

        // --- Home -----------------------------------------------------------
        "home.checkin":      ("Check-in di oggi", "Today's check-in"),
        "home.weight":       ("Peso", "Weight"),
        "home.sleep":        ("Sonno", "Sleep"),
        "home.save_checkin": ("Salva check-in", "Save check-in"),
        "home.streak":       ("Streak", "Streak"),
        "home.days":         ("giorni", "days"),
        "home.next_workout": ("Prossimo allenamento", "Next workout"),
        "home.week_activity": ("Attività settimana", "This week"),
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
        "load.building":     ("Baseline in costruzione", "Building baseline"),
        "load.building_body": (
            "ACWR, monotonia e strain confrontano il carico recente (7 giorni) con quello abituale (28 giorni): con poche sessioni il valore è completamente fuori scala e non affidabile.\n\nServono almeno %d sessioni con durata + FC media, distribuite su almeno %d giorni. L'ideale sono circa 4 settimane di dati costanti.",
            "ACWR, monotony and strain compare your recent load (7 days) with your habitual load (28 days): with only a few sessions the value is completely out of scale and unreliable.\n\nYou need at least %d sessions with duration + average HR, spread over at least %d days. About 4 weeks of consistent data is ideal."),
        "load.sessions_logged": ("Sessioni con carico", "Load sessions"),
        "load.history_days":    ("Giorni di storico", "Days of history"),

        // --- Nutrition ------------------------------------------------------
        "nut.title":         ("Nutrizione", "Nutrition"),
        "nut.cut":           ("Definizione", "Cut"),
        "nut.maintain":      ("Mantenimento", "Maintenance"),
        "nut.bulk":          ("Massa", "Bulk"),
        "nut.target":        ("Calorie obiettivo", "Calorie target"),
        "nut.protein":       ("Proteine", "Protein"),
        "nut.carbs":         ("Carboidrati", "Carbs"),
        "nut.fat":           ("Grassi", "Fat"),
        "nut.salt":          ("Sale (max)", "Salt (max)"),
        "nut.carb_high":     ("Carbo giorno ON", "Carbs training day"),
        "nut.carb_low":      ("Carbo giorno OFF", "Carbs rest day"),
        "nut.per_week":      ("kg/sett", "kg/wk"),
        "nut.trend":         ("Trend peso reale", "Real weight trend"),
        "nut.trend_ok":      ("In linea con l'obiettivo", "On target"),
        "nut.trend_fast":    ("Troppo veloce", "Too fast"),
        "nut.trend_slow":    ("Troppo lento", "Too slow"),
        "nut.trend_wrong":   ("Direzione sbagliata", "Wrong direction"),
        "nut.trend_drift":   ("Ti stai allontanando dal mantenimento", "Drifting away from maintenance"),
        "nut.adjust":        ("Aggiusta di %d kcal", "Adjust by %d kcal"),
        "nut.lea_risk":      ("Rischio bassa disponibilità energetica", "Low energy availability risk"),
        "nut.lea_warn":      ("Disponibilità energetica bassa sotto carico", "Low energy availability under load"),
        "nut.who_note":      ("Range basati su linee guida WHO / ISSN", "Ranges based on WHO / ISSN guidance"),

        // --- Nutrition calendar & per-meal logging --------------------------
        "meal.breakfast":    ("Colazione", "Breakfast"),
        "meal.lunch":        ("Pranzo", "Lunch"),
        "meal.dinner":       ("Cena", "Dinner"),
        "meal.snacks":       ("Spuntini", "Snacks"),
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
        "food.not_found":    ("Prodotto non trovato: inserisci i valori a mano", "Product not found: enter the values by hand"),
        "food.lookup_failed": ("Ricerca non riuscita (connessione?): inserisci i valori a mano", "Lookup failed (connection?): enter the values by hand"),
        "guide.import_dup":  ("Questo allenamento è già registrato", "This workout is already logged"),
        "body.rejected":     ("Non salvato, valore non valido: %@", "Not saved, invalid value: %@"),
        "body.nothing_to_save": ("Niente da salvare", "Nothing to save"),
        "food.scan_hint":    ("Inquadra il codice a barre", "Point at the barcode"),
        "food.scan_unavailable": ("Scansione non disponibile su questo dispositivo. Inserisci l'alimento a mano.",
                                  "Scanning isn't available on this device. Add the food by hand."),
        "nut.day_total":     ("Totale giornaliero", "Daily total"),
        "nut.kcal":          ("Calorie", "Calories"),
        "nut.no_log":        ("Nessun dato nutrizionale", "No nutrition logged"),
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
        "wk.duration":       ("Durata", "Duration"),
        "dur.h":             ("ore", "hrs"),
        "dur.m":             ("min", "min"),
        "dur.s":             ("sec", "sec"),
        "wk.avg_hr":         ("FC media", "Avg HR"),
        "wk.superset":       ("Superset", "Superset"),
        "wk.method":         ("Metodo", "Method"),
        "wk.distance":       ("Distanza", "Distance"),
        "wk.pace":           ("Ritmo", "Pace"),
        "wk.speed":          ("Velocità", "Speed"),
        "wk.pace_auto":      ("Auto da distanza e durata", "Auto from distance & duration"),
        "wk.edit_session":   ("Modifica sessione", "Edit session"),
        "wk.del_session":    ("Elimina sessione", "Delete session"),
        "wk.add_reps":       ("Aumenta le ripetizioni", "Add reps"),
        "wk.add_load":       ("Aumenta il carico", "Add load"),
        "wk.hold":           ("Mantieni il carico", "Hold the load"),
        "wk.deload_ex":      ("Scarica / tecnica", "Deload / technique"),

        // --- Calendar -------------------------------------------------------

        // --- Stats tabs -----------------------------------------------------
        "st.overview":       ("Panoramica", "Overview"),
        "st.records":        ("Record", "Records"),
        "st.progress":       ("Progressi", "Progress"),
        "st.history":        ("Storico", "History"),

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
        "set.sleep_track":   ("Traccia il sonno", "Track sleep"),
        "set.timer":         ("Timer recupero (s)", "Rest timer (s)"),
        "set.units":         ("Unità di misura", "Units"),
        "set.metric":        ("Metrico (kg, cm, km)", "Metric (kg, cm, km)"),
        "set.imperial":      ("Imperiale (lb, in, mi)", "Imperial (lb, in, mi)"),

        // --- Home (legacy) --------------------------------------------------
        "home.day":          ("giorno", "day"),
        "home.sessions":     ("Sessioni", "Sessions"),
        "home.total":        ("totali", "total"),
        "home.goals":        ("Obiettivi", "Goals"),
        "home.fat":          ("Grasso", "Body fat"),
        "home.backup_auto":  ("Salvataggio automatico locale", "Automatic local save"),
        "home.export_data":  ("Esporta dati", "Export data"),
        "home.checkin_done": ("Check-in completato", "Check-in done"),
        "home.checkin_saved":("Check-in salvato", "Check-in saved"),

        // --- Body (legacy) --------------------------------------------------
        "body.analysis":     ("Analisi corporea", "Body analysis"),
        "body.log":          ("Registra corpo", "Log body data"),
        "body.save_all":     ("Salva aggiornamento", "Save update"),
        "body.saved":         ("Aggiornamento salvato", "Update saved"),
        "body.add_measure":  ("Inserisci", "Add"),
        "body.composition":  ("Composizione", "Composition"),
        "body.fat_mass":      ("Massa grassa", "Fat mass"),
        "body.fat_mass_note": ("peso del grasso", "fat weight"),
        "body.lean_mass":     ("Massa magra", "Lean mass"),
        "body.lean_mass_note":("peso senza grasso", "fat-free weight"),
        "body.fat":          ("Grasso", "Fat"),
        "body.measures":     ("Misurazioni settimanali", "Weekly measurements"),
        "body.stable":       ("stabile", "stable"),
        "body.all_measures": ("Tutte le misurazioni", "All measurements"),
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
        "st.max_per_session":("Peso massimo per sessione", "Max weight per session"),
        "st.vol_per_session":("Volume totale per sessione", "Total volume per session"),
        "st.first":          ("Prima", "First"),
        "st.last":           ("Ultima", "Last"),
        "st.delta":          ("Delta", "Delta"),
        "st.progress_hint":  ("Seleziona un esercizio per vedere la progressione.", "Select an exercise to see progression."),
        "st.no_data":        ("Nessun dato", "No data"),
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
        "wk.cardio_kind":    ("Tipo di sport", "Sport kind"),
        "wk.activity_name":  ("Nome attività", "Activity name"),
        "wk.activity_name_ph": ("es. Padel, Sci, HIIT…", "e.g. Padel, Ski, HIIT…"),
        "wk.activity_sub":   ("Sottotitolo", "Subtitle"),
        "wk.activity_sub_ph": ("es. Lungo · Recupero · Soglia…", "e.g. Long · Recovery · Threshold…"),
        "chart.gran.day":    ("Giorno", "Day"),
        "chart.gran.week":   ("Settimana", "Week"),
        "chart.gran.month":  ("Mese", "Month"),
        "chart.gran.year":   ("Anno", "Year"),
        "chart.win.m1":      ("1M", "1M"),
        "chart.win.m3":      ("3M", "3M"),
        "chart.win.m6":      ("6M", "6M"),
        "chart.win.y1":      ("1A", "1Y"),
        "chart.win.all":     ("Tutto", "All"),
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
        "plan.rotation":     ("Rotazione automatica", "Automatic rotation"),
        "plan.scheduled":    ("Da piano settimanale", "From weekly plan"),
        "plan.clear":        ("Azzera piano", "Clear plan"),
        "plan.today":        ("Oggi", "Today"),
        "plan.saved":        ("Piano salvato", "Plan saved"),

        // --- Train page hint ------------------------------------------------
        "wk.edit_hint":      ("Tocca l'icona di modifica su un giorno per rinominarlo, cambiarne colore ed esercizi o eliminarlo. Anche i giorni predefiniti sono completamente personalizzabili.",
                              "Tap the edit icon on a day to rename it, change its color and exercises, or delete it. The default days are fully customizable too."),
        "wk.edit":           ("Modifica", "Edit"),

        // --- Adherence / adaptive nutrition ---------------------------------
        "nut.adaptive":      ("Adattivo", "Adaptive"),
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
        "hk.imported_n":     ("allenamenti importati", "workouts imported"),
        // --- Connect-your-watch guide ---------------------------------------
        "guide.open":        ("Collega il tuo orologio", "Connect your watch"),
        "guide.title":       ("Collega il tuo orologio", "Connect your watch"),
        "band.title":        ("Xiaomi Smart Band 10", "Xiaomi Smart Band 10"),
        "band.note":         ("Collegamento diretto via Bluetooth, senza Mi Fitness: passi, energia, distanza, battito, SpO₂, sonno e gli allenamenti registrati sulla band arrivano in Apple Salute da soli, anche in background.",
                              "Direct Bluetooth link, no Mi Fitness: steps, energy, distance, heart rate, SpO₂, sleep and the workouts recorded on the band reach Apple Health on their own, also in the background."),
        "band.open":         ("Apri la band", "Open band settings"),
        "guide.intro":       ("Qualunque orologio abbinato all'iPhone può alimentare l'app passando da Apple Salute. Collega Salute qui, poi attiva la sincronizzazione nell'app del tuo orologio (sotto).",
                              "Any watch paired to your iPhone can feed the app through Apple Health. Connect Health here, then turn syncing on inside your watch's own app (below)."),
        "guide.health_group":("Orologi che inviano ad Apple Salute", "Watches that send to Apple Health"),
        "guide.other_group": ("Altri orologi (Huawei, Fitbit…)", "Other watches (Huawei, Fitbit…)"),
        "guide.other_note":  ("Alcuni orologi (Huawei e qualche brand) non scrivono su Apple Salute. Esporta l'allenamento dalla loro app, da Strava o da Garmin Connect come file .fit, .gpx o .tcx e importalo qui: diventa una sessione con battito, potenza, cadenza, dislivello e percorso.",
                              "Some watches (Huawei and a few brands) don't write to Apple Health. Export the workout from their app, Strava or Garmin Connect as a .fit, .gpx or .tcx file and import it here: it becomes a session with heart rate, power, cadence, climb and route."),
        "guide.import_file": ("Importa file (.fit / .gpx / .tcx)", "Import file (.fit / .gpx / .tcx)"),
        "guide.import_ok":   ("Allenamento importato", "Workout imported"),
        "guide.import_fail": ("File non riconosciuto. Usa un .fit, .gpx o .tcx valido.", "Unrecognized file. Use a valid .fit, .gpx or .tcx."),

        // --- Workout detail: device metrics and series --------------------
        "wk.max_hr":         ("FC max", "Max HR"),
        "wk.elevation":      ("Dislivello", "Climb"),
        "wk.cal_app":        ("Stima dell'app, uguale per ogni dispositivo", "App estimate, the same for every device"),
        "dev.title":         ("Dati del dispositivo", "Device data"),
        "dev.note":          ("Il valore scritto da te vale su quello misurato e nessuna sincronizzazione lo cambia. Cancellalo per tornare al dato del dispositivo.",
                              "A value you type wins over the measured one and no sync changes it. Clear it to go back to the device's."),
        "dev.empty":         ("Nessun dato extra registrato. Puoi aggiungerne uno a mano.", "No extra data recorded. You can add one by hand."),
        "dev.scores":        ("Punteggi del produttore", "Maker scores"),
        "dev.scores_note":   ("Ogni marca li calcola a modo suo: confrontali solo tra allenamenti dello stesso dispositivo.",
                              "Each brand computes these its own way: compare them only between workouts from the same device."),
        "dev.add":           ("Aggiungi un dato", "Add a value"),
        "dev.measured":      ("Misurato", "Measured"),
        "dev.typed":         ("Scritto da te", "Typed by you"),
        "dev.device":        ("dispositivo", "device"),
        "dev.none":          ("Non misurato", "Not measured"),
        "dev.reset":         ("Torna al valore del dispositivo", "Back to the device's value"),
        "series.title":      ("Andamento dell'allenamento", "Workout timeline"),
        "series.none":       ("Apple Salute non ha battito, percorso o distanze per questo allenamento.",
                              "Apple Health has no heart rate, route or distances for this workout."),
        "series.hr":         ("Battito durante l'allenamento", "Heart rate during the workout"),
        "series.splits":     ("Parziali per km", "Splits per km"),
        "series.route":      ("Percorso", "Route"),
        "wm.minHR":          ("FC minima", "Min HR"),
        "wm.steps":          ("Passi", "Steps"),
        "wm.cadence":        ("Cadenza media", "Avg cadence"),
        "wm.strideLength":   ("Lunghezza del passo", "Stride length"),
        "wm.avgSpeed":       ("Velocità media", "Avg speed"),
        "wm.maxSpeed":       ("Velocità massima", "Max speed"),
        "wm.elevationLoss":  ("Discesa", "Descent"),
        "wm.avgPower":       ("Potenza media", "Avg power"),
        "wm.maxPower":       ("Potenza massima", "Max power"),
        "wm.groundContact":  ("Contatto col suolo", "Ground contact"),
        "wm.verticalOsc":    ("Oscillazione verticale", "Vertical oscillation"),
        "wm.strokes":        ("Bracciate", "Strokes"),
        "wm.laps":           ("Vasche / giri", "Laps"),
        "wm.poolLength":     ("Lunghezza vasca", "Pool length"),
        "wm.swolf":          ("SWOLF", "SWOLF"),
        "wm.jumps":          ("Salti", "Jumps"),
        "wm.mets":           ("Intensità (MET)", "Intensity (MET)"),
        "wm.temperature":    ("Temperatura", "Temperature"),
        "wm.humidity":       ("Umidità", "Humidity"),
        "wm.aerobicEffect":  ("Effetto aerobico", "Aerobic effect"),
        "wm.anaerobicEffect":("Effetto anaerobico", "Anaerobic effect"),
        "wm.trainingLoad":   ("Carico (produttore)", "Load (maker)"),
        "wm.recoveryHours":  ("Recupero consigliato", "Suggested recovery"),
        "wm.vo2max":         ("VO₂max stimato", "Estimated VO₂max"),
        "hk.unavailable":    ("Apple Salute non disponibile su questo dispositivo", "Apple Health unavailable on this device"),

        // --- Sleep / steps quick labels -------------------------------------
        "lbl.steps":         ("Passi", "Steps"),
        "load.trend_title":  ("Andamento carico · 14 giorni", "Load trend · 14 days"),

        // --- Info popups (scientific metrics) -------------------------------
        "band.rest": ("Riposo", "Rest"),
        "band.easy": ("Leggero", "Easy"),
        "band.ready": ("Pronto", "Ready"),
        "band.optimal": ("Ottimale", "Optimal"),
        "band.detraining": ("Sotto carico", "Detraining"),
        "band.sweet_spot": ("Zona ideale", "Sweet spot"),
        "band.caution": ("Attenzione", "Caution"),
        "band.danger": ("Rischio", "Danger"),
        "band.varied": ("Vario", "Varied"),
        "band.monotonous": ("Monotono", "Monotonous"),
        "band.lighter": ("Più leggero", "Lighter"),
        "band.usual": ("Nella tua norma", "Your usual"),
        "band.high": ("Alto", "High"),
        "band.very_high": ("Molto alto", "Very high"),
        "band.light": ("Leggero", "Light"),
        "band.moderate": ("Moderato", "Moderate"),
        "band.hard": ("Duro", "Hard"),
        "band.very_hard": ("Molto duro", "Very hard"),
        "band.poor": ("Scarso", "Poor"),
        "band.fair": ("Discreto", "Fair"),
        "band.good": ("Buono", "Good"),
        "band.excellent": ("Eccellente", "Excellent"),
        "band.low": ("Basso", "Low"),
        "band.slightly_low": ("Un po' basso", "Slightly low"),
        "band.normal": ("Normale", "Normal"),
        "band.regular": ("Regolare", "Regular"),
        "band.irregular": ("Irregolare", "Irregular"),
        "band.very_irregular": ("Molto irregolare", "Very irregular"),
        "band.very_low": ("Molto basso", "Very low"),
        "band.below_usual": ("Sotto la tua norma", "Below your usual"),
        "band.above_usual": ("Sopra la tua norma", "Above your usual"),
        "band.slightly_high": ("Un po' alto", "Slightly high"),
        "band.athlete": ("Da atleta", "Athlete"),
        "band.average": ("Nella media", "Average"),
        "band.sedentary": ("Sedentario", "Sedentary"),
        "band.low_active": ("Poco attivo", "Low active"),
        "band.active": ("Attivo", "Active"),
        "band.very_active": ("Molto attivo", "Very active"),
        "band.underweight": ("Sottopeso", "Underweight"),
        "band.overweight": ("Sovrappeso", "Overweight"),
        "band.obese": ("Obesità", "Obese"),
        "band.essential": ("Essenziale", "Essential"),
        "band.athletic": ("Atletico", "Athletic"),
        "band.fitness": ("In forma", "Fitness"),
        "band.below_average": ("Sotto la media", "Below average"),
        "band.above_average": ("Sopra la media", "Above average"),
        "band.superior": ("Superiore", "Superior"),
        "band.rare": ("Raro senza farmaci", "Rare drug-free"),
        "band.risk": ("Rischio", "Risk"),
        "band.adequate": ("Adeguata", "Adequate"),
        "band.well_under": ("Molto sotto", "Well under"),
        "band.under": ("Sotto", "Under"),
        "band.on_target": ("In obiettivo", "On target"),
        "band.over": ("Sopra", "Over"),
        "band.well_over": ("Molto sopra", "Well over"),
        "band.very_poor": ("Molto scarso", "Very poor"),
        "info.your_value": ("Il tuo valore", "Your value"),
        "info.no_value": ("Ancora nessun dato", "No data yet"),
        "vit.resp_short": ("Respiro", "Breathing"),
        "info.vo2max.title": ("VO₂max", "VO₂max"),
        "info.vo2max.body": (
            "Il massimo ossigeno che il corpo usa sotto sforzo, in mL per kg al minuto. È il miglior indicatore della tua forma aerobica: sale con l'allenamento di resistenza e cala con l'età e l'inattività.\n\nViene dall'Apple Watch (misurato durante camminate e corse all'aperto) oppure, se manca, lo stimiamo dalle tue corse: vedi «Fitness cardio e zone».\n\nLa scala usa le norme del Cooper Institute per il tuo sesso e la tua età. Passare da una classe alla successiva vale molto per la salute: ogni punto di VO₂max in più è associato a un rischio cardiovascolare più basso.",
            "The most oxygen your body uses at full effort, in mL per kg per minute. It is the best marker of your aerobic fitness: it rises with endurance training and falls with age and inactivity.\n\nIt comes from Apple Watch (measured on outdoor walks and runs) or, when missing, we estimate it from your runs: see \"Cardio fitness and zones\".\n\nThe scale uses the Cooper Institute norms for your sex and age. Moving up one class matters a lot for health: every extra point of VO₂max is linked to lower cardiovascular risk."
        ),
        "info.night_vitals.title": ("Parametri notturni", "Overnight vitals"),
        "info.night_vitals.body": (
            "Ogni notte l'orologio o la band misurano mentre dormi HRV, battito, frequenza respiratoria, ossigeno nel sangue e temperatura del polso. Qui li vedi confrontati con la tua norma.\n\nLa tua norma è la media degli ultimi 60 giorni ± 2 deviazioni standard: circa il 95% delle tue notti cade lì dentro, come nell'app Parametri vitali di Apple. Un valore fuori è segnato.\n\nPerché conta: respiro più veloce, polso più caldo e ossigeno più basso del solito, soprattutto insieme, spesso arrivano uno o due giorni prima dei sintomi di un raffreddore, o dopo alcol, viaggi o stress forte. In quei giorni la prontezza si ferma a «leggero».\n\nNon sono dati medici: se un valore resta fuori per giorni, parlane con un medico.",
            "Every night your watch or band measures HRV, heart rate, breathing rate, blood oxygen and wrist temperature while you sleep. Here they are compared with your usual.\n\nYour usual is your average over the last 60 days ± 2 standard deviations: about 95% of your nights fall inside it, as in Apple's Vitals app. A value outside is flagged.\n\nWhy it matters: faster breathing, a warmer wrist and lower oxygen than usual, especially together, often come a day or two before cold symptoms, or after alcohol, travel or heavy stress. On those days readiness stops at \"easy\".\n\nThis is not medical data: if a value stays out of range for days, talk to a doctor."
        ),
        "info.sleep_stages.title": ("Fasi del sonno", "Sleep stages"),
        "info.sleep_stages.body": (
            "Durante la notte il sonno passa per fasi diverse:\n• Profondo: recupero fisico, ormone della crescita, riparazione muscolare. Di solito il 13–23% del sonno\n• REM: memoria, apprendimento motorio, equilibrio emotivo. Di solito il 20–25%\n• Core (leggero): il resto, circa metà della notte\n\nLa scala mostra la quota di sonno profondo dell'ultima notte. Il profondo cala con l'età ed è più alto nella prima parte della notte; alcol e cene tardive lo riducono.\n\nOrologi e band stimano le fasi da movimento e battito: sono indicative, non come un esame in laboratorio. Guarda la tendenza, non la singola notte.",
            "Through the night sleep moves between stages:\n• Deep: physical recovery, growth hormone, muscle repair. Usually 13–23% of sleep\n• REM: memory, motor learning, emotional balance. Usually 20–25%\n• Core (light): the rest, about half the night\n\nThe scale shows last night's share of deep sleep. Deep sleep falls with age and is highest early in the night; alcohol and late dinners reduce it.\n\nWatches and bands estimate stages from movement and heart rate: they are indicative, not a lab test. Look at the trend, not one night."
        ),
        "info.sleep_eff.title": ("Efficienza del sonno", "Sleep efficiency"),
        "info.sleep_eff.body": (
            "Il tempo in cui hai dormito diviso per il tempo passato a letto, dal primo all'ultimo dato della notte.\n\nSopra l'85% è considerato un buon sonno (consenso della National Sleep Foundation, Ohayon 2017). Valori bassi vogliono dire molto tempo sveglio a letto: addormentarsi tardi, risvegli o restare a letto dopo la sveglia.\n\nCosa aiuta: andare a letto solo quando hai sonno, orari regolari, camera buia e fresca, niente schermi e caffeina la sera.",
            "The time you slept divided by the time in bed, from the first to the last reading of the night.\n\nAbove 85% counts as good sleep (National Sleep Foundation consensus, Ohayon 2017). Low values mean a lot of time awake in bed: falling asleep late, waking up, or lying in after the alarm.\n\nWhat helps: going to bed only when sleepy, regular hours, a dark and cool room, no screens or caffeine in the evening."
        ),
        "info.sleep_reg.title": ("Regolarità del sonno", "Sleep regularity"),
        "info.sleep_reg.body": (
            "Quanto cambia, da una notte all'altra, l'orario della metà del tuo sonno nell'ultima settimana (deviazione standard, in minuti). Servono almeno 4 notti.\n\nSotto i 30 minuti il ritmo è regolare. Sopra l'ora e mezza è come avere un piccolo jet lag ogni settimana: gli studi sulla regolarità del sonno (Phillips 2017) la collegano a umore, metabolismo e prestazioni peggiori, anche a parità di ore dormite.\n\nCosa aiuta: svegliarsi alla stessa ora anche nel weekend.",
            "How much the middle of your sleep moves from night to night over the last week (standard deviation, in minutes). It needs at least 4 nights.\n\nUnder 30 minutes your rhythm is regular. Over an hour and a half it is like a small jet lag every week: sleep-regularity studies (Phillips 2017) link it to worse mood, metabolism and performance, even with the same hours slept.\n\nWhat helps: waking up at the same time, weekends included."
        ),
        "info.sleep_hr.title": ("FC nel sonno", "Sleeping heart rate"),
        "info.sleep_hr.body": (
            "Il battito medio mentre dormi, misurato dall'orologio o dalla band solo nelle fasi di sonno.\n\nÈ di solito il valore più basso della giornata e il più affidabile per capire il recupero. Qualche battito sopra la tua norma dopo un allenamento duro, alcol, una cena pesante o un malanno in arrivo è normale; se resta alto per giorni è un segnale di affaticamento.\n\nLa scala è centrata sulla tua media degli ultimi 60 giorni.",
            "Your average heart rate while asleep, measured by the watch or band during sleep only.\n\nIt is usually the lowest value of the day and the most reliable one to read recovery. A few beats above your usual after a hard session, alcohol, a heavy dinner or an oncoming cold is normal; staying high for days signals fatigue.\n\nThe scale is centred on your average over the last 60 days."
        ),
        "info.spo2.title": ("Ossigeno nel sangue", "Blood oxygen"),
        "info.spo2.body": (
            "La saturazione di ossigeno (SpO₂): quanta emoglobina nel sangue trasporta ossigeno. Usiamo la media misurata durante il sonno.\n\nIn una persona sana a livello del mare sta tra 95 e 100%. Di notte scende un po' ed è normale vedere 93–95%. Valori sotto il 93% contano come bassi e fermano la prontezza a «leggero»; sotto il 90% ripetuti meritano un controllo medico (per esempio per apnee notturne).\n\nI sensori da polso sono meno precisi di un saturimetro da dito: guarda le notti ripetute, non un singolo valore.",
            "Oxygen saturation (SpO₂): how much of the haemoglobin in your blood carries oxygen. We use the average measured while asleep.\n\nIn a healthy person at sea level it sits between 95 and 100%. It drops a little at night and 93–95% is normal. Values below 93% count as low and cap readiness at \"easy\"; repeated readings below 90% deserve a medical check (sleep apnoea, for instance).\n\nWrist sensors are less precise than a finger oximeter: look at repeated nights, not one reading."
        ),
        "info.resp_rate.title": ("Frequenza respiratoria", "Breathing rate"),
        "info.resp_rate.body": (
            "Quanti respiri fai al minuto mentre dormi. Negli adulti a riposo è tipicamente tra 12 e 20.\n\nÈ molto stabile da notte a notte per la stessa persona, quindi uno spostamento conta: un aumento di 1–2 respiri sopra la tua norma è uno dei segnali più precoci di infezione, febbre o sovrallenamento. In quel caso la prontezza si ferma a «leggero».\n\nLa scala è centrata sulla tua media degli ultimi 60 giorni (± 2 deviazioni standard).",
            "How many breaths per minute you take while asleep. In resting adults it is typically between 12 and 20.\n\nIt is very stable night to night for the same person, so a shift matters: a rise of 1–2 breaths above your usual is one of the earliest signs of infection, fever or overreaching. Readiness then stops at \"easy\".\n\nThe scale is centred on your average over the last 60 days (± 2 standard deviations)."
        ),
        "info.wrist_temp.title": ("Temperatura del polso", "Wrist temperature"),
        "info.wrist_temp.body": (
            "La temperatura della pelle al polso durante il sonno, misurata dall'Apple Watch (Series 8 e successivi). Non è la temperatura corporea: conta solo lo scarto dalla tua media degli ultimi 60 giorni.\n\nUno scarto tra −0,5 e +0,5 °C è normale. Più di +0,5 °C indica che il corpo è più caldo del solito: può essere l'inizio di un malanno, alcol, una camera calda o, per le donne, la fase del ciclo dopo l'ovulazione. Sopra +0,5 °C la prontezza si ferma a «leggero».",
            "Skin temperature at the wrist while asleep, measured by Apple Watch (Series 8 and later). It is not body temperature: only the deviation from your 60-day average matters.\n\nA deviation between −0.5 and +0.5 °C is normal. More than +0.5 °C means your body runs warmer than usual: an oncoming illness, alcohol, a warm room or, for women, the phase of the cycle after ovulation. Above +0.5 °C readiness stops at \"easy\"."
        ),
        "info.resting_hr.title": ("FC a riposo", "Resting heart rate"),
        "info.resting_hr.body": (
            "Il battito più basso a riposo, calcolato dall'orologio durante la giornata e la notte.\n\nUn cuore allenato pompa più sangue per battito, quindi batte meno: la FC a riposo scende con la forma aerobica. Valori tipici negli adulti: 60–80; sotto 60 è comune in chi si allena, sotto 50 negli atleti di resistenza.\n\nNel breve conta il confronto con te stesso: qualche battito in più del solito per giorni indica stanchezza, stress o un malanno. Per questo la prontezza la confronta con la tua media degli ultimi 60 giorni.",
            "Your lowest heart rate at rest, computed by the watch through the day and night.\n\nA trained heart pumps more blood per beat, so it beats less: resting HR falls as aerobic fitness rises. Typical adult values: 60–80; under 60 is common in people who train, under 50 in endurance athletes.\n\nDay to day, the comparison with yourself is what counts: a few extra beats for days point to fatigue, stress or illness. That is why readiness compares it with your 60-day average."
        ),
        "info.walking_hr.title": ("FC media camminando", "Walking heart rate"),
        "info.walking_hr.body": (
            "Il battito medio mentre cammini, calcolato dall'Apple Watch durante le camminate della giornata.\n\nÈ un buon indicatore della forma nel tempo perché lo sforzo (camminare) è sempre simile: se nelle settimane scende, la tua forma aerobica migliora; se sale, può esserci stanchezza, caldo o un periodo di poca attività.\n\nLa scala è centrata sulla tua media degli ultimi 60 giorni.",
            "Your average heart rate while walking, computed by Apple Watch from the day's walks.\n\nIt is a good fitness marker over time because the effort (walking) is always similar: if it drops over the weeks your aerobic fitness is improving; if it rises there may be fatigue, heat or a period of low activity.\n\nThe scale is centred on your average over the last 60 days."
        ),
        "info.hr_recovery.title": ("Recupero FC a 1 minuto", "1-minute HR recovery"),
        "info.hr_recovery.body": (
            "Di quanti battiti scende il cuore nel primo minuto dopo la fine di un allenamento intenso. L'Apple Watch lo misura a fine allenamento.\n\nUn recupero rapido indica un sistema nervoso parasimpatico efficiente e una buona forma. Riferimenti: 12 battiti o meno è considerato anomalo e associato a un rischio cardiovascolare più alto (Cole 1999); 12–20 discreto; 20–30 buono; oltre 30 eccellente.\n\nIl valore dipende da quanto forte hai spinto: confronta allenamenti simili.",
            "How many beats your heart drops in the first minute after a hard workout ends. Apple Watch measures it at the end of a workout.\n\nA fast recovery means an efficient parasympathetic nervous system and good fitness. References: 12 beats or fewer is considered abnormal and linked to higher cardiovascular risk (Cole 1999); 12–20 fair; 20–30 good; over 30 excellent.\n\nThe value depends on how hard you pushed: compare similar workouts."
        ),
        "info.active_kcal.title": ("Energia attiva", "Active energy"),
        "info.active_kcal.body": (
            "Le calorie bruciate con il movimento durante la giornata, oltre a quelle che il corpo consuma a riposo. Le stima l'orologio da battito e movimento.\n\nÈ la parte del consumo che cambia di più da un giorno all'altro. Le stime da polso possono sbagliare del 20–30%: usale per confrontare i giorni tra loro, non come numero esatto.",
            "The calories burned by moving during the day, on top of what the body uses at rest. Your watch estimates them from heart rate and motion.\n\nIt is the part of your expenditure that changes most from day to day. Wrist estimates can be 20–30% off: use them to compare days, not as an exact number."
        ),
        "info.exercise_min.title": ("Minuti di attività", "Exercise minutes"),
        "info.exercise_min.body": (
            "I minuti di movimento almeno pari a una camminata veloce, contati dall'Apple Watch (l'anello verde).\n\nLe linee guida dell'OMS consigliano 150–300 minuti a settimana di attività moderata (circa 20–40 al giorno), oppure 75–150 di attività intensa.",
            "Minutes of movement at least as hard as a brisk walk, counted by Apple Watch (the green ring).\n\nWHO guidelines recommend 150–300 minutes a week of moderate activity (about 20–40 a day), or 75–150 of vigorous activity."
        ),
        "info.stand.title": ("Ore in piedi", "Stand hours"),
        "info.stand.body": (
            "Le ore della giornata in cui ti sei alzato e mosso per almeno un minuto, contate dall'Apple Watch (l'anello blu). L'obiettivo di Apple è 12.\n\nStare seduti a lungo è un fattore di rischio a sé, anche per chi si allena: interrompere la sedentarietà ogni ora migliora glicemia e circolazione. La scala usa la media degli ultimi 7 giorni.",
            "The hours of the day in which you stood and moved for at least a minute, counted by Apple Watch (the blue ring). Apple's goal is 12.\n\nLong sitting is a risk factor of its own, even for people who train: breaking it up every hour improves blood sugar and circulation. The scale uses your 7-day average."
        ),
        "info.daylight.title": ("Luce del giorno", "Time in daylight"),
        "info.daylight.body": (
            "I minuti passati alla luce del giorno, misurati dal sensore di luce dell'Apple Watch (da iOS 17).\n\nLa luce del mattino regola l'orologio biologico: aiuta ad addormentarsi la sera, migliora umore e regolarità del sonno. Molti studi indicano come utili almeno 20–30 minuti al giorno all'aperto, meglio se al mattino; oltre due ore è ottimo. La scala usa la media degli ultimi 7 giorni.",
            "The minutes spent in daylight, measured by Apple Watch's light sensor (iOS 17 and later).\n\nMorning light sets your body clock: it helps you fall asleep at night and improves mood and sleep regularity. Many studies point to at least 20–30 minutes a day outdoors, ideally in the morning; over two hours is excellent. The scale uses your 7-day average."
        ),
        "info.flights.title": ("Piani saliti", "Flights climbed"),
        "info.flights.body": (
            "I piani di scale saliti nella giornata (circa 3 metri di dislivello l'uno), contati dal telefono o dall'orologio.\n\nSalire le scale è un'attività breve ma intensa: anche pochi piani al giorno sono associati a una migliore forma cardiovascolare. La scala usa la media degli ultimi 7 giorni.",
            "The flights of stairs climbed in the day (about 3 metres each), counted by your phone or watch.\n\nClimbing stairs is short but intense: even a few flights a day are linked to better cardiovascular fitness. The scale uses your 7-day average."
        ),
        "info.weight.title": ("Peso", "Weight"),
        "info.weight.body": (
            "Il grafico mostra la media settimanale del peso, così le oscillazioni di un giorno (acqua, sale, carboidrati, intestino) non confondono la tendenza.\n\nIl peso arriva da quello che inserisci o da una bilancia collegata ad Apple Salute; un valore scritto a mano ha sempre la precedenza. Pesati sempre nelle stesse condizioni, per esempio al mattino dopo il bagno.\n\nPer capire se stai perdendo grasso o muscolo guarda anche grasso corporeo e FFMI.",
            "The chart shows your weekly average weight, so one day's swings (water, salt, carbs, digestion) don't hide the trend.\n\nWeight comes from what you type or from a scale connected to Apple Health; a typed value always wins. Weigh yourself in the same conditions, for instance in the morning after the bathroom.\n\nTo tell fat from muscle, look at body fat and FFMI too."
        ),
        "info.measures.title": ("Misure corporee", "Body measurements"),
        "info.measures.body": (
            "Le circonferenze (vita, petto, braccia, gambe, collo, fianchi) nel tempo.\n\nSono utili quando il peso non si muove: se la vita scende e braccia e petto restano uguali o salgono, stai cambiando composizione corporea nel verso giusto. Vita e collo servono anche alla stima Navy del grasso corporeo.\n\nMisura sempre negli stessi punti, a muscoli rilassati, con il metro aderente ma non stretto.",
            "Your circumferences (waist, chest, arms, legs, neck, hips) over time.\n\nThey help when the scale doesn't move: if your waist shrinks while arms and chest hold or grow, your body composition is changing the right way. Waist and neck also feed the Navy body-fat estimate.\n\nAlways measure at the same spots, muscles relaxed, tape snug but not tight."
        ),
        "info.volume.title": ("Volume per seduta", "Volume per session"),
        "info.volume.body": (
            "Il volume è la somma di peso × ripetizioni di tutte le serie di un esercizio in una seduta (kg totali sollevati).\n\nPer la crescita muscolare il volume settimanale conta più del singolo picco: aumentarlo gradualmente è uno dei modi principali di progredire. Un calo improvviso può voler dire stanchezza o una seduta più leggera voluta. Se fai due sedute lo stesso giorno vengono sommate.",
            "Volume is the sum of weight × reps over every set of an exercise in a session (total kg lifted).\n\nFor muscle growth weekly volume matters more than any single peak: raising it gradually is one of the main ways to progress. A sudden drop can mean fatigue or a planned lighter session. Two sessions on the same day are added together."
        ),
        "info.intake.title": ("Calorie e macro", "Calories and macros"),
        "info.intake.body": (
            "Il grafico mostra la media settimanale di quello che hai mangiato; la linea tratteggiata è il tuo obiettivo.\n\nLa scala confronta la media degli ultimi 7 giorni (oggi escluso, non è finito) con l'obiettivo calorico: tra 90 e 110% sei in linea. Ricorda che quasi tutti sottostimano quello che mangiano del 10–20%: se il peso non segue l'obiettivo, controlla prima la registrazione.",
            "The chart shows your weekly average intake; the dashed line is your target.\n\nThe scale compares the last 7 days (today left out, it isn't over) with your calorie target: between 90 and 110% you are on track. Keep in mind almost everyone under-logs by 10–20%: if your weight doesn't follow the goal, check your logging first."
        ),
        "info.nut_calendar.title": ("Calendario alimentare", "Nutrition calendar"),
        "info.nut_calendar.body": (
            "Ogni giorno mostra le calorie registrate, colorate rispetto al tuo obiettivo:\n• Verde: tra l'85 e il 112% dell'obiettivo\n• Arancio: sotto l'85%\n• Rosso: sopra il 112%\nI giorni vuoti non hanno dati. Tocca un giorno per vederlo o modificarlo.",
            "Each day shows the calories you logged, colored against your target:\n• Green: between 85 and 112% of the target\n• Orange: below 85%\n• Red: above 112%\nEmpty days have no data. Tap a day to see or edit it."
        ),
        "info.salt.title": ("Sale", "Salt"),
        "info.salt.body": (
            "L'Organizzazione Mondiale della Sanità consiglia di non superare 5 g di sale al giorno (circa 2 g di sodio). Un consumo più alto è associato a pressione alta.\n\nChi suda molto in allenamento ne perde una parte, ma per la maggior parte delle persone il problema è l'eccesso, non la carenza: pane, salumi, formaggi e cibi pronti ne contengono molto.",
            "The World Health Organization advises no more than 5 g of salt a day (about 2 g of sodium). Higher intake is linked to high blood pressure.\n\nHeavy sweaters lose some in training, but for most people the problem is too much, not too little: bread, cured meats, cheese and ready meals carry a lot."
        ),
        "sleep.stages":       ("Fasi", "Stages"),
        "sleep.debt_note":    ("ultime 2 settimane", "last 2 weeks"),
        "recovery.today":     ("oggi", "today"),
        "recovery.yesterday": ("ieri", "yesterday"),
        "sleep.slept":        ("Dormito", "Slept"),
        "sleep.slept_note":   ("addormentato", "asleep"),
        "sleep.show_all":     ("Tutti i dati del sonno", "All sleep data"),
        "sleep.hide_all":     ("Nascondi i dati del sonno", "Hide sleep data"),
        "sleep.score_scale":  ("Punteggio della notte", "Night score"),
        "sleep.in_bed":       ("Tempo a letto", "Time in bed"),
        "sleep.hypnogram":    ("Fasi del sonno durante la notte", "Sleep stages through the night"),
        "sleep.week":         ("Ultime 7 notti", "Last 7 nights"),
        "sleep.week_avg":     ("media %@", "average %@"),
        "body.sleep_hr_short": ("FC", "HR"),
        "sleep.deep":         ("Profondo", "Deep"),
        "sleep.core":         ("Core", "Core"),
        "sleep.rem":          ("REM", "REM"),
        "sleep.awake":        ("Sveglio", "Awake"),
        "sleep.efficiency":   ("Efficienza", "Efficiency"),
        "sleep.regularity":   ("Regolarità", "Regularity"),
        "sleep.times":        ("A letto", "In bed"),
        "vit.title":          ("Parametri notturni", "Overnight vitals"),
        "vit.all_ok":         ("TUTTO NELLA NORMA", "ALL USUAL"),
        "vit.out_count":      ("%d FUORI NORMA", "%d OUT OF RANGE"),
        "vit.ok":             ("Norma", "Usual"),
        "vit.high":           ("Sopra", "High"),
        "vit.low":            ("Sotto", "Low"),
        "vit.building":       ("Impara", "Learning"),
        "vit.hrv":            ("HRV", "HRV"),
        "vit.sleep_hr":       ("FC nel sonno", "Sleeping HR"),
        "vit.spo2":           ("SpO₂", "SpO₂"),
        "vit.temp":           ("Temp. polso", "Wrist temp."),
        "load.vitals_warning": ("Fuori dalla tua norma stanotte: %@. Possibile malanno o stress: oggi vacci piano.", "Out of your usual last night: %@. Possible illness or stress: take it easy today."),
        "metric.vo2_norm":    ("norme Cooper per età e sesso", "Cooper norms for age and sex"),
        "metric.hr_recovery": ("Recupero FC 1′", "HR recovery 1′"),
        "st.hrv_time":        ("HRV nel sonno nel tempo", "Sleep HRV over time"),
        "st.rhr_time":        ("FC a riposo nel tempo", "Resting HR over time"),
        "st.resp_time":       ("Frequenza respiratoria nel tempo", "Breathing rate over time"),
        "st.spo2_time":       ("Ossigeno notturno nel tempo", "Night blood oxygen over time"),
        "st.walk_hr_time":    ("FC camminando nel tempo", "Walking HR over time"),
        "st.daylight_time":   ("Luce del giorno nel tempo", "Daylight over time"),
        "st.stand_time":      ("Ore in piedi nel tempo", "Stand hours over time"),
        "band.overreaching": ("Sovraccarico", "Overreaching"),
        "band.productive": ("Allenamento produttivo", "Productive training"),
        "band.maintaining": ("Mantenimento", "Maintaining"),
        "band.fresh": ("Fresco", "Fresh"),
        "band.too_hard": ("Troppa intensità", "Too much intensity"),
        "band.mixed": ("Misto", "Mixed"),
        "band.polarized": ("80/20", "80/20"),
        "band.mostly_easy": ("Quasi tutto facile", "Mostly easy"),
        "band.aerobic_solid": ("Base aerobica solida", "Solid aerobic base"),
        "band.drifting": ("Deriva alta", "High drift"),
        "band.stable": ("Stabile", "Stable"),
        "band.unstable": ("Instabile", "Unstable"),
        "band.very_unstable": ("Molto instabile", "Very unstable"),
        "band.younger": ("Più giovane", "Younger"),
        "band.in_line": ("Come la tua età", "In line"),
        "band.older": ("Più vecchia", "Older"),
        "band.untrained": ("Non allenato", "Untrained"),
        "band.beginner": ("Principiante", "Beginner"),
        "band.novice": ("Base", "Novice"),
        "band.intermediate": ("Intermedio", "Intermediate"),
        "band.advanced": ("Avanzato", "Advanced"),
        "band.elite": ("Élite", "Elite"),
        "info.form.title": ("Forma, fitness e fatica", "Form, fitness and fatigue"),
        "info.form.body": (
            "Il modello di Banister, lo stesso del Performance Management Chart di TrainingPeaks, separa due effetti di ogni allenamento:\n• Fitness: la media del carico (TRIMP) degli ultimi ~42 giorni. Sale lentamente e misura quanto sei allenato\n• Fatica: la media degli ultimi ~7 giorni. Sale e scende in fretta\n• Forma = fitness di ieri − fatica di ieri\n\nCome leggere la forma:\n• Sotto −30: rischio di sovraccarico, serve recupero\n• Da −30 a −10: zona produttiva, stai costruendo forma\n• Da −10 a +5: mantenimento\n• Da +5 a +25: fresco, il momento per una gara o un test\n• Sopra +25: stai perdendo allenamento\n\nConta solo il carico delle sedute con il battito medio.",
            "Banister's model, the same as TrainingPeaks' Performance Management Chart, splits every workout into two effects:\n• Fitness: the average load (TRIMP) of the last ~42 days. It rises slowly and measures how trained you are\n• Fatigue: the average of the last ~7 days. It rises and falls quickly\n• Form = yesterday's fitness − yesterday's fatigue\n\nHow to read form:\n• Below −30: overreaching risk, you need recovery\n• −30 to −10: productive zone, you are building fitness\n• −10 to +5: maintaining\n• +5 to +25: fresh, the time for a race or a test\n• Above +25: you are losing fitness\n\nOnly sessions with average heart rate carry load."
        ),
        "info.recovery.title": ("Recupero stimato", "Estimated recovery"),
        "info.recovery.body": (
            "Quante ore chiede l'ultima seduta con battito registrato prima di rifare uno sforzo intenso. Una seduta pesante quanto una tua giornata media di allenamento chiede circa un giorno; il doppio circa 40 ore. Più sei allenato (fitness alta), meno ore servono; se stamattina la prontezza è bassa, servono circa il 20% in più.\n\nÈ una stima, nello spirito del tempo di recupero di Firstbeat e Garmin: nelle ore di recupero va bene muoversi leggero, non spingere. Se la seduta arriva da Salute conosciamo l'ora di fine e contiamo le ore che mancano.",
            "How many hours your last session with heart rate asks for before another hard effort. A session as heavy as your average training day needs about a day; twice that about 40 hours. The fitter you are the fewer hours it takes; with low readiness this morning add about 20%.\n\nIt is an estimate, in the spirit of Firstbeat's and Garmin's recovery time: during recovery, easy movement is fine, pushing is not. When the session comes from Health we know when it ended and count the hours left."
        ),
        "info.intensity.title": ("Intensità settimanale", "Weekly intensity"),
        "info.intensity.body": (
            "Il tempo passato in ogni zona di frequenza cardiaca durante gli allenamenti, settimana per settimana, letto dal battito che il tuo orologio ha registrato (Apple Watch o altri, tramite Salute).\n\nGli atleti di resistenza di alto livello passano circa l'80% del tempo a intensità bassa (zone 1–2) e il 20% alta (zone 4–5): è il modello polarizzato di Seiler, che migliora la forma con meno rischio di sovraccarico. Chi fa tutto a media intensità (zona 3) si stanca senza migliorare molto.\n\nLa scala mostra la quota di tempo facile delle ultime 4 settimane. Le zone sono quelle della tua scheda Fitness (metodo Karvonen).",
            "The time spent in each heart-rate zone during workouts, week by week, read from the heart rate your watch recorded (Apple Watch or others, through Health).\n\nTop endurance athletes spend about 80% of their time at low intensity (zones 1–2) and 20% high (zones 4–5): Seiler's polarized model, which builds fitness with less risk of overreaching. Doing everything at medium intensity (zone 3) tires you without much progress.\n\nThe scale shows the easy share of the last 4 weeks. The zones are those of your Fitness card (Karvonen method)."
        ),
        "info.decoupling.title": ("Deriva cardiaca", "Aerobic decoupling"),
        "info.decoupling.body": (
            "Nelle corse di almeno 30 minuti confrontiamo la seconda metà con la prima: quanta strada fai per ogni battito. Se a parità di passo il battito sale, la seconda metà è meno efficiente: il cuore \"deriva\".\n\nSotto il 5% la tua base aerobica regge tutta la durata (Joe Friel): è il segnale che sei pronto ad allungare le uscite. Sopra il 10% la corsa era troppo lunga o veloce per la forma attuale, oppure faceva caldo o eri disidratato. Funziona con passo costante: una corsa con ripetute non è confrontabile.",
            "On runs of at least 30 minutes we compare the second half with the first: how much ground you cover per heartbeat. If heart rate climbs at the same pace, the second half is less efficient: the heart \"drifts\".\n\nUnder 5% your aerobic base holds for the whole run (Joe Friel): a sign you are ready to go longer. Above 10% the run was too long or fast for your current fitness, or it was hot or you were dehydrated. It needs a steady pace: a run with intervals is not comparable."
        ),
        "info.sleep_debt.title": ("Debito di sonno", "Sleep debt"),
        "info.sleep_debt.body": (
            "Le ore di sonno che ti mancano nelle ultime due settimane, contro un bisogno di 8 ore a notte (il centro delle 7–9 raccomandate). Ogni notte corta aggiunge debito, ogni notte lunga lo ripaga; le notti senza dati non contano.\n\nUn debito di poche ore è normale. Sopra le 7 ore in due settimane calano attenzione, recupero muscolare e controllo dell'appetito, anche se ti senti abituato. Si recupera con qualche notte più lunga e orari regolari, non con un'unica dormita.",
            "The hours of sleep you are short over the last two weeks, against a need of 8 hours a night (the middle of the recommended 7–9). Each short night adds debt, each long night pays it back; nights without data don't count.\n\nA debt of a few hours is normal. Above 7 hours in two weeks attention, muscle recovery and appetite control decline, even if you feel used to it. It is paid back with a few longer nights and regular hours, not with one long sleep."
        ),
        "info.jet_lag.title": ("Jet lag sociale", "Social jet lag"),
        "info.jet_lag.body": (
            "Quanto si sposta la metà della tua notte tra i giorni di lavoro e il weekend (le notti che finiscono di sabato e domenica), nelle ultime 4 settimane.\n\nIl termine è di Till Roenneberg: dormire molto più tardi nel weekend equivale a cambiare fuso orario ogni settimana. Più di un'ora è comune, oltre le due ore è associato a peggior umore, metabolismo e sonno del lunedì. Si riduce tenendo la sveglia vicina all'orario dei giorni feriali anche nel weekend.",
            "How far the middle of your night moves between work days and the weekend (nights ending on Saturday and Sunday), over the last 4 weeks.\n\nThe term is Till Roenneberg's: sleeping much later at weekends is like changing time zone every week. More than an hour is common; above two hours it is linked to worse mood, metabolism and Monday sleep. It shrinks by keeping the weekend alarm close to the weekday one."
        ),
        "info.hrv_stability.title": ("Stabilità dell'HRV", "HRV stability"),
        "info.hrv_stability.body": (
            "Quanto oscilla la tua HRV notturna da una notte all'altra negli ultimi 7 giorni (coefficiente di variazione del logaritmo, come negli studi di Plews e Buchheit).\n\nNon conta solo il livello dell'HRV ma anche la sua stabilità: oscillazioni che crescono indicano che il corpo fatica ad adattarsi al carico, spesso prima che la media scenda. Sotto il 5% è stabile, sopra il 10% merita attenzione.\n\nServe un dispositivo che misuri l'HRV nel sonno (Apple Watch) per almeno 5 notti della settimana.",
            "How much your night HRV swings from night to night over the last 7 days (coefficient of variation of its logarithm, as in Plews' and Buchheit's studies).\n\nNot only the HRV level matters but its stability: growing swings show the body struggling to adapt to the load, often before the average drops. Under 5% is stable, above 10% deserves attention.\n\nIt needs a device that measures HRV asleep (Apple Watch) on at least 5 nights of the week."
        ),
        "info.fitness_age.title": ("Età fitness", "Fitness age"),
        "info.fitness_age.body": (
            "L'età per cui il tuo VO₂max sarebbe nella media: con 46 mL/kg·min a 40 anni hai la forma aerobica di un trentenne medio. Usiamo le norme del Cooper Institute per il tuo sesso.\n\nL'idea viene dagli studi norvegesi HUNT, dove l'età fitness predice il rischio cardiovascolare meglio dell'età anagrafica. È una stima: il VO₂max dell'orologio o stimato dalle corse può sbagliare di qualche punto.",
            "The age at which your VO₂max would be average: 46 mL/kg·min at 40 means the aerobic fitness of an average 30-year-old. We use the Cooper Institute norms for your sex.\n\nThe idea comes from Norway's HUNT studies, where fitness age predicts cardiovascular risk better than calendar age. It is an estimate: the watch's VO₂max or the one estimated from runs can be off by a few points."
        ),
        "info.strength.title": ("Forza relativa", "Relative strength"),
        "info.strength.body": (
            "Il tuo massimale stimato (1RM con la formula di Epley, dalla serie migliore) diviso per il peso corporeo, per panca piana, squat, stacco e lento avanti con bilanciere.\n\nI livelli (principiante, base, intermedio, avanzato, élite) sono gli standard di forza per adulti come su Strength Level, diversi per uomini e donne. Servono a vedere quale alzata è indietro rispetto alle altre, non come giudizio: dipendono anche da età, altezza e anni di allenamento. Manubri e macchine non contano.",
            "Your estimated max (1RM with Epley's formula, from your best set) divided by body weight, for barbell bench press, squat, deadlift and overhead press.\n\nThe levels (beginner, novice, intermediate, advanced, elite) are adult strength standards as on Strength Level, different for men and women. They show which lift lags behind the others, not a verdict: they also depend on age, height and years of training. Dumbbells and machines don't count."
        ),
        "form.title": ("Forma", "Form"),
        "form.fitness": ("Fitness", "Fitness"),
        "form.fatigue": ("Fatica", "Fatigue"),
        "form.form": ("Forma", "Form"),
        "form.chart_fitness": ("Fitness e fatica · 90 giorni", "Fitness and fatigue · 90 days"),
        "form.chart_form": ("Forma giorno per giorno", "Form day by day"),
        "recovery.title": ("Recupero", "Recovery"),
        "recovery.left": ("ancora %d h", "%d h left"),
        "recovery.done": ("Recuperato", "Recovered"),
        "recovery.total": ("%d h dopo la seduta di %@", "%d h after the %@ session"),
        "intensity.title": ("Intensità settimanale", "Weekly intensity"),
        "intensity.easy": ("facile", "easy"),
        "intensity.hard": ("intenso", "hard"),
        "intensity.zone": ("Z%d", "Z%d"),
        "decoupling.title": ("Deriva cardiaca", "Cardiac drift"),
        "sleep.debt": ("Debito", "Debt"),
        "sleep.jetlag": ("Jet lag sociale", "Social jet lag"),
        "vit.stability": ("Stabilità HRV", "HRV stability"),
        "metric.fitness_age": ("Età fitness", "Fitness age"),
        "metric.years": ("anni", "years"),
        "strength.title": ("Forza relativa", "Relative strength"),
        "lift.bench": ("Panca piana", "Bench press"),
        "lift.squat": ("Squat", "Squat"),
        "lift.deadlift": ("Stacco", "Deadlift"),
        "lift.press": ("Lento avanti", "Overhead press"),
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
        "info.fitness.title": ("Fitness cardio e zone", "Cardio fitness and zones"),
        "info.fitness.body": (
            "Il VO₂max è il massimo ossigeno che il corpo usa sotto sforzo (mL per kg al minuto): il miglior singolo indicatore della forma aerobica e uno dei più forti predittori di salute a lungo termine.\n\nSe Apple Salute ha un valore misurato dall'orologio usiamo quello. Altrimenti lo stimiamo dalle tue corse con battito medio: VO₂ alla tua velocità (equazione ACSM), poi scalato sulla percentuale di riserva cardiaca usata: VO₂max = 3,5 + (VO₂ − 3,5) ÷ %FCR. Contano solo corse di almeno 10 minuti ad almeno il 60% della riserva, e prendiamo la mediana delle tre migliori.\n\nLe classi vengono dalle norme del Cooper Institute per il tuo sesso e la tua età.\n\nLe zone di frequenza cardiaca (metodo Karvonen, % della riserva tra FC a riposo e massima): Z1–Z2 fondo aerobico, Z3 medio, Z4–Z5 alta intensità.",
            "VO₂max is the most oxygen your body can use at full effort (mL per kg per minute): the best single marker of aerobic fitness and one of the strongest predictors of long-term health.\n\nIf Apple Health has a value measured by your watch we use it. Otherwise we estimate it from your runs with average heart rate: VO₂ at your speed (ACSM equation), then scaled by the share of heart-rate reserve used: VO₂max = 3.5 + (VO₂ − 3.5) ÷ %HRR. Only runs of at least 10 minutes at 60% of reserve or more count, and we take the median of the best three.\n\nThe classes come from the Cooper Institute norms for your sex and age.\n\nHeart-rate zones (Karvonen method, % of the reserve between resting and max HR): Z1–Z2 aerobic base, Z3 tempo, Z4–Z5 high intensity."
        ),

        "info.readiness.title": ("Prontezza", "Readiness"),
        "info.readiness.body": (
            "La prontezza (0–100) dice quanto sei recuperato stamattina rispetto a te stesso. Confronta i segnali della notte con la tua norma degli ultimi 60 giorni, quindi è calibrata su di te.\n\nCome si calcola:\n• HRV misurata nel sonno (peso 45%): il valore di stanotte è mescolato con la media degli ultimi 7 giorni, così una sola notte storta non decide tutto\n• FC a riposo (25%): più bassa del solito è un buon segno\n• Punteggio del sonno (30%)\nOgni segnale diventa uno scarto dalla tua media; 50 vuol dire «come al solito».\n\nSe stanotte la frequenza respiratoria o la temperatura del polso sono sopra la tua norma, o l'ossigeno è sotto il 93%, la prontezza si ferma a «leggero»: spesso sono i primi segni di un malanno o di stress forte.\n\nCome usarla: sotto 30 riposa o fai attività leggera; 30–45 allenati ma senza spingere; sopra 45 allenati come previsto.\n\nServono almeno 7 notti di dati per la tua norma.",
            "Readiness (0–100) tells you how recovered you are this morning compared with yourself. It compares last night's signals with your own last 60 days, so it is calibrated to you.\n\nHow it is computed:\n• HRV measured asleep (45%): last night's value is blended with the 7-day average, so one odd night doesn't decide everything\n• Resting heart rate (25%): lower than usual is a good sign\n• Sleep score (30%)\nEach signal becomes a deviation from your average; 50 means \"as usual\".\n\nIf last night your breathing rate or wrist temperature was above your usual, or blood oxygen below 93%, readiness stops at \"easy\": these are often the first signs of illness or heavy stress.\n\nHow to use it: below 30 rest or move lightly; 30–45 train without pushing; above 45 train as planned.\n\nIt needs at least 7 nights of data to learn your usual."
        ),

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

        "info.hrv.title": ("HRV nel sonno", "Sleep HRV"),
        "info.hrv.body": (
            "L'HRV (variabilità della frequenza cardiaca) misura quanto variano gli intervalli tra un battito e l'altro, in millisecondi. Valori più alti indicano un sistema nervoso più rilassato e un buon recupero.\n\nUsiamo solo l'HRV misurata durante il sonno: di giorno cambia troppo con movimento, postura e caffè. Apple Salute la registra come SDNN.\n\nNon esiste un valore giusto per tutti: un atleta può stare a 80–100 ms, una persona sedentaria a 20–30, ed entrambi essere nella norma. Per questo la scala è la tua: il centro è la tua media degli ultimi 60 giorni. Un valore sotto la tua norma per più giorni di fila è un segnale di affaticamento; un singolo valore basso conta poco.",
            "HRV (heart-rate variability) measures how much the time between heartbeats varies, in milliseconds. Higher values mean a more relaxed nervous system and good recovery.\n\nWe only use HRV measured asleep: during the day it moves too much with movement, posture and coffee. Apple Health records it as SDNN.\n\nThere is no right value for everyone: an athlete can sit at 80–100 ms, a sedentary person at 20–30, and both be normal. That is why the scale is yours: its centre is your average over the last 60 days. Several days in a row below your usual signal fatigue; one low night means little."
        ),

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

        "info.sleep.title": ("Punteggio del sonno", "Sleep score"),
        "info.sleep.body": (
            "Il punteggio (0–100) riassume la qualità della notte. Lo calcoliamo dai dati del tuo orologio o della band:\n• Durata (50%): pieno tra 7 e 9 ore, come raccomanda la National Sleep Foundation; scende fino a 0 a 4 o 12 ore\n• Efficienza (15%): tempo addormentato ÷ tempo a letto, pieno dall'85%\n• Fasi (20%): sonno profondo tra 13 e 23% e REM tra 20 e 25% del sonno\n• Regolarità (15%): quanto cambia l'orario della metà della notte nell'ultima settimana\nSe un dato manca (per esempio le fasi), il punteggio usa gli altri.\n\nLa notte va al giorno in cui ti svegli. Se Apple Watch e band registrano la stessa notte, usiamo una sola fonte (quella con più sonno), senza sommarle.\n\nSe inserisci tu il punteggio, l'app non lo cambia più.",
            "The score (0–100) sums up the quality of the night. We compute it from your watch or band:\n• Duration (50%): full marks between 7 and 9 hours, as the National Sleep Foundation recommends; down to 0 at 4 or 12 hours\n• Efficiency (15%): time asleep ÷ time in bed, full marks from 85%\n• Stages (20%): deep sleep 13–23% and REM 20–25% of your sleep\n• Regularity (15%): how much the middle of your night moved over the last week\nIf something is missing (stages, for instance), the score uses the rest.\n\nThe night belongs to the day you wake up. When Apple Watch and the band record the same night we use one source (the one with more sleep) and never add them up.\n\nIf you type a score yourself, the app never changes it."
        ),

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
        "body.sleep_hr":      ("FC nel sonno", "Sleeping HR"),
        "body.hips":          ("Fianchi", "Hips"),
        "body.navy_need_hips": ("Aggiungi la misura dei fianchi per stimare il grasso (formula femminile Navy).",
                                "Add your hip measurement to estimate body fat (women's Navy formula)."),
        "st.steps_time":      ("Passi", "Steps"),

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
        "hk.cat.hrv":         ("HRV nel sonno (SDNN)", "Sleep HRV (SDNN)"),
        "hk.cat.sleep":       ("Sonno", "Sleep"),
        "hk.cat.sleepHR":     ("FC nel sonno", "Sleeping heart rate"),
        "hk.cat.activeKcal":  ("Energia attiva", "Active energy"),
        "hk.cat.exerciseMin": ("Minuti di attività", "Exercise minutes"),

        // --- v8.1: Apple Watch live sync ------------------------------------
        "wk.workout_live":    ("Allenamento in corso", "Workout in progress"),
        "wk.watch_live":      ("In diretta da Apple Watch", "Live from Apple Watch"),
        "wk.watch_synced":    ("Allenamento sincronizzato dall'orologio", "Workout synced from your watch"),
        "wk.started_on_watch": ("Avviato su Apple Watch", "Started on Apple Watch"),

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
        "hk.cat.spo2":        ("Ossigeno nel sangue (notte)", "Blood oxygen (night)"),
        "hk.cat.respRate":    ("Frequenza respiratoria (notte)", "Respiratory rate (night)"),
        "hk.cat.wristTemp":   ("Temperatura del polso (notte)", "Wrist temperature (night)"),
        "hk.cat.walkingHR":   ("FC media camminando", "Walking heart rate"),
        "hk.cat.hrRecovery":  ("Recupero FC a 1 minuto", "1-minute HR recovery"),
        "hk.cat.standHours":  ("Ore in piedi", "Stand hours"),
        "hk.cat.daylight":    ("Tempo alla luce del giorno", "Time in daylight"),
        "hk.cat.flights":     ("Piani saliti", "Flights climbed"),
        "hk.cat.weight":      ("Peso (bilancia)", "Weight (scale)"),
        "hk.cat.bodyFat":     ("Grasso corporeo (bilancia)", "Body fat (scale)"),
        "st.vo2_time":        ("VO₂ max", "VO₂ max"),
        "st.hrv_sdnn":        ("SDNN", "SDNN"),
        "hrv.sleep":          ("HRV notte", "Sleep HRV"),
        "hrv.sleep_note":     ("durante il sonno", "while asleep"),
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

        // --- Sleep manual entry (v10) ----------------------------------------
        "body.sleep_manual":  ("Inserimento manuale", "Manual entry"),
        "body.sleep_hours":   ("Ore di sonno", "Sleep hours"),

        // --- v10: Apple Health history (past days) ---------------------------
        "body.today":         ("Oggi", "Today"),
        "body.past_day":      ("Giorno passato", "Past day"),
        "hk.history":         ("Storico Apple Salute", "Apple Health history"),
        "hk.history_hint":    ("Importa i dati giornalieri già registrati in Apple Salute (passi, sonno, HRV, frequenza cardiaca…). Serve anche a controllare cosa è davvero arrivato: se una voce resta a zero, quel permesso non è attivo in Impostazioni › Privacy › Salute.",
                               "Import the daily data already recorded in Apple Health (steps, sleep, HRV, heart rate…). It also shows what actually arrived: if a row stays at zero, that permission is off in Settings › Privacy › Health."),
        "hk.range":           ("Intervallo", "Range"),
        "hk.range_days":      ("%d giorni", "%d days"),
        "hk.coverage":        ("Giorni con dato", "Days with data"),
        "hk.import_now":      ("Importa", "Import"),
        "hk.reimport":        ("Re-importa (sovrascrivi)", "Re-import (overwrite)"),
        "hk.reimport_hint":   ("Re-importa sostituisce anche i valori già presenti, compresi quelli scritti a mano.",
                               "Re-import replaces stored values too, including ones you typed by hand."),
        "hk.importing":       ("Importazione…", "Importing…"),
        "hk.days_written":    ("%d giorni aggiornati", "%d days updated"),
        "hk.nothing_new":     ("Nessun dato nuovo", "No new data"),
        "hk.partial":         ("Salute ha risposto solo in parte: %d giorni aggiornati. Controlla i permessi o sblocca il telefono e riprova.", "Health answered only in part: %d days updated. Check the permissions, or unlock the phone and try again."),
        "hk.denied":          ("Accesso ad Apple Salute negato", "Apple Health access denied"),
        "hk.recent_days":     ("Ultimi giorni", "Recent days"),
        "hk.day_health":      ("Salute di questo giorno", "Health on this day"),
        "hk.no_day_data":     ("Nessun dato Salute per questo giorno", "No Health data for this day"),

        // --- v10: last-time hint inside the set fields ------------------------
        "wk.last_short":      ("Ultima", "Last"),

        // --- v10: merge sessions ---------------------------------------------
        "day.merge":          ("Unisci", "Merge"),
        "day.merge_n":        ("Unisci %d allenamenti", "Merge %d workouts"),
        "day.merge_hint":     ("Le serie, la durata, la distanza e le calorie vengono sommate in un unico allenamento. Scegli quale nome e colore tenere.",
                               "Sets, duration, distance and calories are summed into one workout. Choose which name and colour to keep."),
        "day.merge_keep":     ("Tieni nome e colore di", "Keep the name and colour of"),
        "day.merged":         ("Allenamenti uniti", "Workouts merged"),

        // --- v10: isometric hold timer ---------------------------------------
        "wk.hold_start":      ("Avvia tenuta", "Start hold"),
        "hold.title":         ("Tenuta isometrica", "Isometric hold"),
        "hold.get_ready":     ("Mettiti in posizione", "Get into position"),
        "hold.hold_now":      ("Tieni!", "Hold!"),
        "hold.prep":          ("Preparazione", "Get ready"),
        "hold.target":        ("Obiettivo", "Target"),
        "hold.free":          ("Libera", "Free"),
        "hold.free_hint":     ("Senza obiettivo il cronometro sale: fermalo quando molli.",
                               "With no target the clock counts up: stop it when you drop."),
        "hold.stop":          ("Ferma e salva", "Stop and save"),
        "hold.done":          ("Tenuta registrata", "Hold logged"),
        "set.hold_prep":      ("Secondi di preparazione", "Preparation seconds"),
        "set.hold_prep_hint": ("Il countdown prima che parta la tenuta, per mettersi in posizione. 0 per disattivarlo.",
                               "The countdown before the hold starts, to get into position. 0 turns it off."),
        "pe.target_sec_field": ("Secondi obiettivo", "Target seconds"),

        // --- v10: FFMI --------------------------------------------------------
        "body.ffmi":          ("FFMI", "FFMI"),
        "body.ffmi_norm":     ("FFMI norm.", "FFMI norm."),
        "body.ffmi_need_bf":  ("Serve la % di grasso", "Needs body fat %"),
        "st.ffmi_time":       ("FFMI nel tempo", "FFMI over time"),
        "ffmi.below":         ("Sotto la media", "Below average"),
        "ffmi.average":       ("Nella media", "Average"),
        "ffmi.good":          ("Buona", "Good"),
        "ffmi.great":         ("Ottima", "Great"),
        "ffmi.excellent":     ("Eccellente", "Excellent"),
        "ffmi.elite":         ("Al limite naturale", "At the natural limit"),
        "info.ffmi.title":    ("FFMI — indice di massa magra", "FFMI — fat-free mass index"),
        "info.ffmi.body":     ("Il FFMI è il BMI della sola massa magra: massa magra (kg) ÷ altezza² (m). A differenza del BMI non ti penalizza se sei muscoloso — un atleta con poco grasso ha BMI \"sovrappeso\" ma FFMI ottimo.\n\nIl FFMI normalizzato aggiunge 6,1 × (1,80 − altezza) per confrontare persone di statura diversa.\n\nRiferimenti (uomini): sotto 18 poca massa, 18-20 media, 20-22 buona, 22-23 ottima, 23-26 eccellente. Oltre 26 è molto raro senza farmaci. Per le donne sposta i valori di circa 3 punti verso il basso.\n\nServe una percentuale di grasso: inseriscila a mano o lascia che la stimi la formula Navy da collo e vita.",
                               "FFMI is the BMI of your lean mass alone: fat-free mass (kg) ÷ height² (m). Unlike BMI it doesn't punish you for being muscular — a lean athlete reads \"overweight\" on BMI but excellent on FFMI.\n\nNormalized FFMI adds 6.1 × (1.80 − height) so people of different heights can be compared.\n\nReference (men): below 18 low mass, 18-20 average, 20-22 good, 22-23 great, 23-26 excellent. Above 26 is very rare drug-free. For women shift the bands down about 3 points.\n\nIt needs a body-fat percentage: enter one by hand or let the Navy formula estimate it from neck and waist."),

        // --- v10: automatic rest timer ---------------------------------------
        "set.auto_rest":      ("Timer di recupero automatico", "Automatic rest timer"),
        "set.auto_rest_hint": ("Il recupero parte da solo quando completi una serie. Puoi impostare una durata diversa per ogni esercizio nell'editor del piano.",
                               "Rest starts on its own when you complete a set. You can set a different duration per exercise in the plan editor."),
        "pe.rest_timer":      ("Recupero", "Rest"),
        "wk.rest_over":       ("Recupero finito", "Rest is over"),
        "wk.rest_over_body":  ("Torna sotto il bilanciere.", "Back under the bar."),

        // --- v10: plate calculator + warm-up ---------------------------------
        "plate.title":        ("Dischi e riscaldamento", "Plates and warm-up"),
        "plate.per_side":     ("Per lato", "Per side"),
        "plate.bar":          ("Bilanciere", "Bar"),
        "plate.unreachable":  ("Peso non raggiungibile con i dischi disponibili — il più vicino è %@ kg.",
                               "Not reachable with the available plates — closest is %@ kg."),
        "plate.warmup":       ("Riscaldamento", "Warm-up"),
        "plate.working":      ("Serie allenante", "Working set"),
        "plate.no_target":    ("Inserisci un peso in una serie per vedere i dischi.",
                               "Enter a weight in a set to see the plates."),
        "set.bar_weight":     ("Peso bilanciere (kg)", "Bar weight (kg)"),
        "set.plates":         ("Dischi disponibili (kg)", "Available plates (kg)"),

        // --- v10: export to Apple Health -------------------------------------
        "hk.export":          ("Scrivi gli allenamenti su Apple Salute", "Write workouts to Apple Health"),
        "hk.export_hint":     ("Gli allenamenti che registri qui vengono salvati anche in Apple Salute, così chiudono gli anelli e appaiono in Fitness. Quelli importati da Salute non vengono riscritti.",
                               "Workouts you log here are also saved into Apple Health, so they close your rings and show up in Fitness. Workouts imported from Health are never written back."),
        "hk.exported":        ("Salvato su Apple Salute", "Saved to Apple Health"),
        "hk.export_failed":   ("Scrittura su Apple Salute non riuscita", "Couldn't write to Apple Health"),

        // --- v10: muscle volume targets + deload -----------------------------
        "st.vol_target":      ("obiettivo %d-%d serie", "target %d-%d sets"),
        "st.vol_low":         ("sotto", "under"),
        "st.vol_ok":          ("in target", "on target"),
        "st.vol_high":        ("sopra", "over"),
        "load.deload_why":    ("Carico e monotonia sono alti insieme: taglia volume e intensità di circa il 40% per una settimana.",
                               "Load and monotony are high together: cut volume and intensity by about 40% for a week."),

        // --- v10: duplicate session + history search --------------------------
        "wk.repeat_today":    ("Ripeti oggi", "Repeat today"),
        "wk.repeated":        ("Allenamento copiato a oggi", "Workout copied to today"),
        "wk.search":          ("Cerca negli allenamenti", "Search workouts"),
        "wk.show_all":        ("Mostra tutti (%d)", "Show all (%d)"),
        "wk.show_less":       ("Mostra meno", "Show less"),
        "wk.no_match":        ("Nessun allenamento trovato", "No workouts found"),

        // --- v10: PR feed ------------------------------------------------------
        "st.pr_feed":         ("Record nel tempo", "Records over time"),
        "st.pr_none":         ("Nessun record ancora. Registra qualche serie con il peso.",
                               "No records yet. Log a few sets with a weight."),
        "st.pr_weight":       ("peso max", "top weight"),
        "st.pr_e1rm":         ("e1RM", "e1RM"),
        "st.pr_hold":         ("tenuta", "hold"),
        "st.pr_first":        ("primo record", "first record"),

        // --- v10: Live Activity ------------------------------------------------
        "set.live_activity":  ("Allenamento su schermata di blocco", "Workout on Lock Screen"),
        "set.live_activity_hint": ("Mostra cronometro, esercizio in corso e recupero su schermata di blocco e Dynamic Island.",
                                   "Shows the clock, current exercise and rest on the Lock Screen and Dynamic Island."),

        // --- v14 ---------------------------------------------------------------
        "wk.session_deleted": ("Allenamento eliminato", "Workout deleted"),
        "store.repaired":     ("Un valore non valido è stato salvato come 0", "An invalid value was saved as 0"),
        "ob.rate_loss":       ("Peso da perdere", "Weight to lose"),
        "ob.rate_gain":       ("Peso da prendere", "Weight to gain"),
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
