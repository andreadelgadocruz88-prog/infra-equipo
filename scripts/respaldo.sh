#!/usr/bin/env bash
# respaldo.sh - respalda documentos y base de datos, y genera hashes sha256
set -euo pipefail

DESTINO="$HOME/respaldos"
FECHA="$(date +%F)"
mkdir -p "$DESTINO"

# 1. Documentos
tar -czf "$DESTINO/docs-$FECHA.tar.gz" "$HOME/documentos"
echo "Respaldo de documentos: docs-$FECHA.tar.gz"

# 2. Base de datos PostgreSQL (si el contenedor esta activo)
if [ "$(docker inspect -f '{{.State.Running}}' compose-db-1 2>/dev/null)" = "true" ]; then
  docker exec compose-db-1 sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$DESTINO/bd-$FECHA.sql.gz"
  echo "Respaldo de la base de datos: bd-$FECHA.sql.gz"
else
  echo "AVISO: compose-db-1 no esta activo, se omite la base de datos"
fi

# 3. Hashes de integridad
cd "$DESTINO"
sha256sum "docs-$FECHA.tar.gz" > "docs-$FECHA.sha256"
if [ -f "bd-$FECHA.sql.gz" ]; then
  sha256sum "bd-$FECHA.sql.gz" > "bd-$FECHA.sha256"
fi
echo "Hashes generados. Verifica con: sha256sum -c docs-$FECHA.sha256"
