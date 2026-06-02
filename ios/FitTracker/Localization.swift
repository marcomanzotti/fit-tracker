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
        "info.readiness.title": ("Prontezza", "Readiness"),
        "info.readiness.body": (
            "Combina i tuoi segnali del mattino: HRV (RMSSD o SDNN, peso maggiore), frequenza a riposo/al risveglio (più bassa = meglio) e qualità del sonno. Ogni segnale viene confrontato con la tua media di ~60 giorni; usa solo quelli disponibili, quindi funziona anche con un dato solo.\n\nPunteggio 0-100: 50 = nella tua norma. Sopra 70 puoi spingere, sotto 30 meglio leggero o riposo. Più dati inserisci (o importi da Salute), più è affidabile.",
            "Combines your morning signals: HRV (RMSSD or SDNN, weighted most), resting/waking heart rate (lower = better) and sleep. Each is compared to your ~60-day average, using only what's available — so it works even with a single signal.\n\nScore 0-100: 50 = normal for you. Above 70 you can push, below 30 go easy or rest. The more you log (or import from Health), the more reliable it gets."),
        "info.acwr.title": ("Carico acuto:cronico (ACWR)", "Acute:Chronic load (ACWR)"),
        "info.acwr.body": (
            "Confronta il carico recente (ultimi ~7 giorni) con quello abituale (ultimi ~28 giorni), entrambi con media mobile esponenziale. Il carico viene dal TRIMP, quindi serve FC media + durata.\n\nZona ottimale: 0,8–1,3. Sotto 0,8 stai detraining. Sopra 1,3 il rischio infortuni aumenta.",
            "Compares recent load (last ~7 days) to habitual load (last ~28 days), both via exponential moving average. Load comes from TRIMP, so you need average HR + session duration.\n\nOptimal zone: 0.8–1.3. Below 0.8 you're detraining. Above 1.3 injury risk goes up."),
        "info.monotony.title": ("Monotonia", "Monotony"),
        "info.monotony.body": (
            "Media del carico giornaliero divisa per la deviazione standard della settimana (metodo Foster). Più è alta, più tutti i tuoi allenamenti si somigliano.\n\nSopra ~2 non stai alternando giorni duri e leggeri, il che aumenta l'affaticamento. Varia l'intensità per tenerla sotto controllo.",
            "Mean daily load divided by its standard deviation for the week (Foster method). The higher it is, the more similar your sessions look.\n\nAbove ~2 you're not alternating hard and easy days, which increases fatigue. Vary intensity to keep it in check."),
        "info.strain.title": ("Strain", "Strain"),
        "info.strain.body": (
            "Carico settimanale totale × monotonia (metodo Foster). In un numero solo: quanto stress hai accumulato questa settimana.\n\nI picchi di strain precedono spesso sovraccarico o malanni. Usalo come segnale per pianificare una settimana di scarico.",
            "Total weekly load × monotony (Foster method). One number for how much stress you've stacked this week.\n\nStrain spikes often come before overreaching or illness — use it as a cue to schedule a deload week."),
        "info.load.title": ("Carico interno", "Internal load"),
        "info.load.body": (
            "Misura lo stress che l'allenamento impone al corpo, calcolato come TRIMP dalla durata e dalla FC media. ACWR, monotonia e strain derivano tutti da questa metrica.\n\nSenza durata + FC media la sessione non genera carico: le metriche restano vuote. Serve un orologio o una fascia cardio.",
            "Measures the stress training places on your body, computed as TRIMP from duration and average heart rate. ACWR, monotony and strain all build on it.\n\nWithout duration + average HR a session has no load, so these metrics stay empty. You need a watch or chest strap."),
        "info.activity.title": ("Livello di attività", "Activity level"),
        "info.activity.body": (
            "Moltiplica il metabolismo basale per stimare quante calorie bruci ogni giorno.\n\nSedentario (×1,2): lavoro d'ufficio. Leggero (×1,375): 1-2 allenamenti/sett. Moderato (×1,55): 3-4. Alto (×1,725): 5-6. Atleta (×1,9): 6-7 + lavoro fisico o doppie sedute. Scegli in base ai tuoi giorni reali di allenamento.",
            "Multiplies your resting metabolism to estimate daily calorie burn.\n\nSedentary (×1.2): desk job. Light (×1.375): 1-2 sessions/week. Moderate (×1.55): 3-4. High (×1.725): 5-6. Athlete (×1.9): 6-7 plus physical job or twice-daily sessions. Pick based on your real training days."),
        "info.srpe.title": ("sRPE (durata × RPE)", "sRPE (duration × RPE)"),
        "info.srpe.body": (
            "Durata della sessione × RPE (1-10, Borg CR10). Il modo più semplice per quantificare il carico interno di qualsiasi allenamento.\n\nUsato nei dati storici. Il carico nelle sessioni attuali si basa sul TRIMP (FC media), più preciso.",
            "Session duration × RPE (1-10, Borg CR10). The simplest way to quantify internal load for any session.\n\nUsed in historical data. Current sessions use TRIMP (average HR), which is more precise."),
        "info.trimp.title": ("TRIMP", "TRIMP"),
        "info.trimp.body": (
            "Calcola il carico cardiovascolare pesando la durata con la frequenza cardiaca di riserva (Banister). Più preciso dell'sRPE perché usa la FC reale.\n\nRichiede FC media + durata, e FC a riposo/massima dal profilo. Riferimento: corsa facile 45 min ≈ 40 TRIMP, sessione dura 60 min ≈ 80-100.",
            "Calculates cardiovascular load by weighting duration by heart-rate reserve (Banister). More precise than sRPE because it uses real HR.\n\nNeeds average HR + duration, and resting/max HR from your profile. Reference: easy 45-min run ≈ 40 TRIMP, hard 60-min session ≈ 80-100."),
        "info.bmi.title": ("BMI", "BMI"),
        "info.bmi.body": (
            "Peso (kg) ÷ altezza² (m). Categorie OMS: <18,5 sottopeso, 18,5-25 normale, 25-30 sovrappeso, >30 obeso.\n\nNon distingue muscolo da grasso: una persona muscolosa può avere BMI alto con poco grasso. Quando inserisci il grasso corporeo, l'app classifica in base a quello invece che al BMI.",
            "Weight (kg) ÷ height² (m). WHO categories: <18.5 underweight, 18.5-25 normal, 25-30 overweight, >30 obese.\n\nIt can't tell muscle from fat — a muscular person can read high with little fat. When you log body fat, the app classifies by that instead of BMI alone."),
        "info.bodyfat.title": ("Grasso corporeo", "Body fat"),
        "info.bodyfat.body": (
            "Percentuale di grasso sul peso totale. Inseriscila a mano (plicometro, bilancia smart) oppure usa la stima Navy basata su collo e vita.\n\nLa stima Navy ha un margine di ±3-4%: l'importante è misurarsi sempre nello stesso modo e seguire il trend nel tempo.",
            "Percentage of fat in your total weight. Enter it manually (calipers, smart scale) or use the Navy estimate from neck and waist measurements.\n\nThe Navy estimate has a ±3-4% margin — measure consistently and track the trend over time."),
        "info.tdee.title": ("TDEE & BMR", "TDEE & BMR"),
        "info.tdee.body": (
            "BMR: calorie bruciate a riposo, calcolate con Mifflin-St Jeor da peso, altezza, età e sesso.\n\nTDEE = BMR × moltiplicatore di attività (1,2–1,9). È la base per impostare le calorie obiettivo in definizione, mantenimento o massa.",
            "BMR: calories burned at rest, from the Mifflin-St Jeor formula using weight, height, age and sex.\n\nTDEE = BMR × activity multiplier (1.2–1.9). It's the starting point for setting calorie targets on a cut, maintenance or bulk."),
        "info.macros.title": ("Macronutrienti", "Macronutrients"),
        "info.macros.body": (
            "Come proteine, carboidrati e grassi si distribuiscono nelle calorie obiettivo, su range ISSN.\n\nProteine 1,8-2,2 g/kg (più alte in definizione per proteggere la massa magra). Grassi min 0,8 g/kg. I carboidrati riempiono le calorie restanti e alimentano la prestazione.",
            "How protein, carbs and fat split your calorie target, on ISSN reference ranges.\n\nProtein 1.8-2.2 g/kg (higher on a cut to protect lean mass). Fat minimum 0.8 g/kg. Carbs fill the remaining calories and fuel performance."),
        "info.carbcycle.title": ("Ciclizzazione dei carboidrati", "Carb cycling"),
        "info.carbcycle.body": (
            "Sposta i carboidrati verso i giorni di allenamento mantenendo la media settimanale: +30% nei giorni ON, -35% nei giorni OFF.\n\nÈ utile soprattutto in definizione: alleni con energia restando in deficit. Le proteine restano costanti ogni giorno.",
            "Shifts carbs toward training days while keeping the weekly average: +30% on ON days, -35% on OFF days.\n\nMost useful on a cut — you train with energy while staying in a deficit. Protein stays constant every day."),
        "info.lea.title": ("Disponibilità energetica (EA)", "Energy availability (EA)"),
        "info.lea.body": (
            "Energia disponibile per le funzioni vitali dopo l'allenamento: (calorie assunte − energia esercizio) ÷ massa magra, media 7 giorni.\n\nSotto 30 kcal/kg di massa magra al giorno c'è rischio di LEA/RED-S: cali ormonali, ossei e di prestazione. La zona 30-45 è di cautela sotto carichi alti.",
            "Energy left for vital functions after training: (calories eaten − exercise energy) ÷ lean mass, 7-day average.\n\nBelow 30 kcal/kg lean mass per day risks LEA/RED-S: hormonal, bone and performance decline. 30-45 is a caution zone under high load."),
        "info.trend.title": ("Trend del peso", "Weight trend"),
        "info.trend.body": (
            "Stima la tua vera variazione di peso (kg/settimana) con una regressione lineare sugli ultimi ~21 pesi, filtrando il rumore giornaliero di acqua e sale.\n\nConfronta il ritmo reale con l'obiettivo e suggerisce un aggiustamento calorico. Servono almeno 4 pesate.",
            "Estimates your real weight change (kg/week) with a linear regression over your last ~21 weigh-ins, filtering out daily water and salt noise.\n\nCompares your real rate to your target and suggests a calorie tweak if needed. Needs at least 4 weigh-ins."),
        "info.overload.title": ("Sovraccarico progressivo", "Progressive overload"),
        "info.overload.body": (
            "Suggerisce se aumentare il carico, le ripetizioni, mantenere o scaricare, confrontando l'ultima sessione con il range obiettivo.\n\nCima del range su tutte le serie → aumenta il peso. Dentro il range → cerca più ripetizioni. Sotto il fondo → mantieni e cura la tecnica. Il ritmo è graduale e misurabile.",
            "Suggests whether to add load, add reps, hold or deload, comparing your last session to the target rep range.\n\nHit the top of the range on every set → add weight. Inside the range → chase more reps. Below the bottom → hold and refine technique. Progress is gradual and measurable."),
        "info.calories.title": ("Calorie bruciate", "Calories burned"),
        "info.calories.body": (
            "Stima le calorie attive bruciate nella sessione (la quota a riposo è esclusa, come un orologio sportivo).\n\nOgni sport ha la sua formula: la corsa e il ciclismo usano una curva velocità→MET dalla distanza e durata; senza distanza usa la FC. La forza usa FC, durata e volume. È una stima: inserisci il tuo valore per sovrascriverla.",
            "Estimates the active calories burned in the session (resting share removed, like a sports watch).\n\nEach sport has its own formula: running and cycling use a speed→MET curve from distance and duration; without distance it uses HR. Strength uses HR, duration and volume. It's an estimate — type your own number to override it."),
        "info.pace.title": ("Ritmo & velocità", "Pace & speed"),
        "info.pace.body": (
            "Calcolato automaticamente da distanza e durata: la bici usa km/h, la corsa e la camminata min/km, il nuoto min/100m.\n\nInserisci distanza e durata e compare da solo. Puoi scriverlo a mano per sovrascrivere il calcolo automatico.",
            "Computed automatically from distance and duration: cycling uses km/h, running and walking use min/km, swimming uses min/100m.\n\nEnter distance and duration and it fills in automatically. Type it by hand to override."),
        "info.rmssd.title": ("RMSSD (HRV)", "RMSSD (HRV)"),
        "info.rmssd.body": (
            "La misura principale dell'HRV: radice quadrata della media dei quadrati delle differenze tra battiti consecutivi, in ms. Riflette il recupero del sistema nervoso parasimpatico.\n\nMisuralo al mattino, sdraiato, sempre nello stesso modo, con un'app HRV o fascia cardio. L'app lo converte nel punteggio di Prontezza.",
            "The main HRV metric: root mean square of successive differences between consecutive heartbeats, in ms. Reflects parasympathetic (recovery) nervous-system activity.\n\nMeasure in the morning, lying down, the same way each time, with an HRV app or chest strap. The app converts it into your Readiness score."),
        "info.dfa.title": ("DFA-alpha1 (soglia aerobica)", "DFA-alpha1 (aerobic threshold)"),
        "info.dfa.body": (
            "Indice frattale degli intervalli R-R: quando scende intorno a 0,75 segnala la prima soglia aerobica senza test di laboratorio.\n\nRichiede un flusso R-R battito-battito continuo da fascia cardio Bluetooth. In arrivo con il supporto BLE.",
            "Fractal index of R-R intervals: when it drops to ~0.75 it marks the first aerobic threshold without a lab test.\n\nNeeds a continuous beat-to-beat R-R stream from a Bluetooth chest strap. Coming with BLE support."),
        "info.weekplan.title": ("Piano settimanale", "Weekly plan"),
        "info.weekplan.body": (
            "Assegna a ogni giorno della settimana un allenamento di forza, un'attività cardio o riposo. Il prossimo allenamento seguirà esattamente questo ordine.\n\nSenza piano l'app ruota automaticamente tra i giorni in ordine. Lascia tutto vuoto per tornare alla rotazione automatica.",
            "Assign a strength workout, cardio activity or rest to each weekday. The next workout follows exactly this schedule.\n\nWithout a plan the app rotates through your days automatically. Leave it all empty to go back to auto-rotation."),
        "info.adherence.title": ("Costanza & TDEE adattivo", "Adherence & adaptive TDEE"),
        "info.adherence.body": (
            "Quando tracki peso e calorie abbastanza giorni, l'app calcola il tuo mantenimento reale (TDEE adattivo) = calorie medie − energia implicata dal trend di peso. Impara la tua spesa vera invece di fidarsi solo del moltiplicatore di attività.\n\nConsideraiamo anche passi e volume di allenamento. Se tracci poco le stime sono meno affidabili.",
            "Once you track weight and calories for enough days, the app calculates your real maintenance (adaptive TDEE) = average intake − energy implied by your weight trend. It learns your true expenditure instead of trusting only the activity multiplier.\n\nIt also factors in steps and training volume. Log inconsistently and estimates become less reliable."),
        "info.steps.title": ("Passi", "Steps"),
        "info.steps.body": (
            "Attività non sportiva (NEAT), che incide molto sul dispendio totale. Inseriscili a mano o collegati ad Apple Salute per l'import automatico.\n\nServono per rendere più preciso il TDEE adattivo e per vedere quanto ti muovi fuori dall'allenamento.",
            "Non-exercise activity (NEAT), which heavily affects total energy expenditure. Enter manually or connect to Apple Health for auto-import.\n\nThey make the adaptive TDEE estimate more accurate and show how much you move outside training."),
        "info.sleep.title": ("Punteggio sonno", "Sleep score"),
        "info.sleep.body": (
            "Punteggio 0-100 per durata e qualità percepita del sonno. Il sonno è il principale fattore di recupero, performance e composizione corporea.\n\nInseriscilo ogni mattina con il peso: nel tempo vedrai come si correla con prontezza e progressi.",
            "A 0-100 score for sleep duration and perceived quality. Sleep is the single biggest driver of recovery, performance and body composition.\n\nLog it each morning with your weight — over time you'll see how it relates to readiness and progress."),
        "info.goal.title": ("Obiettivo & progressi", "Goal & progress"),
        "info.goal.body": (
            "Il tuo obiettivo (peso e grasso) viene impostato all'inizio e non cambia ad ogni pesata: resta fisso finché non lo modifichi con 'Cambia obiettivo'.\n\nLa barra parte dal peso iniziale e arriva all'obiettivo. Il numero a sinistra cambia ad ogni check-in, quello a destra resta fisso.",
            "Your goal (weight and body fat) is set at the start and doesn't change at each weigh-in — it stays fixed until you tap 'Change goal'.\n\nThe bar runs from your start weight to your goal weight. The number on the left changes with each check-in; the one on the right stays put."),
        "info.streak.title": ("Striscia", "Streak"),
        "info.streak.body": (
            "Giorni consecutivi con almeno un check-in o un allenamento. Resta attiva per tutta la giornata di oggi: non si azzera prima che il giorno sia finito.\n\nSi interrompe solo quando un giorno intero passa senza nulla registrato.",
            "Consecutive days with at least one check-in or workout. It stays alive for all of today — it doesn't reset before the day is over.\n\nIt only breaks once a full day passes with nothing logged."),

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

        // --- Sessions info popup --------------------------------------------
        "info.sessions.title": ("Sessioni totali", "Total sessions"),
        "info.sessions.body": (
            "Tutte le sessioni di forza e cardio salvate dall'inizio. Ogni sessione conta, anche se breve.\n\nUsalo come riferimento nel tempo: se il numero cresce in modo costante, stai allenandoti con continuità.",
            "All strength and cardio sessions saved since you started. Every session counts, even short ones.\n\nUse it as a long-term reference: a number that keeps growing means you're training consistently."),

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
        "hk.import_workouts_hint": ("Allenamenti registrati da altri orologi (Garmin, ecc.). I formati non sempre si convertono perfettamente.",
                                    "Workouts recorded by other watches (Garmin, etc.). Formats don't always convert cleanly."),
        "hk.cat.steps":       ("Passi", "Steps"),
        "hk.cat.restHR":      ("FC a riposo", "Resting heart rate"),
        "hk.cat.hrv":         ("HRV (SDNN)", "HRV (SDNN)"),
        "hk.cat.sleep":       ("Sonno", "Sleep"),
        "hk.cat.sleepHR":     ("FC nel sonno", "Sleeping heart rate"),
        "hk.cat.activeKcal":  ("Energia attiva", "Active energy"),
        "hk.cat.exerciseMin": ("Minuti di attività", "Exercise minutes"),

        // --- v8.1: Apple Watch live sync ------------------------------------
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
