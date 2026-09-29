# Between Worlds — Open Technical/Design Questions

These are intentionally NOT blockers for starting the first prototype.

1. ~~Exact player movement constants~~ — CERRADA provisional Punto 1 (2026-09-29): ver DECISIONS.md + `tests/unit/test_movement.gd`.
2. ~~Exact damage/TTK tuning~~ — CERRADA provisional Punto 1: ver DECISIONS.md + `tests/unit/test_balance_point1.gd`.
3. ~~Exact behavior/value of Armor Pickup~~ — CERRADA provisional Punto 1: escudo temporal separado, MAX_SHIELD 50, 30%.
4. ~~Exact construction block health/material categories~~ — CERRADA provisional Punto 1: 200/100/120 + structure_mult 1.0/2.0/0.6.
5. ~~Exact utility roster and cooldowns~~ — CERRADA provisional Punto 1: solo Dash, 8s, impulso 380.
6. ~~Exact rules for VIP/Capture/Domination and the future core mode~~ — CERRADA provisional Punto 2 (2026-09-29): FRONTLINE/VIP/Domination en `src/data/mode_data.gd` + `tests/unit/test_modes.gd`. Capture queda fuera del slice (solo 3 modos).
7. ~~Exact web transport after latency/loss benchmarks~~ — PARCIAL Punto 3 (2026-09-29): protocolo + `SimTransport` + plan en `docs/NET_BENCH.md`. Falta medición de campo WS vs WebRTC con 2 máquinas/navegadores.
8. Final map scale and grid size; 16 px is only the laboratory prototype baseline. — PARCIAL Punto 4: 2 mapas data-driven (`lab`, `arena`) con misma escala; la escala final sigue abierta.
9. Final commercial name validation, domains and trademark review.
10. Final art direction for the two civilizations. — PARCIAL Punto 4: identidad provisional (Aegis vs Rift, siluetas + trim, pipeline en `docs/ART_PIPELINE.md`); pixel-art final pendiente.

When a minor value is needed before these questions are resolved, choose a sensible prototype value, label it provisional, and continue.
