CREATE SEQUENCE "public"."sync_rev" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1;--> statement-breakpoint
CREATE TABLE "audit_log" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "audit_log_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"actor_id" uuid,
	"client_id" uuid,
	"action" text NOT NULL,
	"resource" text NOT NULL,
	"resource_id" text,
	"ip_address" text,
	"at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "audit_log_action_check" CHECK ("audit_log"."action" in ('read', 'write'))
);
--> statement-breakpoint
CREATE TABLE "care_assignment" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"client_id" uuid NOT NULL,
	"staff_id" uuid NOT NULL,
	"role" text NOT NULL,
	"scopes" text[] NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"activated_at" timestamp with time zone,
	"ended_at" timestamp with time zone,
	"ended_by" uuid,
	CONSTRAINT "care_assignment_role_check" CHECK ("care_assignment"."role" in ('pt', 'nutrition', 'physio')),
	CONSTRAINT "care_assignment_status_check" CHECK ("care_assignment"."status" in ('pending', 'active', 'ended')),
	CONSTRAINT "care_assignment_scopes_check" CHECK (cardinality("care_assignment"."scopes") > 0 and "care_assignment"."scopes" <@ array['training', 'nutrition', 'body', 'sleep', 'vitals', 'notes']::text[]),
	CONSTRAINT "care_assignment_not_self_check" CHECK ("care_assignment"."client_id" <> "care_assignment"."staff_id")
);
--> statement-breakpoint
CREATE TABLE "consent" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"purpose" text NOT NULL,
	"ref_id" uuid,
	"granted" boolean NOT NULL,
	"policy_version" text NOT NULL,
	"ip_address" text,
	"user_agent" text,
	"created_at" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
	CONSTRAINT "consent_purpose_check" CHECK ("consent"."purpose" in ('health_processing', 'staff_sharing', 'aggregate_insights', 'research', 'marketing'))
);
--> statement-breakpoint
CREATE TABLE "invitation" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" text NOT NULL,
	"kind" text NOT NULL,
	"disciplines" text[],
	"assignment_role" text,
	"scopes" text[],
	"invited_by" uuid NOT NULL,
	"token_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"accepted_at" timestamp with time zone,
	"accepted_by" uuid,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "invitation_token_hash_unique" UNIQUE("token_hash"),
	CONSTRAINT "invitation_kind_check" CHECK ("invitation"."kind" in ('staff', 'admin', 'client')),
	CONSTRAINT "invitation_email_lower_check" CHECK ("invitation"."email" = lower("invitation"."email")),
	CONSTRAINT "invitation_assignment_role_check" CHECK ("invitation"."assignment_role" is null or "invitation"."assignment_role" in ('pt', 'nutrition', 'physio')),
	CONSTRAINT "invitation_scopes_check" CHECK ("invitation"."scopes" is null or "invitation"."scopes" <@ array['training', 'nutrition', 'body', 'sleep', 'vitals', 'notes']::text[])
);
--> statement-breakpoint
CREATE TABLE "body_measurement" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"rev" bigint DEFAULT nextval('sync_rev') NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"measured_on" date NOT NULL,
	"kind" text NOT NULL,
	"value" double precision NOT NULL,
	"source" text DEFAULT 'manual' NOT NULL,
	CONSTRAINT "body_measurement_kind_check" CHECK ("body_measurement"."kind" in ('weight', 'body_fat', 'waist', 'chest', 'arms', 'legs', 'neck', 'hips')),
	CONSTRAINT "body_measurement_source_check" CHECK ("body_measurement"."source" in ('manual', 'health_connect', 'ios_import')),
	CONSTRAINT "body_measurement_value_check" CHECK ("body_measurement"."value" > 0 and "body_measurement"."value" < 1000)
);
--> statement-breakpoint
CREATE TABLE "client_profile" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"sex" text,
	"birth_date" date,
	"height_cm" double precision,
	"timezone" text DEFAULT 'Europe/Rome' NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "client_profile_sex_check" CHECK ("client_profile"."sex" is null or "client_profile"."sex" in ('m', 'f')),
	CONSTRAINT "client_profile_height_check" CHECK ("client_profile"."height_cm" is null or "client_profile"."height_cm" between 100 and 250)
);
--> statement-breakpoint
CREATE TABLE "staff_profile" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"disciplines" text[] NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "staff_profile_disciplines_check" CHECK (cardinality("staff_profile"."disciplines") > 0 and "staff_profile"."disciplines" <@ array['pt', 'nutrition', 'physio']::text[])
);
--> statement-breakpoint
CREATE TABLE "exercise" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"slug" text NOT NULL,
	"name_it" text NOT NULL,
	"name_en" text NOT NULL,
	"category" text NOT NULL,
	"kind" text DEFAULT 'reps' NOT NULL,
	"is_bodyweight" boolean DEFAULT false NOT NULL,
	"media_url" text,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"archived_at" timestamp with time zone,
	CONSTRAINT "exercise_slug_unique" UNIQUE("slug"),
	CONSTRAINT "exercise_category_check" CHECK ("exercise"."category" in ('chest', 'back', 'legs', 'shoulders', 'arms', 'core', 'fullbody', 'cardio', 'other')),
	CONSTRAINT "exercise_kind_check" CHECK ("exercise"."kind" in ('reps', 'timed', 'interval'))
);
--> statement-breakpoint
CREATE TABLE "exercise_alias" (
	"alias_norm" text PRIMARY KEY NOT NULL,
	"exercise_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "user" DROP CONSTRAINT "user_role_check";--> statement-breakpoint
ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_actor_id_user_id_fk" FOREIGN KEY ("actor_id") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_client_id_user_id_fk" FOREIGN KEY ("client_id") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_assignment" ADD CONSTRAINT "care_assignment_client_id_user_id_fk" FOREIGN KEY ("client_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_assignment" ADD CONSTRAINT "care_assignment_staff_id_user_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_assignment" ADD CONSTRAINT "care_assignment_created_by_user_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_assignment" ADD CONSTRAINT "care_assignment_ended_by_user_id_fk" FOREIGN KEY ("ended_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "consent" ADD CONSTRAINT "consent_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invitation" ADD CONSTRAINT "invitation_invited_by_user_id_fk" FOREIGN KEY ("invited_by") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invitation" ADD CONSTRAINT "invitation_accepted_by_user_id_fk" FOREIGN KEY ("accepted_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "body_measurement" ADD CONSTRAINT "body_measurement_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "client_profile" ADD CONSTRAINT "client_profile_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_profile" ADD CONSTRAINT "staff_profile_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise" ADD CONSTRAINT "exercise_created_by_user_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_alias" ADD CONSTRAINT "exercise_alias_exercise_id_exercise_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercise"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audit_log_client_idx" ON "audit_log" USING btree ("client_id","at");--> statement-breakpoint
CREATE INDEX "audit_log_actor_idx" ON "audit_log" USING btree ("actor_id","at");--> statement-breakpoint
CREATE UNIQUE INDEX "care_assignment_open_unique" ON "care_assignment" USING btree ("client_id","staff_id","role") WHERE "care_assignment"."status" <> 'ended';--> statement-breakpoint
CREATE INDEX "care_assignment_staff_idx" ON "care_assignment" USING btree ("staff_id") WHERE "care_assignment"."status" = 'active';--> statement-breakpoint
CREATE INDEX "care_assignment_client_idx" ON "care_assignment" USING btree ("client_id");--> statement-breakpoint
CREATE INDEX "consent_user_purpose_idx" ON "consent" USING btree ("user_id","purpose","created_at");--> statement-breakpoint
CREATE INDEX "invitation_email_idx" ON "invitation" USING btree ("email");--> statement-breakpoint
CREATE INDEX "body_measurement_user_rev_idx" ON "body_measurement" USING btree ("user_id","rev");--> statement-breakpoint
CREATE INDEX "body_measurement_user_day_idx" ON "body_measurement" USING btree ("user_id","measured_on");--> statement-breakpoint
CREATE INDEX "exercise_alias_trgm_idx" ON "exercise_alias" USING gin ("alias_norm" gin_trgm_ops);--> statement-breakpoint
CREATE INDEX "exercise_alias_exercise_idx" ON "exercise_alias" USING btree ("exercise_id");--> statement-breakpoint
ALTER TABLE "user" ADD CONSTRAINT "user_role_check" CHECK ("user"."role" in ('client', 'staff', 'admin'));