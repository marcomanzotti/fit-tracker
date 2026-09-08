package com.fittracker.android.localization

/**
 * Kotlin port of Localization.swift's key/value lookup table. Not every one of
 * the ~900 Swift keys is ported yet — only the ones the current Android
 * screens (and the data/science layer's `L.t(...)` calls, e.g. bmi/bf/ffmi/mg
 * category labels) reference, plus core UI chrome. `t()` is crash-safe: an
 * unknown key falls back to returning the key itself rather than throwing, so
 * a missing translation never crashes the UI — it just shows the raw key,
 * which is easy to spot and backfill later.
 */
object L {
    var lang: String = "it"

    private val table: Map<String, Pair<String, String>> = mapOf(
        // Generic chrome
        "save" to ("Salva" to "Save"),
        "cancel" to ("Annulla" to "Cancel"),
        "delete" to ("Elimina" to "Delete"),
        "add" to ("Aggiungi" to "Add"),
        "edit" to ("Modifica" to "Edit"),
        "close" to ("Chiudi" to "Close"),
        "optional" to ("opzionale" to "optional"),
        "none" to ("Nessuno" to "None"),
        "kg" to ("kg" to "kg"),
        "confirm_delete" to ("Confermi l'eliminazione?" to "Confirm deletion?"),
        "today" to ("Oggi" to "Today"),
        "yesterday" to ("Ieri" to "Yesterday"),
        "search" to ("Cerca" to "Search"),
        "back" to ("Indietro" to "Back"),
        "done" to ("Fatto" to "Done"),
        "start" to ("Inizia" to "Start"),

        // Nav
        "nav.home" to ("Home" to "Home"),
        "nav.train" to ("Allena" to "Train"),
        "nav.body" to ("Corpo" to "Body"),
        "nav.nutrition" to ("Nutrizione" to "Nutrition"),
        "nav.stats" to ("Stats" to "Stats"),

        // Home
        "home.checkin" to ("Check-in di oggi" to "Today's check-in"),
        "home.weight" to ("Peso" to "Weight"),
        "home.sleep" to ("Sonno" to "Sleep"),
        "home.save_checkin" to ("Salva check-in" to "Save check-in"),
        "home.streak" to ("Streak" to "Streak"),
        "home.days" to ("giorni" to "days"),
        "home.next_workout" to ("Prossimo allenamento" to "Next workout"),
        "home.week_activity" to ("Attività settimana" to "This week"),
        "home.backup" to ("Backup dati" to "Data backup"),
        "home.export" to ("Esporta JSON" to "Export JSON"),
        "home.import" to ("Importa JSON" to "Import JSON"),
        "home.day" to ("giorno" to "day"),
        "home.sessions" to ("Sessioni" to "Sessions"),
        "home.total" to ("totali" to "total"),
        "home.goals" to ("Obiettivi" to "Goals"),
        "home.fat" to ("Grasso" to "Body fat"),
        "home.backup_auto" to ("Salvataggio automatico locale" to "Automatic local save"),
        "home.export_data" to ("Esporta dati" to "Export data"),
        "home.checkin_done" to ("Check-in completato" to "Check-in done"),
        "home.checkin_saved" to ("Check-in salvato" to "Check-in saved"),
        "home.tap_to_log" to ("Tocca un giorno per registrare" to "Tap a day to log"),

        // Body
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
        "body.hips" to ("Fianchi" to "Hips"),
        "body.imported" to ("Dati importati" to "Data imported"),
        "body.invalid_file" to ("File non valido" to "Invalid file"),
        "body.import_cancelled" to ("Importazione annullata" to "Import cancelled"),
        "body.sleep" to ("Sonno" to "Sleep"),
        "body.sleep_hr" to ("FC nel sonno" to "Sleeping HR"),
        "body.sleep_manual" to ("Inserimento manuale" to "Manual entry"),
        "body.sleep_hours" to ("Ore di sonno" to "Sleep hours"),
        "body.today" to ("Oggi" to "Today"),
        "body.past_day" to ("Giorno passato" to "Past day"),
        "body.ffmi" to ("FFMI" to "FFMI"),
        "body.ffmi_norm" to ("FFMI norm." to "FFMI norm."),
        "body.ffmi_need_bf" to ("Serve la % di grasso" to "Needs body fat %"),
        "body.navy_need_hips" to ("Aggiungi la misura dei fianchi per stimare il grasso (formula femminile Navy)." to "Add your hip measurement to estimate body fat (Navy female formula)."),
        "body.steps" to ("Passi" to "Steps"),

        // Meals
        "meal.breakfast" to ("Colazione" to "Breakfast"),
        "meal.lunch" to ("Pranzo" to "Lunch"),
        "meal.dinner" to ("Cena" to "Dinner"),
        "meal.snacks" to ("Spuntini" to "Snacks"),

        // Workout (wk.*)
        "wk.live" to ("Allenamento live" to "Live workout"),
        "wk.add_ex" to ("Aggiungi esercizio" to "Add exercise"),
        "wk.set" to ("Serie" to "Set"),
        "wk.reps" to ("Rip" to "Reps"),
        "wk.duration" to ("Durata" to "Duration"),
        "wk.avg_hr" to ("FC media" to "Avg HR"),
        "wk.superset" to ("Superset" to "Superset"),
        "wk.method" to ("Metodo" to "Method"),
        "wk.distance" to ("Distanza" to "Distance"),
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
        "wk.edit_day" to ("Modifica giorno" to "Edit day"),
        "wk.day" to ("Giorno" to "Day"),
        "wk.create_day" to ("Crea giorno" to "Create day"),
        "wk.recent" to ("Sessioni recenti" to "Recent sessions"),
        "wk.sets_n" to ("serie" to "sets"),
        "wk.exercises_n" to ("esercizi" to "exercises"),
        "wk.day_created" to ("Giorno creato" to "Day created"),
        "wk.day_updated" to ("Giorno aggiornato" to "Day updated"),
        "wk.day_deleted" to ("Giorno eliminato" to "Day deleted"),
        "wk.saved" to ("Salvata" to "Saved"),
        "wk.finish_session" to ("Termina sessione" to "Finish session"),
        "wk.finish" to ("Termina" to "Finish"),
        "wk.pause" to ("Pausa" to "Pause"),
        "wk.resume" to ("Riprendi" to "Resume"),
        "wk.paused" to ("In pausa" to "Paused"),
        "wk.discard_session" to ("Elimina allenamento" to "Discard workout"),
        "wk.discard_q" to ("Eliminare questo allenamento? L'operazione non può essere annullata." to "Discard this workout? This can't be undone."),
        "wk.discarded" to ("Allenamento eliminato" to "Workout discarded"),
        "wk.minimize" to ("Riduci" to "Minimize"),
        "wk.try" to ("Prova" to "Try"),
        "wk.add_set" to ("+ Serie" to "+ Set"),
        "wk.timer" to ("Timer" to "Timer"),
        "wk.vol" to ("Vol" to "Vol"),
        "wk.max" to ("Max" to "Max"),
        "wk.round" to ("Round" to "Round"),
        "wk.rounds_done" to ("Round fatti" to "Rounds done"),
        "wk.add_note" to ("+ Note" to "+ Note"),
        "wk.note_ph" to ("Note…" to "Notes…"),
        "wk.add_ex_ph" to ("es. Dip alle parallele" to "e.g. Parallel bar dips"),
        "wk.ex_added" to ("Esercizio aggiunto" to "Exercise added"),
        "wk.nothing_save" to ("Nessuna serie da salvare" to "No sets to save"),
        "wk.session_saved" to ("Sessione salvata" to "Session saved"),
        "wk.cardio" to ("Cardio" to "Cardio"),
        "wk.cardio_types" to ("Attività cardio" to "Cardio activities"),
        "wk.new_cardio" to ("Nuova attività" to "New activity"),
        "wk.edit_cardio" to ("Modifica attività" to "Edit activity"),
        "wk.cardio_kind" to ("Tipo di sport" to "Sport kind"),
        "wk.activity_name" to ("Nome attività" to "Activity name"),
        "wk.activity_sub" to ("Sottotitolo" to "Subtitle"),
        "wk.cardio_saved" to ("Attività salvata" to "Activity saved"),
        "wk.cardio_deleted" to ("Attività eliminata" to "Activity deleted"),
        "wk.delete_cardio_q" to ("Eliminare questa attività?" to "Delete this activity?"),
        "wk.log_cardio" to ("Registra cardio" to "Log cardio"),

        // Exercise kind
        "exkind.reps" to ("Ripetizioni" to "Reps"),
        "exkind.timed" to ("A tempo" to "Timed"),
        "exkind.interval" to ("Intervalli" to "Interval"),

        // Muscle group
        "mg.title" to ("Gruppo muscolare" to "Muscle group"),
        "mg.chest" to ("Petto" to "Chest"),
        "mg.back" to ("Schiena" to "Back"),
        "mg.legs" to ("Gambe" to "Legs"),
        "mg.shoulders" to ("Spalle" to "Shoulders"),
        "mg.arms" to ("Braccia" to "Arms"),
        "mg.core" to ("Core" to "Core"),
        "mg.fullbody" to ("Tutto il corpo" to "Full body"),
        "mg.cardio" to ("Cardio" to "Cardio"),
        "mg.other" to ("Altro" to "Other"),

        // BMI / body fat categories
        "bmi.under" to ("Sottopeso" to "Underweight"),
        "bmi.normal" to ("Normopeso" to "Normal"),
        "bmi.over" to ("Sovrappeso" to "Overweight"),
        "bmi.obese" to ("Obeso" to "Obese"),
        "bf.essential" to ("Essenziale" to "Essential"),
        "bf.athlete" to ("Atleta" to "Athlete"),
        "bf.fitness" to ("Fitness" to "Fitness"),
        "bf.average" to ("Nella media" to "Average"),
        "bf.overweight" to ("Sovrappeso" to "Overweight"),
        "bf.obese" to ("Obeso" to "Obese"),
        "bf.muscular" to ("Muscoloso (BMI alto, grasso basso)" to "Muscular (high BMI, low fat)"),
        "bf.category" to ("Categoria grasso" to "Body-fat category"),

        // FFMI
        "ffmi.below" to ("Sotto la media" to "Below average"),
        "ffmi.average" to ("Nella media" to "Average"),
        "ffmi.good" to ("Buona" to "Good"),
        "ffmi.great" to ("Ottima" to "Great"),
        "ffmi.excellent" to ("Eccellente" to "Excellent"),
        "ffmi.elite" to ("Al limite naturale" to "At the natural limit"),

        // Sport
        "sport.strength" to ("Forza" to "Strength"),
        "sport.running" to ("Corsa" to "Running"),
        "sport.swimming" to ("Nuoto" to "Swimming"),
        "sport.cycling" to ("Bici" to "Cycling"),
        "sport.walking" to ("Camminata" to "Walking"),
        "sport.other" to ("Altro" to "Other"),

        // Exercise library
        "ex.library" to ("Libreria esercizi" to "Exercise library"),

        // Stats (st.*)
        "st.section_workout" to ("Allenamento" to "Workout"),
        "st.section_nutrition" to ("Nutrizione" to "Nutrition"),
        "st.overview" to ("Panoramica" to "Overview"),
        "st.records" to ("Record" to "Records"),
        "st.progress" to ("Progressi" to "Progress"),
        "st.history" to ("Storico" to "History"),
        "st.maxes" to ("I tuoi massimali" to "Your maxes"),
        "st.maxes_hint" to ("Crea un giorno con esercizi per tracciare i record." to "Create a day with exercises to track records."),
        "st.select_ex" to ("Seleziona esercizio" to "Select exercise"),
        "st.max_per_session" to ("Peso massimo per sessione" to "Max weight per session"),
        "st.vol_per_session" to ("Volume totale per sessione" to "Total volume per session"),
        "st.first" to ("Prima" to "First"),
        "st.last" to ("Ultima" to "Last"),
        "st.delta" to ("Delta" to "Delta"),
        "st.progress_hint" to ("Seleziona un esercizio per vedere la progressione." to "Select an exercise to see progression."),
        "st.no_data" to ("Nessun dato" to "No data"),
        "st.sleep" to ("Sleep score" to "Sleep score"),
        "st.bmi_time" to ("BMI" to "BMI"),
        "st.composition" to ("Composizione corporea" to "Body composition"),
        "st.lean" to ("Magra" to "Lean"),
        "st.fat" to ("Grasso" to "Fat"),
        "st.charts_hint" to ("Registra peso e sleep per 2+ giorni per vedere i grafici." to "Log weight and sleep for 2+ days to see charts."),
        "st.search_ex" to ("Cerca esercizio" to "Search exercise"),
        "st.all_exercises" to ("Tutti gli esercizi" to "All exercises"),
        "st.steps_time" to ("Passi" to "Steps"),
        "st.variants" to ("varianti" to "variants"),
        "st.edit_family" to ("Famiglia esercizio" to "Exercise family"),
        "st.family" to ("Famiglia (movimento base)" to "Family (base movement)"),
        "st.muscle" to ("Muscolo" to "Muscle"),
        "st.manage" to ("Gestisci" to "Manage"),
        "st.dupes" to ("Possibili duplicati" to "Possible duplicates"),
        "st.merge" to ("Unisci" to "Merge"),
        "st.merge_into" to ("Unisci negli altri" to "Merge the rest into it"),
        "st.merged" to ("Esercizi uniti" to "Exercises merged"),
        "st.rename" to ("Rinomina" to "Rename"),
        "st.renamed" to ("Esercizio rinominato" to "Exercise renamed"),
        "st.delete" to ("Cancella" to "Delete"),
        "st.delete_q" to ("Cancellare questo esercizio?" to "Delete this exercise?"),
        "st.deleted" to ("Esercizio cancellato" to "Exercise deleted"),
        "st.sessions_affected" to ("sessioni interessate" to "sessions affected"),
        "st.session_one" to ("sessione" to "session"),
        "st.sessions_n" to ("sessioni" to "sessions"),
        "st.vo2_time" to ("VO₂ max" to "VO₂ max"),
        "st.hrv_sdnn" to ("SDNN" to "SDNN"),
        "st.all_variants" to ("Tutte" to "All"),
        "st.ffmi_time" to ("FFMI nel tempo" to "FFMI over time"),
        "st.vol_low" to ("sotto" to "under"),
        "st.vol_ok" to ("in target" to "on target"),
        "st.vol_high" to ("sopra" to "over"),
        "st.pr_feed" to ("Record nel tempo" to "Records over time"),
        "st.pr_none" to ("Nessun record ancora. Registra qualche serie con il peso." to "No records yet. Log some sets with weight."),
        "st.pr_weight" to ("peso max" to "top weight"),
        "st.pr_e1rm" to ("e1RM" to "e1RM"),
        "st.pr_hold" to ("tenuta" to "hold"),
        "st.pr_first" to ("primo record" to "first record"),

        // Nutrition
        "nut.target" to ("Target" to "Target"),
        "nut.today" to ("Oggi" to "Today"),
        "nut.my_foods" to ("I miei alimenti" to "My foods"),
        "nut.log_edit_today" to ("Registra / modifica oggi" to "Log / Edit today"),
        "nut.new_food" to ("Nuovo alimento" to "New food"),
        "nut.recipes" to ("Ricette" to "Recipes"),
        "nut.protein" to ("Proteine" to "Protein"),
        "nut.carbs" to ("Carboidrati" to "Carbs"),
        "nut.fat" to ("Grassi" to "Fat"),
        "nut.day_total" to ("Totale" to "Total"),

        // Food picker / recipes
        "food.title" to ("Alimenti" to "Foods"),
        "food.add" to ("+ Aggiungi alimento" to "+ Add food"),
        "food.new" to ("Nuovo" to "New"),
        "food.scan" to ("Scansiona" to "Scan"),
        "food.search" to ("Cerca alimenti…" to "Search foods…"),
        "food.none" to ("Nessun alimento salvato" to "No saved foods"),
        "food.looking" to ("Ricerca…" to "Looking up…"),
        "food.sort" to ("Ordina" to "Sort"),
        "food.sort.recent" to ("Recenti" to "Recent"),
        "food.sort.alpha" to ("A-Z" to "A-Z"),
        "food.sort.kcal" to ("Kcal" to "Kcal"),
        "food.sort.ratio" to ("P/kcal" to "P/kcal"),
        "food.new_title" to ("Nuovo alimento" to "New food"),
        "food.name" to ("Nome" to "Name"),
        "food.brand" to ("Marca" to "Brand"),
        "food.per100_label" to ("Per 100" to "Per 100"),
        "food.liquid" to ("Liquido (ml)" to "Liquid (ml)"),
        "food.save_food" to ("Salva" to "Save"),
        "food.amount" to ("Quantità" to "Amount"),
        "recipe.title" to ("Ricette" to "Recipes"),
        "recipe.new" to ("Nuova ricetta" to "New recipe"),
        "recipe.edit" to ("Modifica ricetta" to "Edit recipe"),
        "recipe.none" to ("Nessuna ricetta salvata" to "No saved recipes"),
        "recipe.serving" to ("porzione" to "serving"),
        "recipe.name_placeholder" to ("Nome ricetta" to "Recipe name"),
        "recipe.input_mode" to ("Modalità" to "Input mode"),
        "recipe.manual" to ("Manuale" to "Manual"),
        "recipe.from_ingredients" to ("Da ingredienti" to "From ingredients"),
        "recipe.per_serving_toggle" to ("Per porzione" to "Per serving"),
        "recipe.per_serving_hint" to ("I valori sono per l'intera ricetta, divisi per porzioni" to "Values are for the whole recipe, split across servings"),
        "recipe.servings" to ("Porzioni" to "Servings"),
        "recipe.total_macros_label" to ("Macro totali" to "Total macros"),
        "recipe.ingredients" to ("Ingredienti" to "Ingredients"),
        "recipe.add_ingredient" to ("Aggiungi ingrediente" to "Add ingredient"),

        // Onboarding
        "onb.welcome" to ("Benvenuto in FitTracker" to "Welcome to FitTracker"),
        "onb.next" to ("Avanti" to "Next"),
        "onb.finish" to ("Inizia" to "Get started")
    )

    fun t(key: String): String {
        val entry = table[key] ?: return key
        return if (lang == "en") entry.second else entry.first
    }

    val months: List<String>
        get() = if (lang == "en")
            listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
        else
            listOf("Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic")

    val days: List<String>
        get() = if (lang == "en")
            listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        else
            listOf("Dom", "Lun", "Mar", "Mer", "Gio", "Ven", "Sab")

    val weekHeaders: List<String>
        get() = if (lang == "en")
            listOf("M", "T", "W", "T", "F", "S", "S")
        else
            listOf("L", "M", "M", "G", "V", "S", "D")
}
