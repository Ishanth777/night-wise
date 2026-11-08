-- IST-aware evaluator with overnight windows and next-day spill (fix of 0001 version).
-- Rule semantics: "Su 21:00-01:00" also matches Monday 00:30 (window crosses midnight).
-- Unknown (NULL) stays NULL — deliberately NOT treated as closed (plan FR-202).
CREATE OR REPLACE FUNCTION hours_open_at(rules jsonb, at timestamptz)
RETURNS boolean AS $$
DECLARE r jsonb; tfrom time; tto time; day_idx int; prev_idx int; local_ts timestamptz;
BEGIN
  IF rules IS NULL THEN RETURN NULL; END IF;
  local_ts := at AT TIME ZONE 'Asia/Kolkata';
  day_idx := EXTRACT(dow FROM local_ts)::int;
  prev_idx := (day_idx + 6) % 7;
  FOR r IN SELECT * FROM jsonb_array_elements(rules) LOOP
    IF (r ? 'always') THEN RETURN true; END IF;
    tfrom := (r->>'from')::time;
    tto   := (r->>'to')::time;
    IF tfrom <= tto THEN
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(r->'days') dd WHERE dd::int = day_idx) THEN
        IF local_ts::time >= tfrom AND local_ts::time < tto THEN RETURN true; END IF;
      END IF;
    ELSE
      IF EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(r->'days') dd
        WHERE dd::int IN (day_idx, prev_idx)
      ) THEN
        IF local_ts::time >= tfrom OR local_ts::time < tto THEN RETURN true; END IF;
      END IF;
    END IF;
  END LOOP;
  RETURN false;
END;
$$ LANGUAGE plpgsql;
