# Between Worlds — Despliegue (Punto 5)

## Requisitos

- Godot 4.7.2 stable + plantillas de exportación 4.7.2.
- `export_presets.cfg` del repo (Web + Windows + Linux). **Sin verificar**:
  regenerar desde el editor antes de publicar.

## Chequeos locales (siempre antes de desplegar)

```
godot --headless --path . --quit
godot --headless --path . -s res://tests/run_tests.gd
```

## Servidor dedicado

Local:

```
godot --headless --path . -s res://src/server/server_main.gd -- --port=26500 --mode=frontline --map=lab
```

Docker:

```
docker build -t between-worlds-server .
docker run -p 26500:26500 between-worlds-server
```

El cliente se une desde el menú (Callsign + Server + JOIN) o con
`--connect=ws://host:26500`.

## Web

1. Exportar preset `Web` a `dist/web/`.
2. Servir por HTTPS con compresión (WASM/PCK) — renderer Compatibility.
3. Probar contra servidor dedicado con 2 navegadores (ver `docs/NET_BENCH.md`).

## CI

`.github/workflows/ci.yml`: descarga Godot 4.7.2, chequeo headless y suite.
