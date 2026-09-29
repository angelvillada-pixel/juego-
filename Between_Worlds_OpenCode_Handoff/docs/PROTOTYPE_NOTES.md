# Between Worlds — Prototype Notes (Diagnóstico + Plan Técnico + Supuestos)

Sesión: primer vertical slice jugable. Fecha: 19/09/2026.

## 1. Diagnóstico del estado inicial

- No existía ningún proyecto Godot: no hay `project.godot`, ni `src/`, ni assets.
- El repositorio contenía únicamente documentación (`AGENTS.md`, `docs/*`, handoff).
- Godot NO estaba instalado en el sistema. Se instaló **Godot 4.7.2 stable** (win64, `4.7.2.stable.official`) descargado de los releases oficiales.
- Git disponible (2.55.0). El repo de trabajo no es aún un repositorio git.
- Sin dependencias externas necesarias: ruta principal GDScript (sin C# para mantener la ruta Web viable).
- Windows + WSL (Ubuntu) disponible; no afecta a este vertical slice.

## 2. Decisiones de arquitectura para el primer milestone

- Raíz del proyecto Godot = raíz del repositorio (`project.godot` en la carpeta del handoff).
- Organización modular por dominios: `src/core`, `src/data`, `src/combat`, `src/player`, `src/weapons`, `src/construction`, `src/pickups`, `src/map`, `src/match`, `src/net`, `src/ui`, `tests/`.
- **Data-driven**: armas, armaduras, bloques, pickups y mapa viven en clases de datos (`*.data.gd`), nunca hardcodeados en el gameplay.
- **Simulación autoritativa local**: primero el vertical slice corre una simulación local (un solo proceso). El daño, muerte, construcción y recogida se computan en el lado "servidor" (el mismo proceso); el cliente es una capa de presentación sobre la misma simulación. Existe una interfaz `NetTransport` preparada para cuando llegue la etapa de networking real.
- Zonas de daño HEAD/BODY determinadas por hitbox espacial del jugador (AABB de cabeza).

## 3. Constants de diseño provisionales (etiquetadas como provisionales)

- `MAX_HP = 100`
- `HEADSHOT_MULTIPLIER = 1.5`
- Zonas: HEAD (1.5x) / BODY (1.0x). Sin one-shot: ningún arma del set supera 99 de daño teórico máximo.
- `GRID_SIZE = 16` px
- Mapa de laboratorio: 3200x1800 px = grid 200x112.
- Velocidad horizontal base (Medium) = 240 px/s. Light +10% = 264. Heavy -10% = 216.
- Salto compartido: impulso -360 (gravedad 980).
- Crouch: reduce hitbox y velocidad horizontal *0.6 (provisional).
- Armaduras: Light 10%, Medium 20%, Heavy 30% de mitigación.
- Pickups: Health 30%, Armor(Shield) 30%, Ammo 40% del máximo (rango 25-40% según diseño).
- Armas de prueba: Rifle 20d/600rpm/mag30/rec2.1s; Precision 60d/100rpm/mag5/rec3.0s; Pistol (secundaria) 14d/420rpm/mag12/rec1.4s.
- Respawn rápido: 3 s tras la muerte (provisional).

## 4. Supuestos provisionales documentados

1. **Armor Pickup** (tensión con "armadura fija durante la vida"): el pickup otorga un *escudo/buffer temporal* separado de la armadura base (como recomienda `MASTER_DESIGN` 7.2). No modifica la armadura base. Es una solución provisional de prototipo, modular en `PickupService`.
2. **Condición de victoria del laboratorio**: partida con N vidas (3) y puntos: destruir todos los objetivos `TARGET` del mapa gana; perder todas las vidas pierde. Sólo para validar flujo de partida en vertical slice.
3. **Suministro de munición** inicial y por recarga: provisional.
4. **Mapa generado por datos**: el mapa de laboratorio se genera de forma determinista a partir de parámetros (`seed`, densidades, alturas) en `MapLayout`. Sigue siendo *datos*, no lógica hardcodeada, y es reemplazable por cualquier mapa-serializado.
5. **Bloque básico de construcción**: 16x16, HP 200, propio de equipo (para el slice: equipo neutro/locales).

## 5. Plan técnico del primer prototipo (milestones)

| Paso | Sistema | Estado |
|---|---|---|
| M0 | Scaffold del proyecto Godot + constants + data | hecho |
| M1 | Player controller 2D (movimiento/salto/crouch/cámara) | pendiente |
| M2 | HP / armaduras L/M/H / zonas de daño / headshot | pendiente |
| M3 | Armas primarias/secundaria + munición + recarga | pendiente |
| M4 | Construcción en grid + destrucción | pendiente |
| M5 | Pickups | pendiente |
| M6 | Match manager (respawn, vidas, victoria/derrota) | pendiente |
| M7 | HUD + escena principal + primer mapa | pendiente |
| M8 | Tests unitarios y verificación headless | pendiente |