#!/usr/bin/env bash
set -euo pipefail

DESTINO="$HOME/respaldos"
mkdir -p "$DESTINO"
tar -czf "$DESTINO/docs-$(date +%F).tar.gz" "$HOME/documentos"
echo "Respaldo creado: $(date +%F)"
