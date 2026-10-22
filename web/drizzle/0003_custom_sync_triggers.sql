-- One trigger per synced table (see bump_sync_rev in 0001).
CREATE TRIGGER body_measurement_sync_rev
  BEFORE INSERT OR UPDATE ON body_measurement
  FOR EACH ROW EXECUTE FUNCTION bump_sync_rev();
