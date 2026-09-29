# Between Worlds — Pipeline de arte y audio (Punto 4, provisional)

Hasta el pixel-art final, todo lo visual/sonoro es **procedural y data-driven**:
mismo código de dibujo para todos los clientes (sin desync: es solo vista).

## Estructura

- `src/ui/pawn_art.gd` — siluetas Light/Medium/Heavy + trim de facción.
  El arte final deberá mantener esta regla: **silueta distinta por armadura**,
  color de facción solo como trim (nunca como única señal).
- `src/construction/block.gd` — color por tipo + remache por hash de celda.
- `src/map/test_map.gd` — fondo de territorios Aegis/Rift + zonas sutiles.
- `src/data/faction_data.gd` — Aegis (teal) vs Rift (rojo). Solo identidad.
- `src/audio/sfx_synth.gd` — 14 SFX sintetizados, 22050 Hz mono 16-bit.
- `src/audio/audio_manager.gd` — autoload `Audio`: pool 8 voces, pad en loop,
  volúmenes en `user://settings.cfg`.

## Convenciones para assets futuros (`assets/`)

- `assets/sprites/<faccion>/<armor>_*.png` — import pixel-art, filtro Nearest.
- `assets/audio/*.ogg` — SFX finales reemplazan 1:1 los nombres de `SfxSynth.NAMES`.
- `assets/maps/*.json` — cuando el editor exista; hoy los mapas son `map_data.gd`.
- Regla: ningún asset cambia gameplay; solo vista. La autoridad no lee assets.

## Pendiente (arte final)

Pixel-art de peones/bloques/fondos, música compuesta, voces, cinemáticas.
Q10 sigue abierta hasta esa entrega.
