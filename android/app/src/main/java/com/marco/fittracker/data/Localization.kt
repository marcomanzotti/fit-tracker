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
        "set.title" to ("Impostazioni" to "Settings"),

        "bmi.under" to ("Sottopeso" to "Underweight"),
        "bmi.normal" to ("Normopeso" to "Normal"),
        "bmi.over" to ("Sovrappeso" to "Overweight"),
        "bmi.obese" to ("Obeso" to "Obese"),

        "sport.strength" to ("Forza" to "Strength"),
        "sport.running" to ("Corsa" to "Running"),
        "sport.swimming" to ("Nuoto" to "Swimming"),
        "sport.cycling" to ("Bici" to "Cycling"),
        "sport.walking" to ("Camminata" to "Walking"),
        "sport.other" to ("Altro" to "Other")
    )
}

/** Free helper mirroring the iOS `t("key")`. */
fun t(key: String): String = L.t(key)
