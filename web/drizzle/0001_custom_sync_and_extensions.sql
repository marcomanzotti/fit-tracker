-- Fuzzy exercise search (exercise_alias). pg_trgm is a trusted extension, so the
-- database owner can create it without superuser rights.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
--> statement-breakpoint
-- Sync bookkeeping (ADR-0002): every insert or update of a synced table gets the
-- next global rev and a server-side updated_at, so no code path can forget them.
CREATE OR REPLACE FUNCTION bump_sync_rev() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.rev := nextval('sync_rev');
  NEW.updated_at := now();
  RETURN NEW;
END
$$;
