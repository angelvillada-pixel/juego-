# Between Worlds — Despliegue (Punto 5)

## Requisitos

- Godot 4.7.2 stable + plantillas de exportación 4.7.2.
- `export_presets.cfg` del repo (Web + Windows + Linux), **verificado
  2026-09-29**: los tres presets exportan limpio en headless.

## Chequeos locales (siempre antes de desplegar)

```
godot --headless --path . --quit
godot --headless --path . -s res://tests/run_tests.gd
```

## Servidor dedicado

Local (solo tu máquina; el bind por defecto ya es localhost):

```
godot --headless --path . -s res://src/server/server_main.gd -- --port=26500 --mode=frontline --map=lab
```

Docker manual (solo LAN/dev; el puerto queda en localhost del host):

```
docker build -t between-worlds-server .
docker run -p 127.0.0.1:26500:26500 between-worlds-server
```

Producción con TLS (S2):

```
cp deploy/.env.example deploy/.env  # rellenar DOMAIN + EMAIL
docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d --build
```

Esto levanta `game` + `caddy`: internet entra por 80/443, Caddy emite el
certificado solo y proxea a `game:26500`. El 26500 nunca se publica directo.

El cliente se une desde el menú (Callsign + Server + JOIN) o con
`--connect=wss://TU-DOMINIO` (en producción) o `--connect=ws://host:26500`
(solo LAN/dev). En build web, `ws://` se rehúsa: usa siempre `wss://`.

## Web

1. Exportar preset `Web` a `dist/web/`.
2. Servir por HTTPS con compresión (WASM/PCK) — renderer Compatibility.
3. Probar contra servidor dedicado con 2 navegadores (ver `docs/NET_BENCH.md`).

## CI

`.github/workflows/ci.yml`: descarga Godot 4.7.2, chequeo headless y suite
(rutas corregidas al subdir del proyecto + trigger `workflow_call`).

## CI-deploy (P3-P5)

`.github/workflows/deploy.yml` (disparo manual): verify → build de `game` →
push a GHCR → redespliegue por SSH. Secrets necesarios: `VPS_HOST`,
`VPS_USER`, `VPS_SSH_KEY`. En el VPS basta tener el repo clonado en
`/opt/bw` con `deploy/.env` relleno.

## Watchdog (P3-P5)

`deploy/watchdog.sh` para cron cada 5 min (reinicia `game` si el puerto cae
3 sondas seguidas). Logs con rotación `10m x3` ya en el compose:

```
*/5 * * * * /opt/bw/deploy/watchdog.sh >> /var/log/bw-watchdog.log 2>&1
```

## Backups (P3-P5)

`deploy/backup.sh [volumen] [dir]` vuelca `bw-data` (auth + telemetría) a
`.tgz` con retención de 7 copias. Restaurar con el compose parado:

```
docker run --rm -v bw-data:/data -v $PWD/backups:/b ubuntu:24.04 \
  tar xzf /b/<fichero> -C /data
```

E2E del script pendiente de daemon Docker en marcha (sintaxis OK).
