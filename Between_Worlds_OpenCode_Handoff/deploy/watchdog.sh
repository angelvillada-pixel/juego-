#!/usr/bin/env bash
# Between Worlds — watchdog P3-P5 (para cron/systemd en el VPS, cada 5 min).
# Si el puerto del juego no responde 3 veces seguidas, reinicia el servicio
# `game` del compose y lo anota en el log. No toca Caddy ni el host.
#   */5 * * * * /opt/bw/deploy/watchdog.sh >> /var/log/bw-watchdog.log 2>&1
set -u
COMPOSE="${COMPOSE:-/opt/bw/deploy/docker-compose.yml}"
ENV_FILE="${ENV_FILE:-/opt/bw/deploy/.env}"
HOST="${GAME_HOST:-127.0.0.1}"
PORT="${GAME_PORT:-26500}"
FAILS=0

for _ in 1 2 3; do
  if timeout 5 bash -c "</dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
    exit 0  # vivo
  fi
  FAILS=$((FAILS + 1))
  sleep 5
done

echo "$(date -u +%FT%TZ) watchdog: puerto ${HOST}:${PORT} caído 3/3, reiniciando game"
docker compose -f "$COMPOSE" --env-file "$ENV_FILE" restart game
