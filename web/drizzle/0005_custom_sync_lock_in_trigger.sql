-- The per-user sync lock now lives in the trigger itself, so every writer of a
-- user's synced rows (sync push, staff edits, scripts, backfills) is serialized
-- and their revs commit in order: a pull cursor can never skip a row (ADR-0002).
-- Two-key advisory lock: the 'sync' namespace cannot collide with other locks.
-- The lock is re-entrant, so code that already took it (lockUser) is unaffected.
CREATE OR REPLACE FUNCTION bump_sync_rev() RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('sync'), hashtext(NEW.user_id::text));
  NEW.rev := nextval('public.sync_rev'::regclass);
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END
$$;
