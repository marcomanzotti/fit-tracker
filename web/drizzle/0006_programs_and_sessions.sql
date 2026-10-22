CREATE TABLE "program" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"client_id" uuid,
	"owner_id" uuid,
	"title" text NOT NULL,
	"goal" text,
	"start_date" date,
	"status" text DEFAULT 'draft' NOT NULL,
	"draft" jsonb NOT NULL,
	"draft_revision" integer DEFAULT 1 NOT NULL,
	"active_version_id" uuid,
	"source_template_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "program_status_check" CHECK ("program"."status" in ('draft', 'active', 'archived')),
	CONSTRAINT "program_title_check" CHECK (length("program"."title") between 1 and 120)
);
--> statement-breakpoint
CREATE TABLE "program_version" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"program_id" uuid NOT NULL,
	"version" integer NOT NULL,
	"content" jsonb NOT NULL,
	"change_note" text,
	"published_by" uuid,
	"published_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "program_version_unique" UNIQUE("program_id","version")
);
--> statement-breakpoint
CREATE TABLE "session_exercise" (
	"id" uuid PRIMARY KEY NOT NULL,
	"session_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"exercise_id" uuid,
	"name" text NOT NULL,
	"item_id" text,
	"target" text,
	"notes" text
);
--> statement-breakpoint
CREATE TABLE "set_log" (
	"id" uuid PRIMARY KEY NOT NULL,
	"session_exercise_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"type" text DEFAULT 'work' NOT NULL,
	"reps" integer,
	"load_kg" double precision,
	"seconds" integer,
	"rir" double precision,
	"rpe" double precision,
	"done" boolean DEFAULT true NOT NULL,
	CONSTRAINT "set_log_type_check" CHECK ("set_log"."type" in ('warmup', 'work', 'backoff', 'drop', 'amrap')),
	CONSTRAINT "set_log_reps_check" CHECK ("set_log"."reps" is null or "set_log"."reps" between 0 and 1000),
	CONSTRAINT "set_log_load_check" CHECK ("set_log"."load_kg" is null or "set_log"."load_kg" between 0 and 1000)
);
--> statement-breakpoint
CREATE TABLE "workout_session" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"rev" bigint DEFAULT nextval('sync_rev') NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"local_day" date NOT NULL,
	"started_at" timestamp with time zone,
	"ended_at" timestamp with time zone,
	"title" text NOT NULL,
	"program_version_id" uuid,
	"day_id" text,
	"week" integer,
	"duration_sec" integer,
	"rpe" integer,
	"notes" text,
	"source" text DEFAULT 'manual' NOT NULL,
	CONSTRAINT "workout_session_rpe_check" CHECK ("workout_session"."rpe" is null or "workout_session"."rpe" between 1 and 10),
	CONSTRAINT "workout_session_source_check" CHECK ("workout_session"."source" in ('manual', 'program', 'health_connect', 'ios_import'))
);
--> statement-breakpoint
ALTER TABLE "program" ADD CONSTRAINT "program_client_id_user_id_fk" FOREIGN KEY ("client_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "program" ADD CONSTRAINT "program_owner_id_user_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "program_version" ADD CONSTRAINT "program_version_program_id_program_id_fk" FOREIGN KEY ("program_id") REFERENCES "public"."program"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "program_version" ADD CONSTRAINT "program_version_published_by_user_id_fk" FOREIGN KEY ("published_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_exercise" ADD CONSTRAINT "session_exercise_session_id_workout_session_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."workout_session"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_exercise" ADD CONSTRAINT "session_exercise_exercise_id_exercise_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercise"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "set_log" ADD CONSTRAINT "set_log_session_exercise_id_session_exercise_id_fk" FOREIGN KEY ("session_exercise_id") REFERENCES "public"."session_exercise"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_session" ADD CONSTRAINT "workout_session_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_session" ADD CONSTRAINT "workout_session_program_version_id_program_version_id_fk" FOREIGN KEY ("program_version_id") REFERENCES "public"."program_version"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "program_client_idx" ON "program" USING btree ("client_id");--> statement-breakpoint
CREATE INDEX "program_owner_idx" ON "program" USING btree ("owner_id");--> statement-breakpoint
CREATE INDEX "session_exercise_session_idx" ON "session_exercise" USING btree ("session_id");--> statement-breakpoint
CREATE INDEX "session_exercise_exercise_idx" ON "session_exercise" USING btree ("exercise_id");--> statement-breakpoint
CREATE INDEX "set_log_exercise_idx" ON "set_log" USING btree ("session_exercise_id");--> statement-breakpoint
CREATE INDEX "workout_session_user_rev_idx" ON "workout_session" USING btree ("user_id","rev");--> statement-breakpoint
CREATE INDEX "workout_session_user_day_idx" ON "workout_session" USING btree ("user_id","local_day");--> statement-breakpoint
CREATE INDEX "workout_session_version_idx" ON "workout_session" USING btree ("program_version_id");