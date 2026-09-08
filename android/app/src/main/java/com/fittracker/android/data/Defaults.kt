package com.fittracker.android.data

object Defaults {
    fun defaultPlans(): List<WorkoutPlan> {
        return listOf(
            WorkoutPlan(
                id = "p1", name = "Push", sub = "Chest + Shoulders + Triceps", color = "ff5a52", exercises = listOf(
                    PlanExercise(name = "Barbell bench press", sets = 4, reps = "6-8"),
                    PlanExercise(name = "Incline dumbbell press", sets = 3, reps = "8-10"),
                    PlanExercise(name = "Seated dumbbell shoulder press", sets = 3, reps = "10"),
                    PlanExercise(name = "Cable lateral raise", sets = 3, reps = "12-15"),
                    PlanExercise(name = "Cable chest fly", sets = 3, reps = "12"),
                    PlanExercise(name = "Triceps rope pushdown", sets = 3, reps = "12")
                )
            ),
            WorkoutPlan(
                id = "p2", name = "Pull", sub = "Back + Biceps + Rear Delts", color = "4fb8c4", exercises = listOf(
                    PlanExercise(name = "Pull-up", sets = 4, reps = "6-10"),
                    PlanExercise(name = "Barbell row", sets = 3, reps = "8-10"),
                    PlanExercise(name = "Lat pulldown", sets = 3, reps = "10-12"),
                    PlanExercise(name = "Seated cable row", sets = 3, reps = "12"),
                    PlanExercise(name = "Face pull", sets = 3, reps = "15"),
                    PlanExercise(name = "EZ-bar biceps curl", sets = 3, reps = "10-12")
                )
            ),
            WorkoutPlan(
                id = "p3", name = "Legs", sub = "Quads + Hamstrings + Calves", color = "ffb000", exercises = listOf(
                    PlanExercise(name = "Barbell back squat", sets = 4, reps = "6-8"),
                    PlanExercise(name = "Romanian deadlift", sets = 3, reps = "8-10"),
                    PlanExercise(name = "Leg press", sets = 3, reps = "12"),
                    PlanExercise(name = "Seated leg curl", sets = 3, reps = "12"),
                    PlanExercise(name = "Leg extension", sets = 3, reps = "15"),
                    PlanExercise(name = "Standing calf raise", sets = 4, reps = "15")
                )
            )
        )
    }

    fun defaultCardioTypes(): List<CardioType> {
        return listOf(
            CardioType(id = "c-run", name = "Running", sport = "running", color = "ff5a52"),
            CardioType(id = "c-swim", name = "Swimming", sport = "swimming", color = "4fb8c4"),
            CardioType(id = "c-bike", name = "Cycling", sport = "cycling", color = "7fc950"),
            CardioType(id = "c-walk", name = "Walking", sport = "walking", color = "b08fff")
        )
    }
}

