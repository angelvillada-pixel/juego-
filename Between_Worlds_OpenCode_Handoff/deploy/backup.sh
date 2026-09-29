#!/usr/bin/env bash
# Between Worlds — backup del volumen de datos P3-P5 (auth, telemetría).
# Uso: ./backup.sh [volumen] [dir-salida]   (defecto: bw-data ./backups)
# Guarda bw-data-YYYYmmdd-HHMMSS.tgz y conserva las últimas 7 copias.
# Restaurar: docker run --rm -v VOL:/data -v DIR:/b ubuntu \
#              tar xzf /b/<fichero> -C /data   (con el compose parado)
set -eu
VOLUME="${1:-bw-data}"
OUTDIR="${2:-./backups}"
KEEP=7

mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
FILE="${OUTDIR}/bw-data-${TS}.tgz"
docker run --rm -v "${VOLUME}:/data:ro" -v "${OUTDIR}:/backup" ubuntu:24.04 \
  tar czf "/backup/bw-data-${TS}.tgz" -C /data .
echo "backup OK: ${FILE}"
ls -1t "${OUTDIR}"/bw-data-*.tgz | tail -n +$((KEEP + 1)) | xargs -r rm -f
echo "retención: se conservan las últimas ${KEEP}"
