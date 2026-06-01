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
        "wk.edit_hint" to ("Tocca Modifica su un giorno per rinominarlo, cambiarne colore ed esercizi o eliminarlo. Anche i giorni predefiniti sono completamente personalizzabili." to
            "Tap Edit on a day to rename it, change its color and exercises, or delete it. The default days are fully customizable too."),
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

        // --- Info popups (scientific metrics) ---
        "info.readiness.title" to ("Prontezza (HRV)" to "Readiness (HRV)"),
        "info.readiness.body" to (
            "Stima quanto sei recuperato dalla variabilità della frequenza cardiaca (HRV), misurata come RMSSD che inserisci al mattino. Usiamo il logaritmo naturale dell'RMSSD (lnRMSSD) e lo confrontiamo con la tua media degli ultimi ~60 giorni con uno z-score. Il punteggio 0-100 è 50 + 20 × z. Alto = recuperato, puoi spingere. Basso = sotto la norma, meglio andare leggeri. Servono almeno 5 misurazioni." to
            "Estimates how recovered you are from heart-rate variability (HRV), measured as the RMSSD you type each morning. We take the natural log of RMSSD (lnRMSSD) and compare it to your ~60-day average as a z-score. The 0-100 score is 50 + 20 × z. High = recovered, you can push. Low = below your norm, go easy. At least 5 readings are needed."),
        "info.acwr.title" to ("Carico acuto:cronico (ACWR)" to "Acute:Chronic load (ACWR)"),
        "info.acwr.body" to (
            "Rapporto tra il carico recente (acuto, 7 giorni) e quello abituale (cronico, 28 giorni), con media mobile esponenziale (EWMA). Il carico viene dal TRIMP, quindi compare solo dopo durata + FC media della sessione (serve un orologio o una fascia cardio). Zona: 0,8-1,3 ottimale; sotto 0,8 detraining; sopra 1,3 picco e maggior rischio infortuni." to
            "Ratio of recent load (acute, 7 days) to habitual load (chronic, 28 days), via an exponentially weighted moving average (EWMA). Load comes from TRIMP, so it only appears after the session's duration + average HR (a watch or chest strap is needed). Zone: 0.8-1.3 sweet spot; below 0.8 detraining; above 1.3 a spike with higher injury risk."),
        "info.monotony.title" to ("Monotonia" to "Monotony"),
        "info.monotony.body" to (
            "Quanto è uniforme il carico nella settimana: media giornaliera divisa per la deviazione standard (Foster). Valori alti (sopra ~2) = allenamenti tutti simili, più affaticamento. Variare l'intensità abbassa la monotonia. Servono almeno 2 giorni di allenamento con RPE/FC." to
            "How even your load is across the week: mean daily load over its standard deviation (Foster). High (above ~2) = every session alike, more fatigue. Varying intensity lowers it. Needs at least 2 training days with RPE/HR."),
        "info.strain.title" to ("Strain" to "Strain"),
        "info.strain.body" to (
            "Carico totale della settimana × monotonia (Foster). Riassume lo stress complessivo: alto quando alleni molto e in modo monotono. I picchi precedono spesso sovraccarico o cali di forma: buon segnale per una settimana di scarico." to
            "Week's total load × monotony (Foster). Sums up overall stress: high when you train a lot and monotonously. Spikes often precede overreaching or dips: a good cue for a deload week."),
        "info.load.title" to ("Carico interno" to "Internal load"),
        "info.load.body" to (
            "Misura lo stress dell'allenamento percepito dal corpo, non i kg sollevati. Lo calcoliamo come TRIMP dalla durata e dalla FC media della sessione. Da qui derivano ACWR, monotonia e strain. Senza durata + FC media una sessione non genera carico interno, quindi queste metriche restano vuote (serve un orologio o una fascia cardio). Se hai visto un carico altissimo senza FC, veniva da una vecchia sessione con la valutazione manuale dello sforzo: ora il carico interno si basa solo sulla frequenza cardiaca, quindi non può più gonfiarsi senza di essa." to
            "Measures the training stress your body experiences, not the kilos lifted. We compute it as TRIMP from the session's duration and average heart rate. ACWR, monotony and strain build on it. Without duration + average HR a session produces no internal load, so these stay empty (a watch or chest strap is needed). If you ever saw a very high load with no HR, that came from an old session's manual effort rating: internal load is now based on heart rate alone, so it can no longer be inflated without it."),
        "info.activity.title" to ("Livello di attività" to "Activity level"),
        "info.activity.body" to (
            "Il livello di attività moltiplica il metabolismo basale (BMR) per stimare le calorie bruciate ogni giorno (TDEE). Più ti muovi e ti alleni, più alto è il moltiplicatore.\n\nSedentario (×1.2): lavoro d'ufficio, nessun allenamento.\nLeggero (×1.375): 1-2 allenamenti a settimana.\nModerato (×1.55): 3-4 allenamenti a settimana.\nAlto (×1.725): 5-6 allenamenti a settimana.\nAtleta (×1.9): 6-7 allenamenti a settimana più lavoro fisico o doppie sedute.\n\nScegli in base ai giorni reali di allenamento: è la base per calorie e macro." to
            "Your activity level multiplies your basal metabolism (BMR) to estimate how many calories you burn each day (TDEE). The more you move and train, the higher the multiplier.\n\nSedentary (×1.2): desk job, no training.\nLight (×1.375): 1-2 workouts per week.\nModerate (×1.55): 3-4 workouts per week.\nHigh (×1.725): 5-6 workouts per week.\nAthlete (×1.9): 6-7 workouts per week plus a physical job or twice-daily sessions.\n\nPick it from your real training days: it's the basis for your calories and macros."),
        "info.srpe.title" to ("sRPE (durata × RPE)" to "sRPE (duration × RPE)"),
        "info.srpe.body" to (
            "Session-RPE: durata in minuti × sforzo percepito (RPE 1-10, Borg CR10). È il modo più semplice e validato per quantificare il carico interno di qualsiasi allenamento. Inserisci durata e RPE a fine sessione." to
            "Session-RPE: minutes × perceived effort (RPE 1-10, Borg CR10). The simplest validated way to quantify internal load of any session. Enter duration and RPE at the end."),
        "info.bmi.title" to ("BMI" to "BMI"),
        "info.bmi.body" to (
            "Indice di massa corporea: peso (kg) / altezza (m) al quadrato. OMS: <18,5 sottopeso, 18,5-25 normopeso, 25-30 sovrappeso, >30 obeso. Non distingue muscolo da grasso: per i muscolosi può risultare alto. Per la composizione usa il grasso corporeo." to
            "Body Mass Index: weight (kg) / height (m) squared. WHO: <18.5 underweight, 18.5-25 normal, 25-30 overweight, >30 obese. It can't tell muscle from fat, so muscular people read high. Use body fat for composition."),
        "info.bodyfat.title" to ("Grasso corporeo" to "Body fat"),
        "info.bodyfat.body" to (
            "Percentuale di massa grassa sul peso. Inseriscila manualmente o usa la stima Navy da collo, vita e altezza. La Navy è comoda ma indicativa (±3-4%): misura sempre allo stesso modo e segui il trend." to
            "Share of fat mass over weight. Enter it manually or use the Navy estimate from neck, waist and height. Navy is handy but approximate (±3-4%): measure the same way and follow the trend."),
        "info.tdee.title" to ("TDEE & BMR" to "TDEE & BMR"),
        "info.tdee.body" to (
            "Il BMR (metabolismo basale) è l'energia a riposo (Mifflin-St Jeor da peso, altezza, età, sesso). Il TDEE è il dispendio totale: BMR × moltiplicatore di attività (1,2 sedentario → 1,9 atleta). È la base per le calorie obiettivo." to
            "BMR (basal metabolic rate) is rest energy (Mifflin-St Jeor from weight, height, age, sex). TDEE is total expenditure: BMR × activity multiplier (1.2 sedentary → 1.9 athlete). It's the basis for calorie targets."),
        "info.macros.title" to ("Macronutrienti" to "Macronutrients"),
        "info.macros.body" to (
            "Ripartizione di proteine, carboidrati e grassi sulle calorie obiettivo (range ISSN). Proteine ~1,8-2,2 g/kg (più alte in definizione). Grassi ~0,8 g/kg come minimo ormonale. I carboidrati riempiono il resto e alimentano la prestazione." to
            "How protein, carbs and fat split the calorie target (ISSN ranges). Protein ~1.8-2.2 g/kg (higher on a cut). Fat ~0.8 g/kg as a hormonal floor. Carbs fill the rest and fuel performance."),
        "info.carbcycle.title" to ("Ciclizzazione dei carboidrati" to "Carb cycling"),
        "info.carbcycle.body" to (
            "Sposta i carboidrati verso i giorni di allenamento mantenendo la media: più nei giorni ON (×1,30), meno nei giorni OFF (×0,65). Utile in definizione per allenarsi con energia restando in deficit. Le proteine restano costanti." to
            "Shuttles carbs toward training days while keeping the average: more on ON days (×1.30), fewer on OFF days (×0.65). Useful on a cut to train with energy while in a deficit. Protein stays constant."),
        "info.lea.title" to ("Disponibilità energetica (EA)" to "Energy availability (EA)"),
        "info.lea.body" to (
            "Energia per le funzioni vitali dopo l'allenamento: (calorie assunte − energia dell'esercizio) ÷ massa magra, sugli ultimi 7 giorni. Sotto 30 kcal/kg di massa magra c'è rischio LEA/RED-S: cali ormonali, ossei, di prestazione. 30-45 è cautela sotto carico." to
            "Energy for vital functions after training: (calories eaten − exercise energy) ÷ fat-free mass, over 7 days. Below 30 kcal/kg lean mass risks LEA/RED-S: hormonal, bone and performance decline. 30-45 is a caution zone under load."),
        "info.trend.title" to ("Trend del peso" to "Weight trend"),
        "info.trend.body" to (
            "Stima la reale variazione di peso (kg/sett) con una regressione lineare sugli ultimi ~21 pesi, togliendo il rumore quotidiano. Confronta il ritmo reale con l'obiettivo e suggerisce un aggiustamento calorico. Servono almeno 4 pesate." to
            "Estimates your real weight change (kg/wk) with a linear regression over your last ~21 weigh-ins, removing daily noise. Compares the real rate to your target and suggests a calorie adjustment. Needs at least 4 weigh-ins."),
        "info.overload.title" to ("Sovraccarico progressivo" to "Progressive overload"),
        "info.overload.body" to (
            "Suggerimenti di doppia progressione per il prossimo allenamento, confrontando l'ultima sessione col range di ripetizioni. Massimo del range su tutte le serie → aumenta il carico. Dentro al range → cerca più ripetizioni. Sotto → mantieni e cura la tecnica." to
            "Double-progression hints for your next workout, comparing your last session to the rep range. Top of range on all sets → add load. Inside the range → chase more reps. Below → hold and refine technique."),
        "info.calories.title" to ("Calorie bruciate" to "Calories burned"),
        "info.calories.body" to (
            "Stima dell'energia spesa dai tuoi dati (peso, età, sesso). L'app usa sempre la formula più precisa che i dati permettono.\n\nCon FC media usiamo l'equazione di Keytel (più precisa). Per il cardio senza FC usiamo un MET specifico per sport — bici, corsa, camminata e nuoto hanno ciascuno la propria formula, affinata dalla velocità reale quando inserisci la distanza. Per la forza un MET da allenamento di resistenza sulla durata, oppure una stima da volume. Puoi sempre inserire il tuo numero per sovrascrivere la stima." to
            "Estimate of energy spent from your profile (weight, age, sex). The app always uses the most precise formula your data allows.\n\nWith avg HR we use the Keytel equation (most precise). For cardio without HR we use a sport-specific MET — cycling, running, walking and swimming each have their own formula, refined by your real speed when a distance is logged. For strength a resistance-training MET over the duration, or a volume estimate. You can always type your own number to override the estimate."),
        "info.pace.title" to ("Ritmo & velocità" to "Pace & speed"),
        "info.pace.body" to (
            "Il ritmo viene calcolato automaticamente da distanza e durata, nell'unità tipica di ogni sport: la bici usa la velocità in km/h, la corsa e la camminata il passo in min/km, il nuoto il passo in min/100m.\n\nInserisci distanza e durata e il valore compare da solo. Se vuoi, puoi scriverlo a mano per sovrascrivere il calcolo automatico: la tua cifra ha sempre la precedenza." to
            "Pace is computed automatically from distance and duration, in each sport's usual unit: cycling uses speed in km/h, running and walking use min/km pace, swimming uses min/100m.\n\nEnter distance and duration and the value fills in by itself. If you prefer, type it by hand to override the automatic calculation: your number always wins."),
        "info.trimp.title" to ("TRIMP" to "TRIMP"),
        "info.trimp.body" to (
            "Training Impulse (Banister): pesa la durata con la frequenza cardiaca di riserva e un fattore esponenziale diverso per uomo e donna. Richiede FC media e durata, oltre a FC a riposo e massima del profilo. Più preciso dell'sRPE per il cardio." to
            "Training Impulse (Banister): weights duration by heart-rate reserve and a sex-specific exponential factor. Needs avg HR and duration, plus your resting and max HR. More precise than sRPE for cardio."),
        "info.rmssd.title" to ("RMSSD (HRV)" to "RMSSD (HRV)"),
        "info.rmssd.body" to (
            "L'RMSSD è la principale misura di variabilità della frequenza cardiaca (HRV): la radice della media dei quadrati delle differenze tra battiti consecutivi (intervalli R-R), in millisecondi. Riflette il recupero del sistema nervoso parasimpatico. Misuralo al mattino, da sdraiato, sempre allo stesso modo, con un'app HRV o una fascia cardio, e inseriscilo qui. L'app lo trasforma nel punteggio di Prontezza." to
            "RMSSD is the main heart-rate variability (HRV) metric: the root mean square of successive differences between consecutive heartbeats (R-R intervals), in milliseconds. It reflects parasympathetic (recovery) activity. Measure it in the morning, lying down, the same way each time, with an HRV app or chest strap, and enter it here. The app turns it into your Readiness score."),
        "info.dfa.title" to ("DFA-alpha1 (soglia aerobica)" to "DFA-alpha1 (aerobic threshold)"),
        "info.dfa.body" to (
            "La DFA-alpha1 è un indice dall'analisi frattale degli intervalli R-R durante la corsa. Quando scende verso 0,75 segnala la prima soglia aerobica, stimabile senza test di laboratorio. Richiede un flusso continuo e accurato di intervalli R-R battito-battito da una fascia cardiaca Bluetooth, quindi arriverà con il supporto Bluetooth. La FC da polso non è abbastanza precisa." to
            "DFA-alpha1 is an index from fractal analysis of R-R intervals during running. When it drops toward 0.75 it marks the first aerobic threshold, estimable without a lab test. It needs a continuous, accurate beat-to-beat R-R stream from a Bluetooth chest strap, so it's coming with Bluetooth support. Wrist HR is not precise enough."),
        "info.weekplan.title" to ("Piano settimanale" to "Weekly plan"),
        "info.weekplan.body" to (
            "Decide quale sarà il prossimo allenamento. Senza piano, l'app ruota tra i giorni nell'ordine della pagina Allena (dopo Push viene Pull, ecc., poi ricomincia). Col piano settimanale assegni a ogni giorno un allenamento, un'attività cardio o riposo: il prossimo seguirà l'ordine che preferisci (es. Lunedì Push, Martedì Corsa, Giovedì Pull…). Lascia vuoto per la rotazione automatica." to
            "Decides your next workout. Without a plan, the app rotates through your days in the Train-page order (after Push comes Pull, etc., then loops). With the weekly plan you assign each weekday a workout, a cardio activity or rest: the next one follows the order you prefer (e.g. Monday Push, Tuesday Running, Thursday Pull…). Leave empty for automatic rotation."),
        "info.adherence.title" to ("Costanza & TDEE adattivo" to "Adherence & adaptive TDEE"),
        "info.adherence.body" to (
            "Le calorie obiettivo non si basano solo sul peso. Con abbastanza giorni di dieta e peso tracciati, l'app calcola il mantenimento reale (TDEE adattivo) = calorie medie assunte − energia implicata dal trend di peso. Così impara la tua spesa vera. Considera anche costanza, passi medi e volume di allenamento delle ultime 2-3 settimane." to
            "Your calorie target isn't based on weight alone. With enough days of logged nutrition and weight, the app computes your real maintenance (adaptive TDEE) = average intake − the energy implied by your weight trend. So it learns your true expenditure. It also considers logging consistency, average steps and training volume over the last 2-3 weeks."),
        "info.steps.title" to ("Passi" to "Steps"),
        "info.steps.body" to (
            "I passi giornalieri misurano l'attività non sportiva (NEAT), che incide molto sul dispendio totale. Inseriscili a mano. Servono a valutare la costanza di movimento e a rendere più precise le stime caloriche adattive." to
            "Daily steps measure non-exercise activity (NEAT), which heavily affects total expenditure. Enter them by hand. They help gauge how consistently you move and sharpen the adaptive calorie estimates."),
        "info.sleep.title" to ("Punteggio sonno" to "Sleep score"),
        "info.sleep.body" to (
            "Un punteggio 0-100 di quanto bene hai dormito (durata e qualità percepita). Il sonno è tra i fattori più importanti per recupero, prestazione e composizione corporea. Inseriscilo ogni mattina col peso." to
            "A 0-100 score of how well you slept (duration and perceived quality). Sleep is one of the biggest drivers of recovery, performance and body composition. Log it each morning with your weight."),
        "info.goal.title" to ("Obiettivo & progressi" to "Goal & progress"),
        "info.goal.body" to (
            "Il tuo obiettivo (peso e grasso) è fissato al primo accesso e NON cambia a ogni check-in: resta stabile finché non lo modifichi col pulsante Cambia obiettivo. La barra parte dal peso iniziale e arriva all'obiettivo. Il numero a sinistra è il peso attuale, che cambia a ogni pesata: è normale, l'obiettivo a destra resta fisso." to
            "Your goal (weight and body fat) is set at first launch and does NOT change at every check-in: it stays fixed until you change it with the Change goal button. The bar runs from start weight to goal. The left number is your current weight, which changes with each weigh-in: that's normal, the goal on the right stays put."),
        "info.streak.title" to ("Striscia" to "Streak"),
        "info.streak.body" to (
            "I giorni consecutivi con un check-in o un allenamento. La striscia resta attiva per tutta la giornata di oggi: non si azzera solo perché non hai ancora fatto il check-in. Si interrompe solo quando passa un giorno intero senza check-in né allenamento." to
            "The consecutive days you've done a check-in or workout. The streak stays active all of today: it doesn't reset just because you haven't checked in yet. It only breaks once a full day passes with no check-in and no workout."),

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
            "Sum of session TRIMP from average HR. Higher = more cardiovascular stress.")
    )
}

/** Free helper mirroring the iOS `t("key")`. */
fun t(key: String): String = L.t(key)
