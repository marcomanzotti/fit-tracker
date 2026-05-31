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
        "wk.duration" to ("Durata (min)" to "Duration (min)"),
        "wk.avg_hr" to ("FC media" to "Avg HR"),
        "wk.rmssd" to ("RMSSD" to "RMSSD"),
        "wk.superset" to ("Superset" to "Superset"),
        "wk.method" to ("Metodo" to "Method"),
        "wk.sport" to ("Sport" to "Sport"),
        "wk.distance" to ("Distanza (km)" to "Distance (km)"),
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

        // --- Info popups (scientific metrics) ---
        "info.readiness.title" to ("Prontezza (HRV)" to "Readiness (HRV)"),
        "info.readiness.body" to (
            "Stima quanto sei recuperato dalla variabilità della frequenza cardiaca (HRV), misurata come RMSSD che inserisci al mattino. Usiamo il logaritmo naturale dell'RMSSD (lnRMSSD) e lo confrontiamo con la tua media degli ultimi ~60 giorni con uno z-score. Il punteggio 0-100 è 50 + 20 × z. Alto = recuperato, puoi spingere. Basso = sotto la norma, meglio andare leggeri. Servono almeno 5 misurazioni." to
            "Estimates how recovered you are from heart-rate variability (HRV), measured as the RMSSD you type each morning. We take the natural log of RMSSD (lnRMSSD) and compare it to your ~60-day average as a z-score. The 0-100 score is 50 + 20 × z. High = recovered, you can push. Low = below your norm, go easy. At least 5 readings are needed."),
        "info.acwr.title" to ("Carico acuto:cronico (ACWR)" to "Acute:Chronic load (ACWR)"),
        "info.acwr.body" to (
            "Rapporto tra il carico recente (acuto, 7 giorni) e quello abituale (cronico, 28 giorni), con media mobile esponenziale (EWMA). Il carico viene da sRPE o TRIMP, quindi compare solo dopo durata + RPE (o FC media). Zona: 0,8-1,3 ottimale; sotto 0,8 detraining; sopra 1,3 picco e maggior rischio infortuni." to
            "Ratio of recent load (acute, 7 days) to habitual load (chronic, 28 days), via an exponentially weighted moving average (EWMA). Load comes from sRPE or TRIMP, so it only appears after duration + RPE (or avg HR). Zone: 0.8-1.3 sweet spot; below 0.8 detraining; above 1.3 a spike with higher injury risk."),
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
            "Misura lo stress dell'allenamento percepito dal corpo, non i kg sollevati. È sRPE (durata × RPE) o, con FC media, TRIMP. Da qui derivano ACWR, monotonia e strain. Senza durata + RPE (o FC) una sessione non genera carico interno, quindi queste metriche restano vuote." to
            "Measures the training stress your body experiences, not the kilos lifted. It's sRPE (duration × RPE) or, with avg HR, TRIMP. ACWR, monotony and strain build on it. Without duration + RPE (or HR) a session produces no internal load, so these stay empty."),
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
            "Stima dell'energia spesa dai tuoi dati (peso, età, sesso). Con FC media usiamo la formula di Keytel; per il cardio senza FC i MET × peso × durata; per la forza una stima da volume e serie. È un'approssimazione, non una misura da metabolimetro." to
            "Estimate of energy spent from your profile (weight, age, sex). With avg HR we use the Keytel formula; for cardio without HR the activity METs × weight × duration; for strength a volume/sets estimate. It's an approximation, not a lab measurement.")
    )
}

/** Free helper mirroring the iOS `t("key")`. */
fun t(key: String): String = L.t(key)
