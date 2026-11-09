#!/usr/bin/env bash
# NightWise API smoke test — exercises the real stack end to end.
#
#   ./scripts/smoke-api.sh
#   API_BASE_URL=http://localhost:3000 ./scripts/smoke-api.sh --with-places
#
# Requires: curl, python3, and the API + PostgreSQL/PostGIS/Redis/Valhalla
# services running (see docs/SETUP.md). It creates a throwaway account and
# deletes it at the end. It never calls an endpoint with fabricated data: all
# geography used here is inside the Bengaluru service area.
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"
WITH_PLACES=false
[[ "${1:-}" == "--with-places" ]] && WITH_PLACES=true

command -v curl >/dev/null || { echo "curl is required"; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

say() { printf '%s\n' "$*"; }
ok() { pass=$((pass + 1)); say "  PASS  $*"; }
bad() { fail=$((fail + 1)); say "  FAIL  $*"; }

# request METHOD PATH [BODY] [TOKEN] -> writes body to $TMP/body, status to $TMP/status
request() {
  local method="$1" path="$2" body="${3:-}" token="${4:-}"
  local args=(-sS -o "$TMP/body" -w '%{http_code}' -X "$method" "$API_BASE_URL$path")
  [[ -n "$body" ]] && args+=(-H 'Content-Type: application/json' -d "$body")
  [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
  curl "${args[@]}" > "$TMP/status" || { echo "curl failed for $path"; exit 1; }
  cat "$TMP/status"
}

json() { python3 -c "$1" < "$TMP/body"; }

assert_status() {
  local expected="$1" label="$2" status
  status="$(cat "$TMP/status")"
  if [[ "$status" == "$expected" ]]; then ok "$label (HTTP $status)";
  else bad "$label (expected $expected, got $status): $(head -c 400 "$TMP/body")"; fi
}

say "NightWise smoke test -> $API_BASE_URL"

# ---------------------------------------------------------------- health
request GET /api/health
assert_status 200 "health probe"
[[ "$(json 'import json,sys; print(json.load(sys.stdin)["ok"])')" == "True" ]] \
  && ok "health payload ok" || bad "health payload missing ok=true"

# ---------------------------------------------------------------- auth
EMAIL="smoke_$(date +%s)_$RANDOM@nightwise.test"
PASSWORD="smoke-pass-123"
request POST /api/auth/register "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
assert_status 201 "register throwaway account"
ACCESS="$(json 'import json,sys; print(json.load(sys.stdin)["data"]["accessToken"])')"
REFRESH="$(json 'import json,sys; print(json.load(sys.stdin)["data"]["refreshToken"])')"
[[ -n "$ACCESS" ]] && ok "received access token" || bad "access token missing"

request GET "/api/emergency/nearby?lat=12.9756&lng=77.6040&radiusM=3000" "" "$ACCESS"
assert_status 200 "emergency services nearby"
python3 - "$TMP/body" << 'EOF' && ok "emergency payload has real points in bbox" || bad "emergency payload invalid"
import json, sys
rows = json.load(open(sys.argv[1]))["data"]
assert rows, "no emergency rows"
for r in rows:
    assert 12.7 < r["lat"] < 13.25, r
    assert 77.3 < r["lng"] < 77.9, r
    assert 0 <= r["distanceM"] <= 3000, r
EOF

# ---------------------------------------------------------------- walk routes
DEPART="$(python3 - << 'EOF'
from datetime import datetime, timedelta, timezone
# Next hour in IST, formatted with an explicit offset (API rejects naive times).
ist = timezone(timedelta(hours=5, minutes=30))
print((datetime.now(timezone.utc) + timedelta(hours=2)).astimezone(ist).strftime('%Y-%m-%dT%H:%M:%S+05:30'))
EOF
)"
WALK_BODY="{\"origin\":{\"lat\":12.9756,\"lng\":77.6040},\"destination\":{\"lat\":12.9763,\"lng\":77.5925},\"mode\":\"walk\",\"departureTime\":\"$DEPART\",\"userPrefs\":{\"safetyVsTime\":0.8}}"
request POST /api/routes/recommend "$WALK_BODY" "$ACCESS"
assert_status 200 "walk route recommendation"
python3 - "$TMP/body" << 'EOF' && ok "walk routes are scored, tiled and inside Bengaluru" || bad "walk route payload invalid"
import json, sys
p = json.load(open(sys.argv[1]))["data"]
assert p["mode"] == "walk"
assert p["routes"], "no routes"
assert "environmental estimates" in p["disclaimer"]
for r in p["routes"]:
    s = r["summary"]
    assert 0 <= s["safetyScore"] <= 100
    assert 0 <= s["confidence"] <= 1
    assert s["distanceM"] > 0 and s["durationS"] > 0
    coords = r["geometry"]["coordinates"]
    assert len(coords) > 2
    for lng, lat in coords:
        assert 77.3 < lng < 77.9 and 12.7 < lat < 13.25, (lng, lat)
    segs = r["segments"]
    assert segs and abs(segs[0]["startM"]) < 1
    for a, b in zip(segs, segs[1:]):
        assert abs(a["endM"] - b["startM"]) < 0.01, (a["endM"], b["startM"])
    for key in ("lights", "shops", "activity", "community", "emergency"):
        assert key in r["indicators"], key
        assert r["indicators"][key]["status"], key
EOF

# ---------------------------------------------------------------- vehicle routes
VEHICLE_BODY="{\"origin\":{\"lat\":12.9352,\"lng\":77.6245},\"destination\":{\"lat\":12.9763,\"lng\":77.5925},\"mode\":\"vehicle\",\"vehicleType\":\"car\",\"departureTime\":\"$DEPART\",\"userPrefs\":{\"safetyVsTime\":0.7}}"
request POST /api/routes/recommend "$VEHICLE_BODY" "$ACCESS"
assert_status 200 "vehicle route recommendation"
python3 - "$TMP/body" << 'EOF' && ok "vehicle routes returned" || bad "vehicle route payload invalid"
import json, sys
p = json.load(open(sys.argv[1]))["data"]
assert p["mode"] == "vehicle"
assert p["routes"], "no vehicle routes"
assert all(r["summary"]["distanceM"] > 3000 for r in p["routes"])
EOF

# ---------------------------------------------------------------- out-of-area guard
BODY='{"origin":{"lat":28.6139,"lng":77.2090},"destination":{"lat":12.9763,"lng":77.5925},"mode":"walk","departureTime":"'"$DEPART"'"}'
request POST /api/routes/recommend "$BODY" "$ACCESS"
assert_status 422 "out-of-service-area rejected"
[[ "$(json 'import json,sys; print(json.load(sys.stdin)["error"]["code"])')" == "OUT_OF_SERVICE_AREA" ]] \
  && ok "out-of-area error code" || bad "wrong out-of-area error code"

# ---------------------------------------------------------------- reports
REPORT_BODY='{"kind":"poor_lighting","severity":3,"lat":12.9756,"lng":77.6040,"note":"smoke test"}'
request POST /api/reports "$REPORT_BODY"
assert_status 201 "anonymous community report accepted"
request GET "/api/reports/nearby?lat=12.9756&lng=77.6040&radiusM=800"
assert_status 200 "nearby reports listed"

# ---------------------------------------------------------------- places (optional network)
if [[ "$WITH_PLACES" == true ]]; then
  request GET "/api/places/search?q=MG%20Road%20Metro%20Station&lat=12.9756&lng=77.6040" "" "$ACCESS"
  assert_status 200 "place search (external geocoder)"
fi

# ---------------------------------------------------------------- refresh + delete
request POST /api/auth/refresh "{\"refreshToken\":\"$REFRESH\"}"
assert_status 200 "refresh token rotation"
NEW_ACCESS="$(json 'import json,sys; print(json.load(sys.stdin)["data"]["accessToken"])')"
[[ -n "$NEW_ACCESS" ]] && ok "rotated access token" || bad "rotated access token missing"

request DELETE /api/auth/account "" "$NEW_ACCESS"
assert_status 204 "account deletion"
request POST /api/auth/login "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
assert_status 401 "login after deletion is refused"

say ""
say "Result: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1
