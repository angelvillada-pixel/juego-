# Between Worlds — Telemetría (Punto 5)

El autoload `Telemetry` registra eventos de balance sin decidir gameplay.
Se activa al empezar partida (`start_session`) y se vuelca a JSONL
(`user://telemetry/session_*.jsonl`) al terminar (`end_session` + `flush`).

## Eventos

| Evento | Datos | Para qué |
|---|---|---|
| `session_start` | mode, map | Contexto |
| `died` | team | Ritmo de muertes por equipo |
| `pickup` | id | Uso de pickups |
| `build` / `destroy` | — | Construcción vs destrucción |
| `target` | remaining, total | Progreso FRONTLINE |
| `session_end` | result | Resultado |
| Contadores `shots_<arma>` | n | DPS real por arma (TTK de campo) |

## Preguntas que responde

- TTK real vs teórico (shots por kill con `died` + `shots_*`).
- ¿Se construye o se destruye más? (`build` vs `destroy`).
- ¿Qué modo retiene hasta el final? (`session_end` por modo).
- ¿Los pickups se usan? (frecuencia por tipo).

## Límites

- 5000 eventos por sesión (anillo); JSONL local, sin subida a servidor.
- El backend central con agregación queda fuera de este slice.
