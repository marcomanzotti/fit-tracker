package com.marco.fittracker.data

// MARK: - Lightweight runtime localization (IT / EN), mirrors the iOS L enum.
// L.lang is kept in sync with prefs.language by the Store; Compose reads it via
// the `t(key)` helper at render time.
object L {
    var lang: String = "it"   // "it" | "en"

    fun t(key: String): String {
        val e = table[key] ?: return key
        return if (lang == "en") e.second else e.first
    }

    val months: List<String>
        get() = if (lang == "en")
            listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
        else listOf("Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic")

    val days: List<String>
        get() = if (lang == "en")
            listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        else listOf("Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom")

    val weekHeaders: List<String>
        get() = if (lang == "en") listOf("M", "T", "W", "T", "F", "S", "S")
        else listOf("L", "M", "M", "G", "V", "S", "D")

    // key -> (it, en)
    val table: Map<String, Pair<String, String>> = mapOf(
        "save" to ("Salva" to "Save"),
        "cancel" to ("Annulla" to "Cancel"),
        "delete" to ("Elimina" to "Delete"),
        "edit" to ("Modifica" to "Edit"),
        "done" to ("Fatto" to "Done"),
        "add" to ("Aggiungi" to "Add"),
        "close" to ("Chiudi" to "Close"),
        "none" to ("Nessuno" to "None"),
        "confirm_delete" to ("Confermi l'eliminazione?" to "Confirm deletion?"),

        "nav.home" to ("Home" to "Home"),
        "nav.train" to ("Allena" to "Train"),
        "nav.body" to ("Corpo" to "Body"),
        "nav.stats" to ("Stats" to "Stats"),

        "home.checkin" to ("Check-in di oggi" to "Today's check-in"),
        "home.weight" to ("Peso" to "Weight"),
        "home.sleep" to ("Sonno" to "Sleep"),
        "home.save_checkin" to ("Salva check-in" to "Save check-in"),
        "home.streak" to ("Striscia" to "Streak"),
        "home.day" to ("giorno" to "day"),
        "home.days" to ("giorni" to "days"),
        "home.sessions" to ("Sessioni" to "Sessions"),
        "home.total" to ("totali" to "total"),
        "home.next_workout" to ("Prossimo allenamento" to "Next workout"),
        "home.week_activity" to ("Attività settimana" to "This week"),
        "home.goals" to ("Obiettivi" to "Goals"),
        "home.fat" to ("Grasso" to "Body fat"),
        "home.exercises" to ("esercizi" to "exercises"),
        "home.workouts" to ("Allenamenti" to "Workouts"),
        "home.goals" to ("Obiettivi" to "Goals"),
        "home.fat" to ("Grasso" to "Body fat"),
        "home.checkin_done" to ("Check-in completato" to "Check-in done"),
        "home.checkin_saved" to ("Check-in salvato" to "Check-in saved"),
        "home.weight14" to ("Peso · ultimi 14 giorni" to "Weight · last 14 days"),
        "home.week_cmp" to ("Confronto settimane" to "Weekly comparison"),
        "home.avg_weight" to ("Peso medio" to "Avg weight"),
        "home.total_volume" to ("Volume totale" to "Total volume"),
        "home.prev" to ("prec." to "prev"),
        "home.lifetime" to ("lifetime" to "lifetime"),
        "home.backup" to ("Backup" to "Backup"),
        "home.backup_auto" to ("Salvataggio automatico locale" to "Automatic local save"),
        "home.export_data" to ("Esporta dati" to "Export data"),

        "load.readiness" to ("Prontezza (HRV)" to "Readiness (HRV)"),
        "load.ready" to ("Pronto: puoi spingere" to "Ready: you can push"),
        "load.easy" to ("Vai leggero oggi" to "Go easy today"),
        "load.rest" to ("Meglio recuperare" to "Better to rest"),
        "load.need_data" to ("Inserisci l'RMSSD per qualche giorno" to "Log RMSSD for a few days"),
        "load.acwr" to ("Carico acuto/cronico (ACWR)" to "Acute:chronic load (ACWR)"),
        "load.acwr_low" to ("Carico basso: rischio detraining" to "Low load: detraining risk"),
        "load.acwr_ok" to ("Zona ottimale" to "Sweet spot"),
        "load.acwr_high" to ("Carico alto: rischio infortunio" to "High load: injury risk"),
        "load.monotony" to ("Monotonia" to "Monotony"),
        "load.strain" to ("Strain" to "Strain"),
        "load.weekly" to ("Carico settimanale" to "Weekly load"),
        "load.deload" to ("Valuta una settimana di scarico" to "Consider a deload week"),
        "load.title" to ("Carico interno" to "Internal load"),
        "load.building" to ("Baseline in costruzione" to "Building baseline"),
        "load.building_body" to (
            "ACWR, monotonia e strain confrontano il carico recente (7 giorni) con quello abituale (28 giorni): con poche sessioni il valore è completamente fuori scala e non affidabile.\n\nServono almeno %d sessioni con durata + FC media, distribuite su almeno %d giorni. L'ideale sono circa 4 settimane di dati costanti." to
            "ACWR, monotony and strain compare your recent load (7 days) with your habitual load (28 days): with only a few sessions the value is completely out of scale and unreliable.\n\nYou need at least %d sessions with duration + average HR, spread over at least %d days. About 4 weeks of consistent data is ideal."),
        "load.sessions_logged" to ("Sessioni con carico" to "Load sessions"),
        "load.history_days" to ("Giorni di storico" to "Days of history"),

        "nut.title" to ("Nutrizione" to "Nutrition"),
        "nut.cut" to ("Definizione" to "Cut"),
        "nut.maintain" to ("Mantenimento" to "Maintenance"),
        "nut.bulk" to ("Massa" to "Bulk"),
        "nut.protein" to ("Proteine" to "Protein"),
        "nut.carbs" to ("Carboidrati" to "Carbs"),
        "nut.fat" to ("Grassi" to "Fat"),
        "nut.salt" to ("Sale (max)" to "Salt (max)"),
        "nut.carb_high" to ("Carbo giorno ON" to "Carbs training day"),
        "nut.carb_low" to ("Carbo giorno OFF" to "Carbs rest day"),
        "nut.per_week" to ("kg/sett" to "kg/wk"),
        "nut.trend" to ("Trend peso reale" to "Real weight trend"),
        "nut.trend_ok" to ("In linea con l'obiettivo" to "On target"),
        "nut.trend_fast" to ("Troppo veloce" to "Too fast"),
        "nut.trend_slow" to ("Troppo lento" to "Too slow"),
        "nut.trend_wrong" to ("Direzione sbagliata" to "Wrong direction"),
        "nut.lea_risk" to ("Rischio bassa disponibilità energetica" to "Low energy availability risk"),
        "nut.lea_warn" to ("Disponibilità energetica bassa sotto carico" to "Low energy availability under load"),
        "nut.intake_today" to ("Assunzione di oggi" to "Today's intake"),
        "nut.who_note" to ("Range basati su linee guida WHO / ISSN" to "Ranges based on WHO / ISSN guidance"),

        "wk.reps" to ("Rip" to "Reps"),
        "wk.suggested" to ("Suggerito" to "Suggested"),
        "wk.rpe" to ("RPE sessione" to "Session RPE"),
        "wk.duration" to ("Durata" to "Duration"),
        "dur.h" to ("ore" to "hrs"),
        "dur.m" to ("min" to "min"),
        "dur.s" to ("sec" to "sec"),
        "wk.avg_hr" to ("FC media" to "Avg HR"),
        "wk.rmssd" to ("RMSSD" to "RMSSD"),
        "wk.superset" to ("Superset" to "Superset"),
        "wk.method" to ("Metodo" to "Method"),
        "wk.sport" to ("Sport" to "Sport"),
        "wk.distance" to ("Distanza (km)" to "Distance (km)"),
        "wk.pace" to ("Ritmo" to "Pace"),
        "wk.speed" to ("Velocità" to "Speed"),
        "wk.pace_auto" to ("Auto da distanza e durata" to "Auto from distance & duration"),
        "wk.edit_session" to ("Modifica sessione" to "Edit session"),
        "wk.del_session" to ("Elimina sessione" to "Delete session"),
        "wk.add_reps" to ("Aumenta le ripetizioni" to "Add reps"),
        "wk.add_load" to ("Aumenta il carico" to "Add load"),
        "wk.hold" to ("Mantieni il carico" to "Hold the load"),
        "wk.deload_ex" to ("Scarica / tecnica" to "Deload / technique"),
        "wk.select_day" to ("Seleziona giorno" to "Select day"),
        "wk.new_day" to ("Nuovo giorno" to "New day"),
        "wk.recent" to ("Sessioni recenti" to "Recent sessions"),
        "wk.sets_n" to ("serie" to "sets"),
        "wk.cardio" to ("Cardio" to "Cardio"),
        "wk.cardio_types" to ("Attività cardio" to "Cardio activities"),
        "wk.new_cardio" to ("Nuova attività" to "New activity"),
        "wk.edit_cardio" to ("Modifica attività" to "Edit activity"),
        "wk.add_cardio" to ("Aggiungi attività" to "Add activity"),
        "wk.cardio_kind" to ("Tipo di sport" to "Sport kind"),
        "wk.activity_name" to ("Nome attività" to "Activity name"),
        "wk.activity_name_ph" to ("es. Padel, Sci, HIIT…" to "e.g. Padel, Ski, HIIT…"),
        "wk.log_cardio" to ("Registra cardio" to "Log cardio"),
        "wk.est_calories" to ("Calorie stimate" to "Estimated calories"),
        "wk.est_cal_hint" to ("Calcolate dai tuoi dati (peso, età, sesso, FC)." to "Computed from your profile (weight, age, sex, HR)."),
        "wk.calories" to ("Calorie bruciate" to "Calories burned"),
        "wk.cal_override" to ("Modifica manuale" to "Manual override"),
        "wk.cal_hint" to ("Stima dai tuoi dati: con FC più precisa, altrimenti da durata e tipo di attività. Puoi sovrascriverla." to "Estimated from your data: sharper with HR, otherwise from duration and activity type. You can override it."),
        "wk.cal_at_finish" to ("Le calorie vengono stimate al termine dell'allenamento." to "Calories are estimated when you finish the workout."),
        "wk.saved" to ("Salvata" to "Saved"),
        "wk.finish_session" to ("Termina sessione" to "Finish session"),
        "wk.discard_session" to ("Elimina allenamento" to "Discard workout"),
        "wk.discard_q" to ("Eliminare questo allenamento? L'operazione non può essere annullata." to "Discard this workout? This can't be undone."),
        "wk.discarded" to ("Allenamento eliminato" to "Workout discarded"),
        "wk.minimize" to ("Riduci" to "Minimize"),
        "wk.paused" to ("In pausa" to "Paused"),
        "wk.pause" to ("Pausa" to "Pause"),
        "wk.resume" to ("Riprendi" to "Resume"),
        "wk.finish" to ("Termina" to "Finish"),
        "wk.speed_pace" to ("Ritmo" to "Pace"),
        "wk.session_saved" to ("Sessione salvata" to "Session saved"),
        "wk.gps_hint" to ("Attiva la posizione per misurare distanza e ritmo via GPS." to "Enable location to measure distance and pace via GPS."),

        "cal.title" to ("Calendario" to "Calendar"),
        "cal.no_sessions" to ("Nessuna sessione questo mese" to "No sessions this month"),

        "ob.finish" to ("Inizia ad allenarti" to "Start training"),
        "ob.sex" to ("Sesso" to "Sex"),
        "ob.male" to ("Uomo" to "Male"),
        "ob.female" to ("Donna" to "Female"),
        "ob.birth" to ("Data di nascita" to "Date of birth"),
        "ob.goal_mode" to ("Obiettivo" to "Goal"),
        "ob.activity" to ("Livello di attività" to "Activity level"),
        "ob.act_sed" to ("Sedentario" to "Sedentary"),
        "ob.act_light" to ("Leggero" to "Light"),
        "ob.act_mod" to ("Moderato" to "Moderate"),
        "ob.act_high" to ("Alto" to "High"),
        "ob.act_athlete" to ("Atleta" to "Athlete"),
        "ob.act_sed_d" to ("Lavoro d'ufficio, nessun allenamento (×1.2)" to "Desk job, no training (×1.2)"),
        "ob.act_light_d" to ("1-2 allenamenti a settimana (×1.375)" to "1-2 workouts per week (×1.375)"),
        "ob.act_mod_d" to ("3-4 allenamenti a settimana (×1.55)" to "3-4 workouts per week (×1.55)"),
        "ob.act_high_d" to ("5-6 allenamenti a settimana (×1.725)" to "5-6 workouts per week (×1.725)"),
        "ob.act_athlete_d" to ("6-7 + lavoro fisico o doppie sedute (×1.9)" to "6-7 + physical job or 2x/day (×1.9)"),
        "ob.train_days" to ("Giorni/sett" to "Days/week"),
        "ob.rest_hr" to ("FC a riposo" to "Resting HR"),
        "ob.max_hr" to ("FC max" to "Max HR"),
        "set.title" to ("Impostazioni" to "Settings"),
        "set.language" to ("Lingua" to "Language"),
        "set.sleep_track" to ("Traccia il sonno" to "Track sleep"),
        "set.timer" to ("Timer recupero (s)" to "Rest timer (s)"),
        "pc.height" to ("Altezza (m)" to "Height (m)"),
        "pc.start_weight" to ("Peso iniziale" to "Start weight"),
        "pc.goal_weight" to ("Peso obiettivo" to "Goal weight"),
        "pc.goal_bf" to ("Grasso obiettivo %" to "Goal body fat %"),

        "bmi.under" to ("Sottopeso" to "Underweight"),
        "bmi.normal" to ("Normopeso" to "Normal"),
        "bmi.over" to ("Sovrappeso" to "Overweight"),
        "bmi.obese" to ("Obeso" to "Obese"),

        "sport.strength" to ("Forza" to "Strength"),
        "sport.running" to ("Corsa" to "Running"),
        "sport.swimming" to ("Nuoto" to "Swimming"),
        "sport.cycling" to ("Bici" to "Cycling"),
        "sport.walking" to ("Camminata" to "Walking"),
        "sport.other" to ("Altro" to "Other"),

        // --- Goal editor ---
        "goal.change" to ("Cambia obiettivo" to "Change goal"),
        "goal.title" to ("Modifica obiettivo" to "Edit goal"),
        "goal.hint" to ("L'obiettivo resta fisso finché non lo cambi qui. Il peso iniziale è il punto di partenza dei progressi." to
            "Your goal stays fixed until you change it here. Start weight is the baseline your progress is measured from."),
        "goal.start_weight" to ("Peso iniziale (kg)" to "Start weight (kg)"),
        "goal.saved" to ("Obiettivo aggiornato" to "Goal updated"),
        "ob.goal_weight" to ("Peso obiettivo (kg)" to "Goal weight (kg)"),
        "ob.rate" to ("Ritmo (kg/sett)" to "Rate (kg/wk)"),

        // --- Weekly plan / next workout ---
        "plan.week" to ("Piano settimanale" to "Weekly plan"),
        "plan.week_hint" to ("Assegna un allenamento a ogni giorno. Il prossimo allenamento seguirà quest'ordine. Lascia vuoto per la rotazione automatica." to
            "Assign a workout to each day. The next workout follows this order. Leave empty for automatic rotation."),
        "plan.rest" to ("Riposo" to "Rest"),
        "plan.auto" to ("Automatico" to "Auto"),
        "plan.rotation" to ("Rotazione automatica" to "Automatic rotation"),
        "plan.scheduled" to ("Da piano settimanale" to "From weekly plan"),
        "plan.clear" to ("Azzera piano" to "Clear plan"),
        "plan.today" to ("Oggi" to "Today"),
        "plan.saved" to ("Piano salvato" to "Plan saved"),

        // --- Train page hint ---
        "wk.edit_hint" to ("Tocca il piano per modificarlo, premi Play per iniziare subito l'allenamento. Puoi modificare nome, colore ed esercizi. Anche i giorni predefiniti sono completamente personalizzabili." to
            "Tap the card to edit the plan, press Play to start the workout immediately. You can change name, color and exercises. The default days are fully customizable too."),
        "wk.start" to ("Inizia" to "Start"),
        "wk.workout_live" to ("Allenamento in corso" to "Workout in progress"),
        "wk.activity_sub" to ("Sottotitolo attività" to "Activity subtitle"),
        "wk.activity_sub_ph" to ("es. Zona 2, Sprint" to "e.g. Zone 2, Sprint"),
        "chart.gran.day" to ("Giorno" to "Day"),
        "chart.gran.week" to ("Settimana" to "Week"),
        "chart.gran.month" to ("Mese" to "Month"),
        "chart.gran.year" to ("Anno" to "Year"),
        "wk.edit" to ("Modifica" to "Edit"),
        "wk.exercises_n" to ("esercizi" to "exercises"),
        "wk.day" to ("Giorno" to "Day"),

        // --- Adherence / adaptive nutrition ---
        "nut.adaptive" to ("Adattivo" to "Adaptive"),
        "nut.adherence" to ("Costanza" to "Adherence"),
        "nut.logging" to ("Dieta tracciata" to "Nutrition logged"),
        "nut.steps_avg" to ("Passi medi" to "Avg steps"),
        "nut.vol_sessions" to ("Allenamenti (2 sett.)" to "Workouts (2 wks)"),
        "nut.low_logging" to ("Traccia la dieta più spesso per stime più precise" to "Log nutrition more often for sharper estimates"),
        "nut.adjust_pre" to ("Aggiusta di" to "Adjust by"),

        // --- Health data sources / metrics ---
        "hk.optional_note" to ("Questi dati non sono obbligatori ma migliorano prontezza, carico e nutrizione." to
            "This data is not required but improves readiness, load and nutrition."),
        "hk.android_note" to ("Su Android inserisci questi dati a mano. L'import automatico (Health Connect) arriverà più avanti." to
            "On Android enter this data by hand. Automatic import (Health Connect) is coming later."),
        "lbl.steps" to ("Passi" to "Steps"),
        "metric.dfa" to ("DFA-alpha1 (soglia aerobica)" to "DFA-alpha1 (aerobic threshold)"),
        "metric.dfa_soon" to ("Richiede una fascia cardio Bluetooth · in arrivo" to "Needs a Bluetooth chest strap · coming soon"),
        "load.trend_title" to ("Andamento carico · 14 giorni" to "Load trend · 14 days"),

        // --- Info popups (scientific metrics) — v8.3c rewrite, mirrors iOS ---
        "info.trimp.title" to ("TRIMP" to "TRIMP"),
        "info.trimp.body" to (
            "Il TRIMP (Training Impulse) è una metrica scientifica che quantifica il carico di allenamento interno di una sessione. Combina quanto a lungo hai allenato con quanto forte hai spinto, usando la frequenza cardiaca come misura dell'intensità. Il risultato è un singolo punteggio che rappresenta lo stress fisiologico totale imposto al corpo, indipendentemente dal tipo di sport.\n\nPerché è utile: è il modo più preciso per confrontare sessioni di tipo diverso — una corsa leggera da 60 minuti e un interval training da 30 producono carichi molto diversi, e il TRIMP li cattura correttamente.\n\nRange per singola sessione:\n• Recupero / molto facile: 30–80\n• Moderato: 80–150\n• Duro: 150–250\n• Massimale: 250–500+\n\nRange settimanale (volume totale):\n• Principianti: 500–1.000\n• Intermedi: 1.000–1.500\n• Avanzati: 1.500–2.000\n• Élite: oltre 2.000\n\nCosa influenza il valore: la durata della sessione, la frequenza cardiaca media, e la frequenza cardiaca a riposo e massima dal tuo profilo. Senza questi dati il TRIMP non può essere calcolato." to
            "TRIMP (Training Impulse) is a scientific metric that quantifies the internal training load of a session. It combines how long you trained with how hard you pushed, using heart rate as a measure of intensity. The result is a single score representing total physiological stress placed on the body, regardless of sport type.\n\nWhy it matters: it is the most precise way to compare sessions of different types — a 60-minute easy run and a 30-minute interval session carry very different loads, and TRIMP captures that correctly.\n\nSingle-session ranges:\n• Recovery / very easy: 30–80\n• Moderate: 80–150\n• Hard: 150–250\n• Maximal: 250–500+\n\nWeekly ranges (total volume):\n• Beginners: 500–1,000\n• Intermediate: 1,000–1,500\n• Advanced: 1,500–2,000\n• Elite: over 2,000\n\nWhat influences the value: session duration, average heart rate, and resting and maximum heart rate from your profile. Without these inputs TRIMP cannot be calculated."),

        "info.acwr.title" to ("Carico acuto:cronico (ACWR)" to "Acute:Chronic load (ACWR)"),
        "info.acwr.body" to (
            "Il rapporto Acuto:Cronico (ACWR) misura il tuo equilibrio tra allenamento recente e capacità di recupero abituale. Confronta quanto hai fatto nell'ultima settimana rispetto a ciò che il tuo corpo è abituato a gestire nelle ultime quattro settimane, usando una media mobile che dà più peso ai giorni recenti.\n\nPerché è utile: è uno degli indicatori più studiati per prevenire gli infortuni da sovraccarico. Aumentare troppo il volume in poco tempo — senza aver costruito la base — è la causa più comune di infortuni da overuse nello sport.\n\nRange:\n• Sotto 0,8 — stai allenandoti meno del solito (detraining)\n• 0,8–1,3 — zona ottimale: stress sufficiente senza eccessivo rischio\n• 1,3–1,5 — attenzione, rischio infortuni in aumento\n• Sopra 1,5 — zona di rischio elevato\n\nCosa influenza il valore: il carico TRIMP di ogni sessione nelle ultime sette e ventotto settimane. Più sessioni registri con durata e frequenza cardiaca, più l'indicatore è preciso." to
            "The Acute:Chronic Workload Ratio (ACWR) measures the balance between your recent training and your habitual recovery capacity. It compares what you have done in the last week against what your body is used to handling over the last four weeks, using a rolling average that weights recent days more heavily.\n\nWhy it matters: it is one of the most researched indicators for preventing overuse injuries. Increasing volume too quickly — without having built the necessary base — is the most common cause of overuse injuries in sport.\n\nRanges:\n• Below 0.8 — you are training less than usual (detraining)\n• 0.8–1.3 — optimal zone: enough stress without excessive risk\n• 1.3–1.5 — caution, injury risk rising\n• Above 1.5 — high-risk zone\n\nWhat influences the value: the TRIMP load from each session over the last seven and twenty-eight days. The more sessions you log with duration and heart rate, the more accurate this indicator becomes."),

        "info.readiness.title" to ("Prontezza" to "Readiness"),
        "info.readiness.body" to (
            "La Prontezza è un punteggio composito 0–100 che riassume quanto il tuo sistema nervoso e corporeo è recuperato in questo momento. Raccoglie i segnali del mattino — variabilità della frequenza cardiaca, frequenza a riposo e qualità del sonno — e li confronta con la tua media personale degli ultimi due mesi. In questo modo il punteggio è calibrato su di te, non su valori universali.\n\nPerché è utile: ti aiuta a decidere se spingere forte, allenarsi a un'intensità moderata o recuperare. Usarlo insieme all'ACWR e al carico settimanale rende le decisioni di allenamento più intelligenti.\n\nInterpretazione:\n• 70–100 — recupero ottimale, puoi spingere\n• 50–70 — nella tua norma, allenamento normale\n• 30–50 — leggermente sotto la norma, intensità moderata\n• 0–30 — recupero incompleto, preferisci riposo o attività leggera\n\nCosa influenza il valore: l'HRV del mattino ha il peso maggiore, seguito dalla frequenza a riposo e dalle ore di sonno. Con un solo segnale disponibile il punteggio funziona comunque, ma con tutti e tre è molto più affidabile." to
            "Readiness is a composite score from 0 to 100 that summarises how well your nervous system and body have recovered at this moment. It collects your morning signals — heart rate variability, resting heart rate and sleep quality — and compares them to your personal average over the last two months. This way the score is calibrated to you, not to universal reference values.\n\nWhy it matters: it helps you decide whether to train hard, at moderate intensity, or to recover. Using it alongside ACWR and weekly load makes training decisions smarter and more data-driven.\n\nInterpretation:\n• 70–100 — optimal recovery, you can push hard\n• 50–70 — within your normal range, train as planned\n• 30–50 — slightly below normal, keep intensity moderate\n• 0–30 — incomplete recovery, prefer rest or light activity\n\nWhat influences the value: morning HRV carries the most weight, followed by resting heart rate and sleep hours. The score works with just one signal, but it becomes significantly more reliable with all three."),

        "info.load.title" to ("Carico interno · 14 giorni" to "Internal load · 14 days"),
        "info.load.body" to (
            "Il Carico interno misura lo stress cumulativo che gli allenamenti degli ultimi 14 giorni hanno imposto al tuo corpo. Ogni sessione contribuisce con il proprio TRIMP — che dipende da durata e frequenza cardiaca media — e i valori si sommano nel tempo per mostrarti l'andamento del volume di allenamento.\n\nPerché è utile: vedere il carico nel tempo ti permette di riconoscere settimane di picco, periodi di scarico e progressioni troppo rapide prima che diventino infortuni.\n\nNon esiste un valore assoluto ottimale: dipende dal tuo sport, dal tuo livello e dalla fase di allenamento in cui sei. Usa il grafico per confrontare la settimana attuale con le precedenti e per valutare la coerenza del volume nel tempo.\n\nCosa influenza il valore: la durata di ogni sessione e la frequenza cardiaca media registrata. Sessioni senza questi dati non contribuiscono al carico." to
            "Internal load measures the cumulative stress that your training sessions over the last 14 days have placed on your body. Each session contributes its own TRIMP — which depends on duration and average heart rate — and the values accumulate over time to show you how your training volume is developing.\n\nWhy it matters: seeing load over time lets you recognise peak weeks, deload periods and progressions that are too rapid before they become injuries.\n\nThere is no universal optimal value: it depends on your sport, your level and the training phase you are in. Use the chart to compare the current week to previous ones and to evaluate consistency of volume over time.\n\nWhat influences the value: the duration of each session and the average heart rate recorded. Sessions without these data do not contribute to the load."),

        "info.monotony.title" to ("Monotonia" to "Monotony"),
        "info.monotony.body" to (
            "La Monotonia misura quanto variato è il tuo allenamento durante la settimana. Confronta il carico medio giornaliero con la variabilità tra i giorni: se alleni sempre alla stessa intensità senza alternare sessioni dure e leggere, la monotonia sale.\n\nPerché è utile: un allenamento monotono affatica il sistema nervoso in modo cumulativo anche quando il volume totale non è eccessivo. Alternare giorni pesanti, medi e di recupero mantiene la monotonia bassa e riduce il rischio di burnout e sovraccarico.\n\nRange:\n• Sotto 1,5 — variazione sufficiente\n• 1,5–2,0 — attenzione, il programma è abbastanza ripetitivo\n• Sopra 2,0 — alta monotonia, considera di variare l'intensità\n\nCosa influenza il valore: la distribuzione del carico TRIMP tra i giorni della settimana. Più i valori giornalieri si assomigliano, più alta è la monotonia." to
            "Monotony measures how varied your training is during the week. It compares the average daily load against the variation between days: if you always train at the same intensity without alternating hard and easy sessions, monotony rises.\n\nWhy it matters: monotonous training fatigues the nervous system cumulatively even when total volume is not excessive. Alternating heavy, moderate and recovery days keeps monotony low and reduces the risk of burnout and overreaching.\n\nRanges:\n• Below 1.5 — sufficient variation\n• 1.5–2.0 — caution, the programme is fairly repetitive\n• Above 2.0 — high monotony, consider varying intensity\n\nWhat influences the value: the distribution of TRIMP load across the days of the week. The more similar the daily values, the higher the monotony."),

        "info.strain.title" to ("Strain settimanale" to "Weekly strain"),
        "info.strain.body" to (
            "Lo Strain combina il volume totale di allenamento della settimana con la sua monotonia per dare un indice complessivo dello stress accumulato. Non è il semplice totale delle sessioni: due settimane con lo stesso carico totale ma distribuzioni diverse possono avere strain molto differenti.\n\nPerché è utile: è un indicatore precoce di sovraccarico. Valori elevati precedono spesso affaticamento profondo, calo della performance o malanni. Usalo per pianificare le settimane di scarico prima che il corpo te lo chieda da solo.\n\nNon esistono range assoluti validi per tutti: dipende dal tuo livello e dal tuo sport. Ciò che conta è monitorare il trend nel tempo — uno strain in costante aumento senza settimane di recupero è il segnale da tenere d'occhio.\n\nCosa influenza il valore: il carico TRIMP totale della settimana e la monotonia. Settimane ad alta monotonia amplificano lo strain anche con lo stesso volume." to
            "Strain combines the total training volume of the week with its monotony to give an overall index of accumulated stress. It is not a simple sum of sessions: two weeks with the same total load but different distributions can have very different strain values.\n\nWhy it matters: it is an early indicator of overreaching. High values often precede deep fatigue, performance drops or illness. Use it to plan deload weeks before your body forces one on you.\n\nThere are no absolute ranges valid for everyone: it depends on your level and your sport. What matters is monitoring the trend over time — a strain that keeps rising without recovery weeks is the signal to watch.\n\nWhat influences the value: total TRIMP load for the week and monotony. High-monotony weeks amplify strain even with the same volume."),

        "info.rmssd.title" to ("RMSSD — Variabilità della frequenza cardiaca" to "RMSSD — Heart rate variability"),
        "info.rmssd.body" to (
            "L'RMSSD è la misura principale della variabilità della frequenza cardiaca (HRV). Rappresenta la variazione negli intervalli di tempo tra battiti consecutivi, espressa in millisecondi. Valori più alti indicano una maggiore attività del sistema nervoso parasimpatico, che è associata a un buon recupero, bassa fatica e buona salute cardiovascolare.\n\nPerché è utile: l'HRV è uno dei pochi marcatori fisiologici che cambia giorno per giorno in risposta all'allenamento, al sonno, allo stress e alla salute generale. Monitorarlo nel tempo permette di individuare stati di sovraccarico prima che diventino infortuni o malanni.\n\nNon esistono valori assoluti ottimali: l'RMSSD varia enormemente tra individui. Un atleta può avere 80–100 ms, una persona sedentaria 20–30 ms, ed entrambi essere nella propria norma. Ciò che conta è il confronto con la tua media personale nel tempo, non un numero fisso.\n\nCome misurarlo: al mattino, appena sveglio, sdraiato, per 2–5 minuti, sempre nello stesso modo. L'app usa il tuo valore per calcolare il punteggio di Prontezza." to
            "RMSSD is the primary measure of heart rate variability (HRV). It represents the variation in time intervals between consecutive heartbeats, expressed in milliseconds. Higher values indicate greater parasympathetic nervous system activity, which is associated with good recovery, low fatigue and cardiovascular health.\n\nWhy it matters: HRV is one of the few physiological markers that changes day to day in response to training, sleep, stress and general health. Tracking it over time allows you to identify overreaching states before they become injuries or illness.\n\nThere are no universal optimal values: RMSSD varies enormously between individuals. An athlete may have 80–100 ms, a sedentary person 20–30 ms, and both can be within their own normal range. What matters is comparing against your personal average over time, not a fixed number.\n\nHow to measure: in the morning, just after waking, lying down, for 2–5 minutes, always the same way. The app uses your value to calculate your Readiness score."),

        "info.bmi.title" to ("BMI — Indice di massa corporea" to "BMI — Body mass index"),
        "info.bmi.body" to (
            "Il BMI è un indice che mette in relazione il peso corporeo con l'altezza per fornire una stima rapida della composizione corporea a livello di popolazione. È calcolato a partire dal peso e dall'altezza inseriti nel tuo profilo.\n\nPerché è utile: dà un riferimento rapido e standardizzato, usato globalmente in ambito sanitario per identificare persone a rischio di patologie legate al peso.\n\nCategorie standard (OMS):\n• Sotto 18,5 — sottopeso\n• 18,5–24,9 — normopeso\n• 25,0–29,9 — sovrappeso\n• 30,0 e oltre — obesità\n\nLimiti importanti: il BMI non distingue massa muscolare da massa grassa. Un atleta molto muscoloso può avere un BMI nella fascia sovrappeso pur avendo una composizione corporea eccellente. Viceversa, una persona con poco muscolo e molto grasso può risultare normopeso. Quando registri il grasso corporeo, l'app classifica la tua composizione in base a quello, che è un indicatore molto più preciso." to
            "BMI is an index that relates body weight to height to provide a quick population-level estimate of body composition. It is calculated from the weight and height entered in your profile.\n\nWhy it matters: it provides a quick, standardised reference used globally in healthcare to identify people at risk from weight-related conditions.\n\nStandard categories (WHO):\n• Below 18.5 — underweight\n• 18.5–24.9 — normal weight\n• 25.0–29.9 — overweight\n• 30.0 and above — obesity\n\nImportant limitations: BMI does not distinguish muscle mass from fat mass. A highly muscular athlete may have a BMI in the overweight range while having an excellent body composition. Conversely, someone with little muscle and high fat may appear normal weight. When you log body fat, the app classifies your composition based on that, which is a far more accurate indicator."),

        "info.bodyfat.title" to ("Grasso corporeo" to "Body fat"),
        "info.bodyfat.body" to (
            "Il grasso corporeo è la percentuale del tuo peso totale composta da tessuto adiposo. È un indicatore molto più preciso del BMI per valutare la composizione corporea, perché distingue la massa grassa da quella magra (muscoli, ossa, organi).\n\nPerché è utile: monitorare il grasso corporeo nel tempo è il modo più diretto per capire se stai perdendo grasso mantenendo il muscolo, o stai semplicemente perdendo peso. È anche rilevante per la salute metabolica e cardiovascolare.\n\nRange di riferimento per adulti:\n• Donne: 20–32% normale, 14–20% atletico, sotto 14% essenziale\n• Uomini: 10–22% normale, 6–13% atletico, sotto 6% essenziale\n\nCome inserirlo: puoi misurarlo con plicometro, bilancia smart con bioimpedenza, o DEXA. In alternativa usa la stima Navy dell'app, calcolata dalle misure di collo, vita e (per le donne) fianchi. La stima Navy ha un margine di errore di ±3–4%, quindi usa il trend nel tempo piuttosto che il valore assoluto di una singola misurazione." to
            "Body fat is the percentage of your total weight made up of adipose tissue. It is a far more accurate indicator than BMI for evaluating body composition, because it distinguishes fat mass from lean mass (muscles, bones, organs).\n\nWhy it matters: tracking body fat over time is the most direct way to understand whether you are losing fat while preserving muscle, or simply losing weight. It is also relevant for metabolic and cardiovascular health.\n\nReference ranges for adults:\n• Women: 20–32% normal, 14–20% athletic, below 14% essential\n• Men: 10–22% normal, 6–13% athletic, below 6% essential\n\nHow to measure: you can use calipers, a smart scale with bioimpedance, or DEXA. Alternatively use the app's Navy estimate, calculated from neck, waist and (for women) hip measurements. The Navy estimate has a ±3–4% margin of error, so track the trend over time rather than relying on any single measurement."),

        "info.tdee.title" to ("TDEE & metabolismo basale" to "TDEE & basal metabolism"),
        "info.tdee.body" to (
            "Il metabolismo basale (BMR) è la quantità di energia che il tuo corpo consuma in uno stato di completo riposo solo per mantenere le funzioni vitali — respirazione, circolazione, termoregolazione. È influenzato dal peso corporeo, dall'altezza, dall'età e dal sesso biologico.\n\nIl TDEE (Total Daily Energy Expenditure) è il tuo consumo calorico reale nell'arco della giornata, cioè il BMR moltiplicato per un fattore che tiene conto del tuo livello di attività fisica. È il numero di calorie attorno al quale ruota tutta la pianificazione nutrizionale: per perdere peso devi stare sotto, per aumentare sopra, per mantenere intorno a esso.\n\nPerché è utile: avere un punto di partenza preciso per le calorie giornaliere evita di affidarsi a stime generiche che spesso sottostimano o sovrastimano il consumo reale di una persona attiva.\n\nCosa influenza il valore: peso corporeo, altezza, età, sesso biologico e il livello di attività selezionato nel tuo profilo. Cambiando il livello di attività il TDEE cambia immediatamente." to
            "Basal metabolic rate (BMR) is the amount of energy your body uses at complete rest just to maintain vital functions — breathing, circulation, thermoregulation. It is influenced by body weight, height, age and biological sex.\n\nTDEE (Total Daily Energy Expenditure) is your actual daily calorie burn, meaning BMR multiplied by a factor that accounts for your physical activity level. It is the calorie number around which all nutritional planning revolves: to lose weight you need to stay below it, to gain weight above it, to maintain around it.\n\nWhy it matters: having an accurate calorie starting point avoids relying on generic estimates that often under- or overestimate the real consumption of an active person.\n\nWhat influences the value: body weight, height, age, biological sex and the activity level selected in your profile. Changing the activity level updates the TDEE immediately."),

        "info.macros.title" to ("Macronutrienti" to "Macronutrients"),
        "info.macros.body" to (
            "I macronutrienti — proteine, carboidrati e grassi — sono le tre classi di nutrienti che forniscono energia e costruiscono il corpo. Ogni obiettivo nutrizionale (definizione, mantenimento, massa) richiede una distribuzione diversa tra i tre.\n\nPerché è utile: tracciare i macronutrienti separatamente è molto più efficace che contare solo le calorie, perché due diete con le stesse calorie ma macronutrienti diversi producono effetti molto diversi sulla composizione corporea e sulle performance.\n\nRange di riferimento per atleti e persone attive:\n• Proteine: 1,8–2,2 g per kg di peso corporeo. In fase di definizione si sale verso il limite superiore per proteggere la massa muscolare durante il deficit calorico.\n• Grassi: almeno 0,8–1,0 g per kg. I grassi sono essenziali per la produzione ormonale e l'assorbimento delle vitamine liposolubili.\n• Carboidrati: riempiono le calorie rimanenti. Sono il carburante principale per l'allenamento ad alta intensità.\n\nCosa influenza i valori: il tuo peso corporeo, il TDEE, l'obiettivo selezionato e il livello di attività." to
            "Macronutrients — protein, carbohydrates and fat — are the three classes of nutrients that provide energy and build the body. Each nutritional goal (fat loss, maintenance, muscle gain) requires a different distribution among the three.\n\nWhy it matters: tracking macronutrients separately is far more effective than counting calories alone, because two diets with the same calories but different macros produce very different effects on body composition and performance.\n\nReference ranges for athletes and active people:\n• Protein: 1.8–2.2 g per kg of body weight. During a cut, aim toward the upper end to protect muscle mass in a caloric deficit.\n• Fat: at least 0.8–1.0 g per kg. Fats are essential for hormone production and absorption of fat-soluble vitamins.\n• Carbohydrates: fill the remaining calories. They are the primary fuel for high-intensity training.\n\nWhat influences the values: your body weight, TDEE, selected goal and activity level."),

        "info.carbcycle.title" to ("Ciclizzazione dei carboidrati" to "Carb cycling"),
        "info.carbcycle.body" to (
            "La ciclizzazione dei carboidrati consiste nel variare l'apporto di carboidrati in base ai giorni di allenamento, mantenendo invariata la media settimanale. Nei giorni in cui ti alleni i carboidrati aumentano per fornire energia e supportare il recupero muscolare; nei giorni di riposo diminuiscono.\n\nPerché è utile: permette di restare in deficit calorico settimanale per perdere grasso, senza però dover affrontare le sessioni di allenamento con poca energia. È particolarmente efficace per chi si allena 3–5 volte a settimana e vuole ottimizzare sia la composizione corporea che la performance.\n\nIl ciclo dell'app aumenta i carboidrati del 30% nei giorni ON e li riduce del 35% nei giorni OFF. Le calorie totali e le proteine restano costanti ogni giorno.\n\nCosa influenza i valori: il tuo piano settimanale (giorni ON e OFF) e i macronutrienti calcolati dal tuo TDEE e obiettivo." to
            "Carb cycling means varying carbohydrate intake based on training days while keeping the weekly average unchanged. On training days carbs increase to provide energy and support muscle recovery; on rest days they decrease.\n\nWhy it matters: it allows you to stay in a weekly caloric deficit for fat loss, without having to face training sessions with low energy. It is particularly effective for people training 3–5 times per week who want to optimise both body composition and performance.\n\nThe app's cycle increases carbs by 30% on ON days and reduces them by 35% on OFF days. Total calories and protein stay constant every day.\n\nWhat influences the values: your weekly plan (ON and OFF days) and the macronutrients calculated from your TDEE and goal."),

        "info.lea.title" to ("Disponibilità energetica (EA)" to "Energy availability (EA)"),
        "info.lea.body" to (
            "La disponibilità energetica (EA) misura quanta energia rimane disponibile per le funzioni corporee vitali dopo aver sottratto quella consumata durante l'allenamento. È calcolata come media degli ultimi 7 giorni e normalizzata sulla massa magra.\n\nPerché è utile: è l'indicatore più diretto per identificare la Low Energy Availability (LEA), anche nota come RED-S (Relative Energy Deficiency in Sport). La LEA è spesso invisibile dall'esterno ma ha conseguenze gravi: alterazioni ormonali, riduzione della densità ossea, immunosoppressione, cali cognitivi e di performance.\n\nRange clinici:\n• Sopra 45 kcal/kg di massa magra/giorno — zona ottimale\n• 30–45 kcal/kg/giorno — zona di cautela sotto carichi elevati\n• Sotto 30 kcal/kg/giorno — rischio clinico di LEA/RED-S\n\nCosa influenza il valore: le calorie assunte ogni giorno, le calorie stimate bruciate durante l'allenamento e la tua massa magra. Senza tracciare la nutrizione e le sessioni questo dato non può essere calcolato." to
            "Energy availability (EA) measures how much energy remains for vital body functions after subtracting what was burned during training. It is calculated as a 7-day rolling average and normalised to lean body mass.\n\nWhy it matters: it is the most direct indicator for identifying Low Energy Availability (LEA), also known as RED-S (Relative Energy Deficiency in Sport). LEA is often invisible from the outside but has serious consequences: hormonal disruption, reduced bone density, immune suppression, and cognitive and performance decline.\n\nClinical ranges:\n• Above 45 kcal/kg lean mass/day — optimal zone\n• 30–45 kcal/kg/day — caution zone under high training loads\n• Below 30 kcal/kg/day — clinical risk of LEA/RED-S\n\nWhat influences the value: calories consumed each day, estimated calories burned during training and your lean body mass. Without tracking both nutrition and sessions this indicator cannot be calculated."),

        "info.trend.title" to ("Trend del peso" to "Weight trend"),
        "info.trend.body" to (
            "Il trend del peso filtra il rumore delle fluttuazioni quotidiane — causate da idratazione, sale, glicogeno e digestione — per mostrare la variazione di peso reale e pulita nel tempo. Usa le tue ultime pesate per stimare a quale ritmo stai davvero guadagnando o perdendo peso.\n\nPerché è utile: il peso giornaliero da solo può essere fuorviante. Può salire di 1–2 kg in 24 ore per semplice ritenzione idrica anche se sei in deficit, oppure scendere rapidamente per poca acqua senza perdita reale di grasso. Il trend è l'unico dato su cui ha senso prendere decisioni nutrizionali.\n\nNon esiste un valore ottimale universale: dipende dal tuo obiettivo. In definizione un ritmo di −0,5/−1,0% del peso corporeo a settimana è considerato ottimale per preservare la massa muscolare. In massa +0,25/+0,5% a settimana minimizza l'accumulo di grasso.\n\nCosa influenza il valore: la frequenza e la consistenza delle pesate (ideale: mattina, a stomaco vuoto, ogni giorno o quasi) e il numero di misurazioni disponibili. Servono almeno 4 pesate per avere una stima affidabile." to
            "The weight trend filters out the noise of daily fluctuations — caused by hydration, salt, glycogen and digestion — to show your real, clean weight change over time. It uses your recent weigh-ins to estimate at what rate you are actually gaining or losing weight.\n\nWhy it matters: daily weight alone can be misleading. It can rise by 1–2 kg in 24 hours from simple water retention even when you are in a deficit, or drop rapidly from dehydration without any real fat loss. The trend is the only number on which it makes sense to base nutritional decisions.\n\nThere is no universal optimal value: it depends on your goal. On a cut, a rate of −0.5/−1.0% of body weight per week is considered optimal for preserving muscle mass. On a bulk, +0.25/+0.5% per week minimises fat gain.\n\nWhat influences the value: the frequency and consistency of your weigh-ins and the number of measurements available. At least 4 weigh-ins are needed for a reliable estimate."),

        "info.overload.title" to ("Sovraccarico progressivo" to "Progressive overload"),
        "info.overload.body" to (
            "Il sovraccarico progressivo è il principio fondamentale dell'allenamento con i pesi: per continuare a crescere in forza e massa muscolare, il corpo deve essere esposto a uno stimolo via via maggiore nel tempo.\n\nPerché è utile: l'app confronta la tua ultima sessione con il range di ripetizioni obiettivo per suggerirti il passo successivo in modo oggettivo, riducendo l'incertezza sulla gestione dei carichi.\n\nLogica di progressione:\n• Hai completato tutte le serie nel range alto o superiore → è il momento di aumentare il peso\n• Sei dentro il range ma non al limite → cerca di fare più ripetizioni mantenendo la tecnica\n• Sei sotto il range → mantieni il peso attuale e concentrati sulla qualità del movimento\n• Regressione significativa rispetto alla sessione precedente → considera uno scarico\n\nCosa influenza il suggerimento: il numero di serie, le ripetizioni completate e il peso usato nell'ultima sessione, confrontati con il range obiettivo impostato nel piano." to
            "Progressive overload is the fundamental principle of resistance training: to keep growing in strength and muscle mass, the body must be exposed to a progressively greater stimulus over time.\n\nWhy it matters: the app compares your last session against the target rep range to suggest the next step objectively, reducing uncertainty about load management.\n\nProgression logic:\n• You completed all sets at the top of the range or above → time to increase the weight\n• You are within the range but not at the limit → chase more reps while maintaining technique\n• You are below the range → keep the current weight and focus on movement quality\n• Significant regression compared to the previous session → consider a deload\n\nWhat influences the suggestion: the number of sets, reps completed and weight used in the last session, compared against the target range set in your plan."),

        "info.calories.title" to ("Calorie bruciate" to "Calories burned"),
        "info.calories.body" to (
            "Le calorie bruciate mostrate nell'app si riferiscono all'energia attiva consumata durante la sessione di allenamento, escludendo la quota basale che il corpo brucerebbe comunque a riposo.\n\nPerché è utile: avere una stima del consumo calorico per sessione aiuta a calibrare l'apporto nutrizionale nei giorni di allenamento, a pianificare il deficit o il surplus, e a monitorare il volume di lavoro nel tempo.\n\nLa stima dipende dal tipo di sport: per la corsa e il ciclismo si usa la distanza percorsa insieme alla durata per stimare l'intensità; per gli sport di forza si tiene conto della durata, della frequenza cardiaca e del volume di lavoro. Se un dispositivo esterno fornisce un dato più preciso, puoi inserirlo manualmente per sovrascrivere la stima.\n\nCosa influenza il valore: il tipo di sport, la durata, la frequenza cardiaca media, la distanza (dove disponibile) e i dati del tuo profilo come peso e età." to
            "The calories burned shown in the app refer to the active energy consumed during the training session, excluding the basal portion the body would burn at rest anyway.\n\nWhy it matters: having a calorie estimate per session helps you calibrate nutritional intake on training days, plan your deficit or surplus, and monitor training volume over time.\n\nThe estimate depends on sport type: for running and cycling, distance and duration are combined to estimate intensity; for strength training, duration, heart rate and training volume are taken into account. If an external device provides a more accurate number, you can enter it manually to override the estimate.\n\nWhat influences the value: sport type, duration, average heart rate, distance where available, and profile data such as weight and age."),

        "info.pace.title" to ("Ritmo & velocità" to "Pace & speed"),
        "info.pace.body" to (
            "Il ritmo (per la corsa e il nuoto) e la velocità (per il ciclismo) sono calcolati automaticamente a partire dalla distanza e dalla durata che inserisci al termine della sessione. L'app sceglie automaticamente l'unità di misura più appropriata per ogni sport: km/h per il ciclismo, min/km per la corsa e la camminata, min/100m per il nuoto.\n\nPerché è utile: monitorare il ritmo nel tempo permette di misurare i miglioramenti di performance in modo oggettivo. Puoi confrontare sessioni diverse e vedere se a parità di sforzo stai diventando più veloce.\n\nNon esiste un range ottimale universale: il ritmo dipende dal livello dell'atleta, dal tipo di sessione e dall'obiettivo specifico. Confronta il tuo ritmo con le tue sessioni precedenti dello stesso tipo per valutare i progressi nel tempo.\n\nCome funziona: inserendo distanza e durata il valore viene calcolato e mostrato automaticamente. Se preferisci inserire direttamente il ritmo medio, puoi farlo sovrascrivendo il calcolo automatico." to
            "Pace (for running and swimming) and speed (for cycling) are calculated automatically from the distance and duration you enter at the end of a session. The app automatically selects the most appropriate unit for each sport: km/h for cycling, min/km for running and walking, min/100m for swimming.\n\nWhy it matters: tracking pace over time allows you to measure performance improvements objectively. You can compare different sessions and see whether at the same effort level you are getting faster.\n\nThere is no universal optimal range: pace depends on the athlete's level, the type of session and the specific goal. Compare your pace against your previous sessions of the same type to evaluate progress over time.\n\nHow it works: enter distance and duration and the value is calculated and displayed automatically. If you prefer to enter the average pace directly, you can do so by overriding the automatic calculation."),

        "info.activity.title" to ("Livello di attività" to "Activity level"),
        "info.activity.body" to (
            "Il livello di attività è un moltiplicatore che viene applicato al metabolismo basale per stimare il consumo calorico totale giornaliero (TDEE). Tiene conto del fatto che una persona che si allena 5 volte a settimana brucia molte più calorie di una persona sedentaria, anche a parità di corporatura.\n\nPerché è utile: scegliere il livello corretto è il passo più importante per ottenere un TDEE accurato.\n\nLivelli disponibili:\n• Sedentario — lavoro d'ufficio, poco o nessun movimento extra\n• Leggero — 1–2 sessioni di allenamento a settimana\n• Moderato — 3–4 sessioni a settimana\n• Alto — 5–6 sessioni a settimana\n• Atleta — 6–7 sessioni a settimana, o lavoro fisico intenso, o doppie sedute\n\nCosa influenza il valore: il livello selezionato e il metabolismo basale calcolato dal tuo profilo." to
            "The activity level is a multiplier applied to your basal metabolic rate to estimate your total daily calorie expenditure (TDEE). It accounts for the fact that a person training five times per week burns far more calories than a sedentary person of the same size.\n\nWhy it matters: choosing the correct level is the most important step for getting an accurate TDEE.\n\nAvailable levels:\n• Sedentary — desk job, little or no extra movement\n• Light — 1–2 training sessions per week\n• Moderate — 3–4 sessions per week\n• High — 5–6 sessions per week\n• Athlete — 6–7 sessions per week, or physically demanding job, or twice-daily sessions\n\nWhat influences the value: the selected level and the basal metabolic rate calculated from your profile."),

        "info.srpe.title" to ("sRPE — Carico percepito" to "sRPE — Perceived load"),
        "info.srpe.body" to (
            "L'sRPE (session Rate of Perceived Exertion) combina la durata della sessione con quanto ti sei sentito sotto sforzo, su una scala da 1 a 10. È il metodo più semplice per quantificare il carico interno di qualsiasi tipo di allenamento, anche senza un cardiofrequenzimetro.\n\nPerché è utile: permette di stimare il carico di sessioni per cui non hai dati di frequenza cardiaca. È meno preciso del TRIMP ma universalmente applicabile.\n\nScala RPE (Borg CR10):\n• 1–2 — sforzo molto lieve (passeggiata)\n• 3–4 — moderato (puoi parlare comodamente)\n• 5–6 — impegnativo (parli a fatica)\n• 7–8 — molto duro (poche parole per volta)\n• 9–10 — massimale (impossibile parlare)\n\nNell'app l'sRPE è usato principalmente per i dati storici. Il carico delle sessioni nuove si basa sul TRIMP (frequenza cardiaca media), che è più preciso quando i dati cardio sono disponibili." to
            "sRPE (session Rate of Perceived Exertion) combines session duration with how hard you felt you were working, on a scale from 1 to 10. It is the simplest method to quantify the internal load of any type of training, even without a heart rate monitor.\n\nWhy it matters: it allows you to estimate the load of sessions for which you have no heart rate data. It is less precise than TRIMP but universally applicable.\n\nRPE scale (Borg CR10):\n• 1–2 — very light effort (walking)\n• 3–4 — moderate (can speak comfortably)\n• 5–6 — challenging (speaking is effortful)\n• 7–8 — very hard (only a few words at a time)\n• 9–10 — maximal (impossible to speak)\n\nIn the app sRPE is used primarily for historical data. The load of new sessions is based on TRIMP (average heart rate), which is more precise when cardiac data is available."),

        "info.dfa.title" to ("DFA-alpha1 (soglia aerobica)" to "DFA-alpha1 (aerobic threshold)"),
        "info.dfa.body" to (
            "Il DFA-alpha1 è un indice avanzato che analizza la natura frattale degli intervalli tra i battiti cardiaci. Quando l'intensità dell'esercizio sale e si avvicina alla soglia aerobica, il pattern dei battiti cardiaci perde progressivamente la sua complessità frattale. Questo cambiamento è misurabile e permette di individuare la soglia aerobica in tempo reale durante lo sforzo, senza bisogno di un test in laboratorio.\n\nPerché è utile: la soglia aerobica è uno dei marker di fitness più importanti per gli sport di resistenza. Sapere quando la superi durante l'allenamento permette di ottimizzare la distribuzione dell'intensità.\n\nRange:\n• DFA-alpha1 sopra 0,75 — intensità sotto soglia aerobica\n• DFA-alpha1 intorno a 0,75 — zona di soglia aerobica\n• DFA-alpha1 sotto 0,75 — intensità sopra soglia aerobica\n\nQuesta funzione richiede un flusso continuo di dati battito-battito da una fascia cardio Bluetooth. È in arrivo con il supporto BLE dell'app." to
            "DFA-alpha1 is an advanced index that analyses the fractal nature of the intervals between heartbeats. When exercise intensity rises and approaches the aerobic threshold, the heartbeat pattern progressively loses its fractal complexity. This change is measurable and allows the aerobic threshold to be identified in real time during exercise, without the need for a laboratory test.\n\nWhy it matters: the aerobic threshold is one of the most important fitness markers for endurance sports. Knowing when you cross it during training allows you to optimise intensity distribution.\n\nRanges:\n• DFA-alpha1 above 0.75 — intensity below the aerobic threshold\n• DFA-alpha1 around 0.75 — aerobic threshold zone\n• DFA-alpha1 below 0.75 — intensity above the aerobic threshold\n\nThis feature requires a continuous beat-to-beat data stream from a Bluetooth chest strap. It is coming with the app's BLE support."),

        "info.weekplan.title" to ("Piano settimanale" to "Weekly plan"),
        "info.weekplan.body" to (
            "Il piano settimanale ti permette di assegnare uno specifico allenamento, attività cardio o giorno di riposo a ciascun giorno della settimana. Una volta configurato, l'app sa già cosa ti aspetta il giorno successivo e ti mostra il prossimo allenamento in Home.\n\nPerché è utile: avere una struttura fissa riduce il carico decisionale quotidiano e migliora la consistenza — uno dei fattori più importanti per i progressi a lungo termine.\n\nSe non imposti un piano, l'app ruota automaticamente tra i tuoi giorni di allenamento in ordine. Lasciare il piano vuoto fa tornare alla rotazione automatica.\n\nPuoi modificare il piano in qualsiasi momento senza perdere nessun dato storico." to
            "The weekly plan lets you assign a specific workout, cardio activity or rest day to each day of the week. Once configured, the app already knows what awaits you the next day and shows the upcoming workout on the Home screen.\n\nWhy it matters: having a fixed structure reduces daily decision fatigue and improves consistency — one of the most important factors for long-term progress.\n\nIf you do not set a plan, the app automatically rotates through your training days in order. Leaving the plan empty returns to automatic rotation.\n\nYou can modify the plan at any time without losing any historical data."),

        "info.adherence.title" to ("Costanza & TDEE adattivo" to "Adherence & adaptive TDEE"),
        "info.adherence.body" to (
            "Il TDEE adattivo è una stima del tuo consumo calorico reale calcolata direttamente dai tuoi dati registrati, invece di basarsi solo su formule generiche. Quando tracci sia l'alimentazione che il peso per un numero sufficiente di giorni, l'app confronta la variazione di peso osservata con l'apporto calorico medio per stimare quante calorie stai davvero bruciando ogni giorno.\n\nPerché è utile: le formule standard come il TDEE calcolato dal moltiplicatore di attività sono medie di popolazione che possono discostarsi significativamente dal tuo metabolismo reale. Il TDEE adattivo apprende dal tuo corpo specifico e migliora nel tempo.\n\nCosa influenza la stima: la frequenza e la consistenza con cui registri peso, calorie, passi e sessioni di allenamento. Tracciare in modo intermittente riduce l'affidabilità della stima.\n\nLa costanza è anche il fattore più predittivo del raggiungimento degli obiettivi a lungo termine." to
            "The adaptive TDEE is an estimate of your real calorie expenditure calculated directly from your logged data, instead of relying solely on generic formulas. When you track both nutrition and weight for a sufficient number of days, the app compares the observed weight change with average caloric intake to estimate how many calories you are actually burning each day.\n\nWhy it matters: standard formulas like the activity-multiplier TDEE are population averages that can differ significantly from your actual metabolism. The adaptive TDEE learns from your specific body and improves over time.\n\nWhat influences the estimate: the frequency and consistency with which you log weight, calories, steps and training sessions. Intermittent tracking reduces the reliability of the estimate.\n\nConsistency is also the single most predictive factor for achieving long-term goals."),

        "info.steps.title" to ("Passi giornalieri" to "Daily steps"),
        "info.steps.body" to (
            "I passi giornalieri sono una misura dell'attività fisica non strutturata — tutto il movimento che fai al di fuori dell'allenamento formale. Questa componente è chiamata NEAT (Non-Exercise Activity Thermogenesis) e può incidere sul consumo calorico giornaliero totale anche più dell'allenamento stesso.\n\nPerché è utile: molte persone si concentrano esclusivamente sulle sessioni di allenamento trascurando il resto della giornata. Tenere traccia dei passi aiuta a mantenere un livello di attività complessiva sufficiente e migliora la precisione del TDEE adattivo.\n\nRange di riferimento:\n• Sotto 5.000 passi/giorno — livello molto sedentario\n• 5.000–7.500 — poco attivo\n• 7.500–10.000 — moderatamente attivo\n• Sopra 10.000 — attivo\n\nQuesti range sono indicativi: il valore ottimale dipende dal tuo stile di vita e da quanto ti alleni." to
            "Daily steps are a measure of unstructured physical activity — all the movement you do outside of formal training. This component is called NEAT (Non-Exercise Activity Thermogenesis) and can contribute to total daily calorie expenditure even more than training itself.\n\nWhy it matters: many people focus exclusively on training sessions while neglecting the rest of the day. Tracking steps helps maintain a sufficient overall activity level and improves the accuracy of the adaptive TDEE.\n\nReference ranges:\n• Below 5,000 steps/day — very sedentary\n• 5,000–7,500 — lightly active\n• 7,500–10,000 — moderately active\n• Above 10,000 — active\n\nThese ranges are indicative: the optimal value depends on your lifestyle and how much you train."),

        "info.sleep.title" to ("Sonno & recupero" to "Sleep & recovery"),
        "info.sleep.body" to (
            "Il punteggio del sonno rappresenta la qualità complessiva della notte, tenendo conto sia della durata che della qualità percepita del riposo. Il sonno è il fattore di recupero più importante in assoluto: è durante le ore di sonno che avvengono la sintesi proteica muscolare, il ripristino ormonale, la consolidazione della memoria motoria e la rigenerazione del sistema nervoso.\n\nPerché è utile: la qualità del sonno influenza quasi ogni altro indicatore monitorato nell'app — la prontezza, la variabilità della frequenza cardiaca, la performance negli allenamenti e la composizione corporea nel tempo.\n\nNon esiste un punteggio ottimale fisso: confronta il tuo valore con la tua media personale e osserva come le notti migliori si riflettono sugli allenamenti successivi." to
            "The sleep score represents the overall quality of the night, taking into account both duration and perceived quality of rest. Sleep is by far the most important recovery factor: it is during sleep hours that muscle protein synthesis, hormonal restoration, motor memory consolidation and nervous system regeneration occur.\n\nWhy it matters: sleep quality influences almost every other indicator monitored in the app — readiness, heart rate variability, training performance and body composition over time.\n\nThere is no fixed optimal score: compare your value against your personal average and observe how better nights reflect on subsequent training sessions."),

        "info.goal.title" to ("Obiettivo & progressi" to "Goal & progress"),
        "info.goal.body" to (
            "L'obiettivo è il peso corporeo o la percentuale di grasso che vuoi raggiungere. Lo imposti una volta e rimane fisso come riferimento stabile, indipendentemente dalle fluttuazioni quotidiane del peso. La barra di progresso mostra quanto sei avanzato dal tuo punto di partenza verso l'obiettivo.\n\nPerché è utile: avere un obiettivo esplicito e visualizzato consente di valutare i progressi in modo oggettivo, senza farsi ingannare dalle variazioni giornaliere del peso.\n\nCome funziona:\n• Il punto di partenza è il peso iniziale registrato al momento dell'impostazione dell'obiettivo\n• La barra riflette la posizione attuale tra il punto di partenza e l'obiettivo\n• L'obiettivo rimane fisso finché non lo modifichi manualmente\n\nPuoi modificare l'obiettivo in qualsiasi momento. Cambierà anche la direzione suggerita per la nutrizione e il ritmo di progresso atteso." to
            "The goal is the body weight or body fat percentage you want to reach. You set it once and it remains fixed as a stable reference, regardless of daily weight fluctuations. The progress bar shows how far you have come from your starting point toward the goal.\n\nWhy it matters: having an explicit, visualised goal allows you to evaluate progress objectively, without being misled by daily weight variations.\n\nHow it works:\n• The starting point is the initial weight recorded when the goal was set\n• The bar reflects your current position between the starting point and the goal\n• The goal stays fixed until you change it manually\n\nYou can change the goal at any time. It will also update the suggested nutritional direction and expected progress rate."),

        "info.sessions.title" to ("Sessioni totali" to "Total sessions"),
        "info.sessions.body" to (
            "Il contatore delle sessioni totali registra tutte le sessioni di forza e di cardio salvate dall'inizio dell'utilizzo dell'app. Ogni sessione completata e salvata contribuisce al totale, indipendentemente dalla durata o dall'intensità.\n\nPerché è utile: è una misura diretta del volume di lavoro accumulato nel tempo. Un numero in crescita costante è la conferma più semplice e inequivocabile che ti stai allenando con regolarità.\n\nNon esiste un numero ottimale: dipende dalla frequenza di allenamento settimanale e da quanto tempo usi l'app. Ciò che conta è la tendenza nel tempo — un plateau prolungato nel contatore può indicare un periodo di pausa non intenzionale." to
            "The total sessions counter records all strength and cardio sessions saved since you started using the app. Every completed and saved session contributes to the total, regardless of duration or intensity.\n\nWhy it matters: it is a direct measure of the work volume accumulated over time. A steadily growing number is the simplest and most unambiguous confirmation that you are training regularly.\n\nThere is no optimal number: it depends on your weekly training frequency and how long you have been using the app. What matters is the trend over time — a prolonged plateau in the counter may indicate an unintentional rest period."),

        "info.streak.title" to ("Streak di allenamento" to "Training streak"),
        "info.streak.body" to (
            "La streak conta il numero di giorni consecutivi in cui hai registrato almeno un check-in del peso o una sessione di allenamento. È un indicatore della tua consistenza nel tempo, che è il fattore più importante per i progressi a lungo termine indipendentemente dall'obiettivo.\n\nPerché è utile: la consistenza batte quasi sempre l'intensità sporadica. Una persona che si allena 3 volte a settimana ogni settimana per un anno ottiene risultati nettamente superiori a chi si allena intensamente per 2 mesi e poi si ferma.\n\nCome funziona:\n• Si incrementa ogni giorno in cui registri almeno un check-in o una sessione\n• Rimane attiva per tutto il giorno corrente — non si azzera finché la giornata non è finita\n• Si interrompe solo quando un giorno intero passa senza nessuna registrazione\n\nNon esiste un numero magico di giorni da raggiungere: l'obiettivo è che il valore cresca nel tempo." to
            "The streak counts the number of consecutive days in which you logged at least one weight check-in or a training session. It is an indicator of your consistency over time, which is the single most important factor for long-term progress regardless of goal.\n\nWhy it matters: consistency almost always beats sporadic intensity. A person who trains three times a week every week for a year achieves far better results than someone who trains intensely for two months and then stops.\n\nHow it works:\n• It increments every day you log at least one check-in or session\n• It stays alive for the entire current day — it does not reset before the day is over\n• It breaks only when a full day passes with nothing logged\n\nThere is no magic number of days to reach: the goal is for the value to grow over time."),

        // --- Day logging / rest / recommended fields ------------------------
        "home.tap_to_log" to ("Tocca un giorno per registrare" to "Tap a day to log"),
        "day.title" to ("Registra giornata" to "Log day"),
        "day.hint" to ("Scegli cosa hai fatto in questo giorno: un allenamento di forza, un'attività cardio o riposo. I dati partono dall'ultima volta e restano modificabili." to
            "Choose what you did on this day: a strength workout, a cardio activity or rest. Data starts from last time and stays editable."),
        "day.mark_rest" to ("Segna come riposo" to "Mark as rest"),
        "day.clear_rest" to ("Rimuovi riposo" to "Remove rest"),
        "load.recommended" to ("Consigliato" to "Recommended"),
        "load.sensor" to ("Sensore HRV" to "HRV sensor"),
        "load.trimp_hint" to ("Carico cardio della sessione" to "Session cardio load"),

        // --- TRIMP card -----------------------------------------------------
        "trimp.title" to ("Carico cardio (TRIMP)" to "Cardio load (TRIMP)"),
        "trimp.this_week" to ("Questa settimana" to "This week"),
        "trimp.last_week" to ("Settimana scorsa" to "Last week"),
        "trimp.last" to ("Ultima:" to "Last:"),
        "trimp.note" to ("Somma del TRIMP delle sessioni con FC media. Più alto = più stress cardiovascolare." to
            "Sum of session TRIMP from average HR. Higher = more cardiovascular stress."),

        // --- Navigation (sub labels) ---
        "nav.nutrition" to ("Nutrizione" to "Nutrition"),
        "sub.home" to ("Dashboard" to "Dashboard"),
        "sub.train" to ("Log allenamento" to "Workout log"),
        "sub.body" to ("Misurazioni & Check-in" to "Measurements & Check-in"),
        "sub.nutrition" to ("Alimentazione" to "Nutrition"),
        "sub.stats" to ("Statistiche" to "Statistics"),
        "body.recovery" to ("Recupero" to "Recovery"),
        "nutp.today" to ("Oggi" to "Today"),
        "nutp.log_today" to ("Registra oggi" to "Log today"),
        "nutp.edit_today" to ("Modifica oggi" to "Edit today"),
        "nutp.my_foods" to ("I miei alimenti" to "My foods"),
        "nutp.no_foods" to ("Nessun alimento salvato. Scansiona o crea il primo." to "No foods saved yet. Scan or create your first one."),

        // --- Common extras ---
        "next" to ("Avanti" to "Next"),
        "back" to ("Indietro" to "Back"),
        "start" to ("Inizia" to "Start"),
        "finish" to ("Termina" to "Finish"),
        "today" to ("Oggi" to "Today"),
        "optional" to ("opzionale" to "optional"),
        "kg" to ("kg" to "kg"),

        // --- Home extras ---
        "home.bmi" to ("BMI" to "BMI"),
        "home.goal_weight" to ("Obiettivo peso" to "Weight goal"),
        "home.goal_bf" to ("Obiettivo grasso" to "Body-fat goal"),
        "home.sleep_score" to ("Punteggio sonno" to "Sleep score"),
        "home.weight_14" to ("Peso ultimi 14 giorni" to "Weight last 14 days"),
        "home.recent_pr" to ("Record recenti" to "Recent PRs"),
        "home.week_cmp_title" to ("Confronto settimane" to "Weekly comparison"),
        "home.wake_hr" to ("FC riposo/risveglio" to "Resting/waking HR"),
        "home.health_autofill" to ("Compilato da Health Connect quando disponibile · modificabile" to "Filled from Health Connect when available · editable"),
        "home.export" to ("Esporta JSON" to "Export JSON"),
        "home.import" to ("Importa JSON" to "Import JSON"),

        // --- Nutrition ---
        "nut.mode" to ("Modalità energetica" to "Energy mode"),
        "nut.target" to ("Calorie obiettivo" to "Calorie target"),
        "nut.tdee" to ("TDEE" to "TDEE"),
        "nut.bmr" to ("Metabolismo basale" to "Basal metabolism"),
        "nut.rate_target" to ("Variazione obiettivo" to "Target change"),
        "nut.per_week" to ("kg/sett" to "kg/wk"),
        "nut.lea" to ("Disponibilità energetica" to "Energy availability"),
        "nut.calendar" to ("Calendario nutrizione" to "Nutrition calendar"),
        "nut.cal_hint_tap" to ("Tocca un giorno per inserire o modificare le calorie" to "Tap a day to add or edit calories"),
        "nut.edit_day" to ("Modifica nutrizione" to "Edit nutrition"),
        "nut.quick" to ("Totale rapido" to "Quick total"),
        "nut.per_meal" to ("Per pasto" to "Per meal"),
        "nut.foods" to ("Alimenti" to "Foods"),
        "nut.entry_mode" to ("Modalità di inserimento" to "Entry mode"),
        "nut.day_total" to ("Totale giornaliero" to "Daily total"),
        "nut.kcal" to ("Calorie" to "Calories"),
        "nut.no_log" to ("Nessun dato nutrizionale" to "No nutrition logged"),
        "nut.charts" to ("Grafici nutrizione" to "Nutrition charts"),
        "nut.charts_hint" to ("Registra le calorie per 2+ giorni per vedere i grafici." to "Log calories for 2+ days to see charts."),
        "nut.saved" to ("Nutrizione salvata" to "Nutrition saved"),
        "nut.cleared" to ("Dati nutrizionali rimossi" to "Nutrition cleared"),
        "nut.adjust" to ("Aggiusta di %d kcal" to "Adjust by %d kcal"),
        "nut.vol_sessions" to ("Allenamenti (2 sett.)" to "Workouts (2 wks)"),
        "nut.adaptive_on" to ("TDEE appreso dai tuoi dati reali" to "TDEE learned from your real data"),

        // --- Meal slots ---
        "meal.breakfast" to ("Colazione" to "Breakfast"),
        "meal.lunch" to ("Pranzo" to "Lunch"),
        "meal.dinner" to ("Cena" to "Dinner"),
        "meal.snacks" to ("Spuntini" to "Snacks"),

        // --- Food ---
        "food.title" to ("Alimenti" to "Foods"),
        "food.search" to ("Cerca un alimento" to "Search a food"),
        "food.scan" to ("Scansiona" to "Scan"),
        "food.new" to ("Nuovo" to "New"),
        "food.new_title" to ("Alimento" to "Food"),
        "food.none" to ("Nessun alimento salvato. Creane uno o scansiona un barcode." to "No saved foods yet. Create one or scan a barcode."),
        "food.add" to ("Aggiungi alimento" to "Add food"),
        "food.name" to ("Nome" to "Name"),
        "food.per100_label" to ("Valori per 100" to "Values per 100"),
        "food.liquid" to ("Liquido (misura in ml)" to "Liquid (measured in ml)"),
        "food.save_food" to ("Salva alimento" to "Save food"),
        "food.amount" to ("Quantità" to "Amount"),
        "food.day_foods" to ("Alimenti di oggi" to "Today's foods"),
        "food.looking" to ("Ricerca prodotto…" to "Looking up product…"),
        "food.scan_hint" to ("Inquadra il codice a barre" to "Point at the barcode"),
        "food.scan_unavailable" to ("Scansione non disponibile su questo dispositivo. Inserisci l'alimento a mano." to "Scanning isn't available on this device. Add the food by hand."),
        "food.sort" to ("Ordina" to "Sort"),
        "food.sort.recent" to ("Recenti" to "Recent"),
        "food.sort.alpha" to ("A-Z" to "A-Z"),
        "food.sort.kcal" to ("Kcal/100g" to "Kcal/100g"),
        "food.sort.ratio" to ("Kcal:Prot" to "Kcal:Prot"),
        "food.brand" to ("Marca" to "Brand"),
        "st.section_workout" to ("Allenamento" to "Workout"),
        "st.section_nutrition" to ("Nutrizione" to "Nutrition"),

        // --- Recipe ---
        "recipe.title" to ("Ricette" to "Recipes"),
        "recipe.new" to ("Nuova ricetta" to "New recipe"),
        "recipe.edit" to ("Modifica ricetta" to "Edit recipe"),
        "recipe.none" to ("Nessuna ricetta salvata. Creane una." to "No saved recipes. Create one."),
        "recipe.name_placeholder" to ("es. Pasta al pesto" to "e.g. Pasta with pesto"),
        "recipe.input_mode" to ("Modalità di creazione" to "Creation mode"),
        "recipe.manual" to ("Manuale" to "Manual"),
        "recipe.from_ingredients" to ("Da alimenti" to "From foods"),
        "recipe.per_serving_toggle" to ("Valori totali ricetta + porzioni" to "Total recipe values + servings"),
        "recipe.per_serving_hint" to ("Inserisci i valori totali e quante porzioni fa la ricetta" to "Enter total values and how many servings the recipe makes"),
        "recipe.servings" to ("Porzioni" to "Servings"),
        "recipe.total_macros_label" to ("Valori totali ricetta" to "Total recipe values"),
        "recipe.ingredients" to ("Ingredienti" to "Ingredients"),
        "recipe.add_ingredient" to ("Aggiungi ingrediente" to "Add ingredient"),
        "recipe.serving" to ("porzione" to "serving"),
        "recipe.servings_short" to ("porz" to "srv"),

        // --- Workout live extras ---
        "wk.live" to ("Allenamento live" to "Live workout"),
        "wk.add_ex" to ("Aggiungi esercizio" to "Add exercise"),
        "wk.set" to ("Serie" to "Set"),
        "wk.last_time" to ("Ultima volta" to "Last time"),
        "wk.notes" to ("Note" to "Notes"),
        "wk.finish_ask" to ("Terminare e salvare la sessione?" to "Finish and save the session?"),
        "wk.last" to ("Ultima" to "Last"),
        "wk.others" to ("altri" to "others"),
        "wk.last_time_label" to ("Ultima volta" to "Last time"),
        "wk.try" to ("Prova" to "Try"),
        "wk.add_set" to ("+ Serie" to "+ Set"),
        "wk.timer" to ("Timer" to "Timer"),
        "wk.vol" to ("Vol" to "Vol"),
        "wk.max" to ("Max" to "Max"),
        "wk.add_note" to ("+ Note" to "+ Note"),
        "wk.note_ph" to ("Note…" to "Notes…"),
        "wk.add_ex_ph" to ("es. Dip alle parallele" to "e.g. Parallel bar dips"),
        "wk.add_ex_hint" to ("Aggiunto alla sessione e salvato nel giorno per le prossime volte." to "Added to the session and saved to the day for next time."),
        "wk.ex_added" to ("Esercizio aggiunto" to "Exercise added"),
        "wk.nothing_save" to ("Nessuna serie da salvare" to "No sets to save"),
        "wk.save_session" to ("Salva sessione" to "Save session"),
        "wk.cardio_saved" to ("Attività salvata" to "Activity saved"),
        "wk.cardio_deleted" to ("Attività eliminata" to "Activity deleted"),
        "wk.delete_cardio_q" to ("Eliminare questa attività?" to "Delete this activity?"),
        "wk.edit_hint" to ("Tocca il piano per modificarlo. Puoi modificare nome, colore ed esercizi. Anche i giorni predefiniti sono completamente personalizzabili." to
            "Tap the card to edit the plan. You can change name, color and exercises. The default days are fully customizable too."),
        "wk.watch_live" to ("In diretta da orologio" to "Live from your watch"),
        "wk.watch_synced" to ("Dati importati da Health Connect" to "Data imported from Health Connect"),
        "wk.workout_live" to ("Allenamento in corso" to "Workout in progress"),
        "wk.recreate_plan" to ("Ricrea come scheda" to "Recreate as plan"),

        // --- Plan editor ---
        "pe.subtitle_hint" to ("Personalizza esercizi, serie e ripetizioni" to "Customize exercises, sets and reps"),
        "pe.day_name" to ("Nome giorno" to "Day name"),
        "pe.day_name_ph" to ("es. Push, Petto, Gambe…" to "e.g. Push, Chest, Legs…"),
        "pe.subtitle" to ("Sottotitolo" to "Subtitle"),
        "pe.subtitle_ph" to ("es. Spalle + Petto" to "e.g. Shoulders + Chest"),
        "pe.color" to ("Colore" to "Color"),
        "pe.exercises" to ("Esercizi" to "Exercises"),
        "pe.no_ex" to ("Nessun esercizio. Aggiungine uno qui sotto." to "No exercises. Add one below."),
        "pe.ex_name_ph" to ("Nome esercizio" to "Exercise name"),
        "pe.sets" to ("Serie" to "Sets"),
        "pe.save_changes" to ("Salva modifiche" to "Save changes"),
        "pe.delete_day" to ("Elimina giorno" to "Delete day"),
        "pe.delete_day_q" to ("Eliminare questo giorno?" to "Delete this day?"),
        "pe.group" to ("Gruppo" to "Group"),

        // --- Stats ---
        "st.overview" to ("Panoramica" to "Overview"),
        "st.records" to ("Record" to "Records"),
        "st.progress" to ("Progressi" to "Progress"),
        "st.history" to ("Storico" to "History"),
        "st.profile" to ("Profilo" to "Profile"),
        "st.maxes" to ("I tuoi massimali" to "Your maxes"),
        "st.maxes_hint" to ("Crea un giorno con esercizi per tracciare i record." to "Create a day with exercises to track records."),
        "st.select_ex" to ("Seleziona esercizio" to "Select exercise"),
        "st.choose" to ("— Scegli —" to "— Choose —"),
        "st.max_per_session" to ("Peso massimo per sessione" to "Max weight per session"),
        "st.vol_per_session" to ("Volume totale per sessione" to "Total volume per session"),
        "st.first" to ("Prima" to "First"),
        "st.last" to ("Ultima" to "Last"),
        "st.delta" to ("Delta" to "Delta"),
        "st.progress_hint" to ("Seleziona un esercizio per vedere la progressione." to "Select an exercise to see progression."),
        "st.no_data" to ("Nessun dato" to "No data"),
        "st.empty_history" to ("Storico vuoto" to "No history"),
        "st.no_workouts" to ("Nessun allenamento registrato." to "No workouts logged."),
        "st.weight90" to ("Peso · 90 giorni" to "Weight · 90 days"),
        "st.sleep" to ("Sleep score" to "Sleep score"),
        "st.bmi_time" to ("BMI" to "BMI"),
        "st.composition" to ("Composizione corporea" to "Body composition"),
        "st.lean" to ("Magra" to "Lean"),
        "st.fat" to ("Grasso" to "Fat"),
        "st.charts_hint" to ("Registra peso e sleep per 2+ giorni per vedere i grafici." to "Log weight and sleep for 2+ days to see charts."),
        "st.search_ex" to ("Cerca esercizio" to "Search exercise"),
        "st.all_exercises" to ("Tutti gli esercizi" to "All exercises"),
        "st.steps_time" to ("Passi" to "Steps"),
        "st.hr_time" to ("Frequenza cardiaca" to "Heart rate"),
        "st.hrv_time" to ("HRV" to "HRV"),
        "st.rest_hr" to ("Riposo" to "Resting"),
        "st.sleep_hr" to ("Sonno" to "Sleep"),
        "st.vo2_time" to ("VO₂ max" to "VO₂ max"),
        "st.hrv_sdnn" to ("SDNN" to "SDNN"),
        "st.sort.sessions" to ("Sessioni" to "Sessions"),
        "st.all_variants" to ("Tutte" to "All"),
        "st.variants" to ("varianti" to "variants"),
        "st.edit_family" to ("Famiglia esercizio" to "Exercise family"),
        "st.family_hint" to ("Le varianti che condividono la stessa famiglia hanno una sola linea di progressi. Cambia famiglia per unirle o separarle." to
            "Variants sharing a family share one progress line. Change the family to merge or split them."),
        "st.family" to ("Famiglia (movimento base)" to "Family (base movement)"),
        "st.muscle" to ("Muscolo" to "Muscle"),

        // --- Profile card ---
        "pc.title" to ("Obiettivi & profilo" to "Goals & profile"),
        "pc.timer" to ("Recupero timer (s)" to "Rest timer (s)"),
        "pc.save" to ("Salva profilo" to "Save profile"),
        "pc.saved" to ("Profilo salvato" to "Profile saved"),

        // --- Onboarding extras ---
        "ob.welcome" to ("Benvenuto" to "Welcome"),
        "ob.intro" to ("Configura il tuo profilo per personalizzare obiettivi, calorie e carichi." to
            "Set up your profile to personalize goals, calories and load."),
        "ob.language" to ("Lingua" to "Language"),
        "ob.height" to ("Altezza" to "Height"),
        "ob.weight" to ("Peso attuale" to "Current weight"),
        "ob.per_wk" to ("sett" to "wk"),

        // --- Settings extras ---
        "set.profile" to ("Profilo & obiettivi" to "Profile & goals"),
        "set.edit_profile" to ("Modifica profilo" to "Edit profile"),
        "set.units" to ("Unità di misura" to "Units"),
        "set.metric" to ("Metrico (kg, cm, km)" to "Metric (kg, cm, km)"),
        "set.imperial" to ("Imperiale (lb, in, mi)" to "Imperial (lb, in, mi)"),

        // --- Body extras ---
        "body.analysis" to ("Analisi corporea" to "Body analysis"),
        "body.fat" to ("Grasso" to "Fat"),
        "body.lean" to ("Magra" to "Lean"),
        "body.goal" to ("goal" to "goal"),
        "body.fat_input" to ("Grasso % · manuale o Navy (collo + vita)" to "Body fat % · manual or Navy (neck + waist)"),
        "body.measures" to ("Misurazioni settimanali" to "Weekly measurements"),
        "body.save_measures" to ("Salva misurazioni" to "Save measurements"),
        "body.no_data" to ("Nessun dato" to "No data"),
        "body.stable" to ("stabile" to "stable"),
        "body.all_measures" to ("Tutte le misurazioni" to "All measurements"),
        "body.measures_saved" to ("Misurazioni salvate" to "Measurements saved"),
        "body.fat_saved" to ("Grasso % salvato" to "Body fat % saved"),
        "body.neck" to ("collo" to "neck"),
        "body.waist" to ("vita" to "waist"),
        "body.imported" to ("Dati importati" to "Data imported"),
        "body.invalid_file" to ("File non valido" to "Invalid file"),
        "body.import_cancelled" to ("Importazione annullata" to "Import cancelled"),
        "body.sleep" to ("Sonno" to "Sleep"),
        "body.sleep_hr" to ("FC nel sonno" to "Sleeping HR"),
        "body.hips" to ("Fianchi" to "Hips"),
        "body.navy_need_hips" to ("Aggiungi la misura dei fianchi per stimare il grasso (formula femminile Navy)." to
            "Add your hip measurement to estimate body fat (women's Navy formula)."),
        "body.sleep_manual" to ("Inserimento manuale" to "Manual entry"),
        "body.sleep_hours" to ("Ore di sonno" to "Sleep hours"),
        "meas.waist" to ("Vita" to "Waist"),
        "meas.chest" to ("Petto" to "Chest"),
        "meas.arms" to ("Braccia" to "Arms"),
        "meas.legs" to ("Gambe" to "Legs"),
        "meas.neck" to ("Collo" to "Neck"),
        "meas.hips" to ("Fianchi" to "Hips"),

        // --- BMI extras ---
        "home.bmi_comment" to ("BMI" to "BMI"),
        "bf.essential" to ("Essenziale" to "Essential"),
        "bf.athlete" to ("Atleta" to "Athlete"),
        "bf.fitness" to ("Fitness" to "Fitness"),
        "bf.average" to ("Nella media" to "Average"),
        "bf.overweight" to ("Sovrappeso" to "Overweight"),
        "bf.obese" to ("Obeso" to "Obese"),
        "bf.muscular" to ("Muscoloso (BMI alto, grasso basso)" to "Muscular (high BMI, low fat)"),
        "bf.category" to ("Categoria grasso" to "Body-fat category"),

        // --- Health Connect (Android-specific, mirrors iOS hk.* keys) ---
        "hk.connect" to ("Collega Health Connect" to "Connect Health Connect"),
        "hk.connected" to ("Health Connect collegato" to "Health Connect connected"),
        "hk.sync" to ("Sincronizza ora" to "Sync now"),
        "hk.synced" to ("Dati sincronizzati" to "Data synced"),
        "hk.hint" to ("Importa automaticamente passi, energia attiva, minuti di attività, frequenza cardiaca a riposo, HRV e gli allenamenti registrati da qualunque orologio compatibile (Garmin, Polar, Amazfit, Samsung…)." to
            "Automatically imports steps, active energy, exercise minutes, resting heart rate, HRV and workouts recorded by any compatible watch (Garmin, Polar, Amazfit, Samsung…)."),
        "hk.imported" to ("Da Health Connect" to "From Health Connect"),
        "hk.imported_n" to ("allenamenti importati" to "workouts imported"),
        "hk.choose" to ("Cosa importare" to "What to import"),
        "hk.import_workouts" to ("Importa allenamenti passati" to "Import past workouts"),
        "hk.import_workouts_hint" to ("Importa gli allenamenti già registrati in Health Connect — da Garmin, Polar, Amazfit, Samsung Health e altri orologi compatibili." to
            "Import workouts already recorded in Health Connect — from Garmin, Polar, Amazfit, Samsung Health and other compatible watches."),
        "hk.from_health" to ("Da Health Connect" to "From Health Connect"),
        "hk.cat.steps" to ("Passi" to "Steps"),
        "hk.cat.restHR" to ("FC a riposo" to "Resting heart rate"),
        "hk.cat.hrv" to ("HRV (SDNN)" to "HRV (SDNN)"),
        "hk.cat.sleep" to ("Sonno" to "Sleep"),
        "hk.cat.sleepHR" to ("FC nel sonno" to "Sleeping heart rate"),
        "hk.cat.activeKcal" to ("Energia attiva" to "Active energy"),
        "hk.cat.exerciseMin" to ("Minuti di attività" to "Exercise minutes"),
        "hk.cat.vo2max" to ("VO₂ max" to "VO₂ max"),
        "hk.unavailable" to ("Health Connect non disponibile su questo dispositivo" to "Health Connect unavailable on this device"),
        "hk.optional_note" to ("Questi dati non sono obbligatori ma migliorano prontezza, carico e nutrizione." to
            "This data is not required but improves readiness, load and nutrition."),

        // --- Watch / wearable guide (Android version) ---
        "guide.open" to ("Collega il tuo orologio" to "Connect your watch"),
        "guide.title" to ("Collega il tuo orologio" to "Connect your watch"),
        "guide.intro" to ("Qualunque orologio che scrive su Health Connect può alimentare l'app automaticamente. Attiva la sincronizzazione nell'app del tuo orologio e abilita Health Connect qui." to
            "Any watch that writes to Health Connect can feed the app automatically. Enable syncing in your watch's app and connect Health Connect here."),
        "guide.health_group" to ("Orologi compatibili con Health Connect" to "Watches compatible with Health Connect"),

        // --- Day logging extras ---
        "day.logged" to ("Allenamenti di questo giorno" to "Workouts on this day"),
        "day.mark_rest" to ("Segna come riposo" to "Mark as rest"),
        "day.clear_rest" to ("Rimuovi riposo" to "Remove rest"),
        "day.import_health" to ("Importa da Health Connect" to "Import from Health Connect"),
        "day.health_loading" to ("Cerco allenamenti in Health Connect…" to "Checking Health Connect…"),
        "day.health_none" to ("Nessun allenamento da importare per questo giorno. Assicurati che l'app abbia accesso a Health Connect." to
            "No workouts to import for this day. Make sure the app has access to Health Connect."),
        "day.health_recheck" to ("Ricontrolla" to "Re-check"),
        "cal.tap_hint" to ("Tocca un giorno per registrare un allenamento o il riposo" to "Tap a day to log a workout or rest"),
        "load.no_load_yet" to ("Inserisci durata + RPE (o FC) per vedere il carico" to "Enter duration + RPE (or HR) to see load"),

        // --- Readiness factor chips ---
        "load.from" to ("Da" to "From"),
        "load.sig.hrv" to ("HRV" to "HRV"),
        "load.sig.hr" to ("FC" to "HR"),
        "load.sig.sleep" to ("Sonno" to "Sleep"),
        "load.srpe" to ("sRPE (durata × RPE)" to "sRPE (duration × RPE)"),
        "load.trimp" to ("TRIMP" to "TRIMP"),
        "load.building_body" to (
            "ACWR, monotonia e strain confrontano il carico recente (7 giorni) con quello abituale (28 giorni): con poche sessioni il valore è completamente fuori scala e non affidabile.\n\nServono almeno %d sessioni con durata + FC media, distribuite su almeno %d giorni. L'ideale sono circa 4 settimane di dati costanti." to
            "ACWR, monotony and strain compare your recent load (7 days) with your habitual load (28 days): with only a few sessions the value is completely out of scale and unreliable.\n\nYou need at least %d sessions with duration + average HR, spread over at least %d days. About 4 weeks of consistent data is ideal."),

        // --- Muscle groups ---
        "mg.chest" to ("Petto" to "Chest"),
        "mg.back" to ("Schiena" to "Back"),
        "mg.legs" to ("Gambe" to "Legs"),
        "mg.shoulders" to ("Spalle" to "Shoulders"),
        "mg.arms" to ("Braccia" to "Arms"),
        "mg.core" to ("Core" to "Core"),
        "mg.fullbody" to ("Tutto il corpo" to "Full body"),
        "mg.cardio" to ("Cardio" to "Cardio"),
        "mg.other" to ("Altro" to "Other"),

        // --- Exercise library ---
        "ex.library" to ("Libreria esercizi" to "Exercise library"),

        // --- Per-set effort tracking ---
        "wk.effort" to ("Sforzo" to "Effort"),
        "wk.effort.off" to ("—" to "—"),
        "wk.effort.rir" to ("RIR" to "RIR"),
        "wk.effort.rpe" to ("RPE" to "RPE"),
        "wk.effort.fail" to ("FAIL" to "FAIL"),
        "wk.effort.hint" to ("RIR = ripetizioni prima del cedimento · RPE = sforzo 1-10 · FAIL = cedimento raggiunto" to
            "RIR = reps before failure · RPE = perceived effort 1-10 · FAIL = hit failure"),

        // --- Bodyweight exercise ---
        "wk.bodyweight" to ("Corpo libero" to "Bodyweight"),
        "wk.bw_hint" to ("Il campo peso è il carico aggiunto. 0 = solo peso corporeo, negativo = macchina assistita." to
            "Weight field is added load. 0 = pure bodyweight, negative = machine-assisted."),

        // --- Calendar day label ---
        "wk.day_created" to ("Giorno creato" to "Day created"),
        "wk.day_updated" to ("Giorno aggiornato" to "Day updated"),
        "wk.day_deleted" to ("Giorno eliminato" to "Day deleted"),

        // --- Progression badges (live workout) ---
        "wk.prog.add_load" to ("Aumenta il carico" to "Add load"),
        "wk.prog.add_reps" to ("Aggiungi ripetizioni" to "Add reps"),

        // --- Settings extras ---
        "set.import_workouts" to ("Importa allenamenti da Health Connect" to "Import workouts from Health Connect"),
        "set.health_cats" to ("Categorie da importare" to "Categories to import")
    )
}

/** Free helper mirroring the iOS `t("key")`. */
fun t(key: String): String = L.t(key)
