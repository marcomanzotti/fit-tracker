ALTER TABLE "audit_log" DROP CONSTRAINT "audit_log_action_check";--> statement-breakpoint
DROP INDEX "care_assignment_staff_idx";--> statement-breakpoint
ALTER TABLE "invitation" ALTER COLUMN "email" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "audit_log" ADD COLUMN "actor_name" text;--> statement-breakpoint
ALTER TABLE "audit_log" ADD COLUMN "actor_email" text;--> statement-breakpoint
ALTER TABLE "consent" ADD COLUMN "seq" bigint NOT NULL GENERATED ALWAYS AS IDENTITY (sequence name "consent_seq_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1);--> statement-breakpoint
ALTER TABLE "consent" ADD COLUMN "scopes" text[];--> statement-breakpoint
CREATE INDEX "care_assignment_created_by_idx" ON "care_assignment" USING btree ("created_by");--> statement-breakpoint
CREATE INDEX "care_assignment_ended_by_idx" ON "care_assignment" USING btree ("ended_by");--> statement-breakpoint
CREATE INDEX "consent_current_idx" ON "consent" USING btree ("user_id","purpose","ref_id","seq");--> statement-breakpoint
CREATE INDEX "invitation_invited_by_idx" ON "invitation" USING btree ("invited_by");--> statement-breakpoint
CREATE INDEX "invitation_accepted_by_idx" ON "invitation" USING btree ("accepted_by");--> statement-breakpoint
CREATE INDEX "exercise_created_by_idx" ON "exercise" USING btree ("created_by");--> statement-breakpoint
CREATE INDEX "care_assignment_staff_idx" ON "care_assignment" USING btree ("staff_id");--> statement-breakpoint
ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_action_check" CHECK ("audit_log"."action" in ('read', 'write', 'denied'));