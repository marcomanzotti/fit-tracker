-- workout_session is synced: same rev/lock trigger as body_measurement (0003, 0005).
CREATE TRIGGER workout_session_sync_rev
  BEFORE INSERT OR UPDATE ON workout_session
  FOR EACH ROW EXECUTE FUNCTION bump_sync_rev();
