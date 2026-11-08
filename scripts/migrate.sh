#!/usr/bin/env bash
# Apply SQL migrations in filename order, tracked in schema_migrations.
set -euo pipefail
cd "$(dirname "$0")/.."
DB_URL="${DATABASE_URL:-postgres://nightwise:nightwise@localhost:5432/nightwise}"

docker exec -i nightwise-postgres psql -U nightwise -d nightwise -tAc "
  CREATE TABLE IF NOT EXISTS schema_migrations (
    name TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );" > /dev/null

for f in backend/src/db/migrations/*.sql; do
  base=$(basename "$f")
  applied=$(docker exec -i nightwise-postgres psql -U nightwise -d nightwise -tAc \
    "SELECT 1 FROM schema_migrations WHERE name='$base'")
  if [ "$applied" = "1" ]; then
    echo "= skip $base"
  else
    echo "+ applying $base"
    docker exec -i nightwise-postgres psql -U nightwise -d nightwise -v ON_ERROR_STOP=1 < "$f" > /dev/null
    docker exec -i nightwise-postgres psql -U nightwise -d nightwise -tAc \
      "INSERT INTO schema_migrations(name) VALUES ('$base')" > /dev/null
  fi
done
echo "migrations up to date"
