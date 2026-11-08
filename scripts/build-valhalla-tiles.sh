#!/usr/bin/env bash
# Build Valhalla tiles for the Bengaluru extract (plan §5.3).
# Prereq: data/bengaluru-latest.osm.pbf must exist (scripts/fetch-data.sh).
set -euxo pipefail
cd "$(dirname "$0")/.."

mkdir -p tiles data

docker run --rm \
  -v "$PWD/data:/data" \
  -v "$PWD/tiles:/custom_files" \
  ghcr.io/valhalla/valhalla:latest /bin/bash -c '
    set -ex
    valhalla_build_config --mjolnir-tile-dir /data/valhalla-tiles --mjolnir-concurrency 2 \
      > /custom_files/valhalla.json
    valhalla_build_tiles -c /custom_files/valhalla.json /data/bengaluru-latest.osm.pbf
    valhalla_build_extract -v -c /custom_files/valhalla.json
    rm -rf /data/valhalla-tiles
  '

echo "Valhalla tiles built at ./tiles/valhalla.tar (or tiles/valhalla_tiles)"
