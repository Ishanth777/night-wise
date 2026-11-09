#!/usr/bin/env bash
# Reproducible geodata acquisition (plan §6, §8).
#
# Downloads the real Geofabrik Southern-Zone extract and clips it to the
# Bengaluru service bbox used by the API and Valhalla. Nothing synthetic is
# produced — the output is an OSM PBF that the ingest job parses directly.
#
#   ./scripts/fetch-and-clip-data.sh
#
# The bbox must match SERVICE_BBOX_* in backend/.env and the Flutter app.
set -euo pipefail
cd "$(dirname "$0")/.."

URL="${OSM_SOURCE_URL:-https://download.geofabrik.de/asia/india/southern-zone-latest.osm.pbf}"
SRC="data/southern-zone-latest.osm.pbf"
OUT="data/bengaluru-latest.osm.pbf"
# osmium order is W,S,E,N
BBOX="77.30,12.70,77.90,13.25"
OSMIUM_IMAGE="${OSMIUM_IMAGE:-krizleebear/docker-osmium-tool:v1.19.1}"

mkdir -p data

if [[ ! -s "$SRC" ]]; then
  echo "Downloading $URL"
  curl -fL --retry 3 --retry-delay 3 -o "$SRC.part" "$URL"
  mv "$SRC.part" "$SRC"
else
  echo "Using existing $SRC"
fi

echo "Clipping to $BBOX"
docker run --rm \
  -v "$PWD/data:/data" \
  "$OSMIUM_IMAGE" \
  osmium extract --overwrite -b "$BBOX" -o "/data/$(basename "$OUT")" "/data/$(basename "$SRC")"

ls -lh "$SRC" "$OUT"
echo "Next: cd backend && OSM_PBF_PATH=../data/bengaluru-latest.osm.pbf npm run ingest:osm"
echo "Then: ./scripts/build-valhalla-tiles.sh"
