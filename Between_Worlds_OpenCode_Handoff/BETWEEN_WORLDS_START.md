# BETWEEN WORLDS — START INSTRUCTIONS FOR OPENCODE

Actúa desde este momento como el LEAD ENGINEER y PROGRAMADOR PRINCIPAL de BETWEEN WORLDS.

Tu objetivo es transformar toda la documentación existente en un videojuego funcional, siguiendo el diseño que ya hemos definido.

## 1. LEE PRIMERO TODA LA DOCUMENTACIÓN

Antes de modificar el proyecto, lee completamente:

- AGENTS.md
- README_OPENCODE.md
- OPENCODE_FIRST_TASK.md
- docs/MASTER_DESIGN.md
- docs/DECISIONS.md
- docs/OPEN_QUESTIONS.md
- y cualquier otro archivo relevante existente en el repositorio.

Después inspecciona toda la estructura del repositorio y determina:

- qué existe
- qué falta
- si ya existe un proyecto Godot
- configuración actual
- dependencias
- código existente
- herramientas disponibles

No asumas que la documentación es perfecta. Detecta contradicciones y posibles problemas técnicos.

## 2. REGLA GENERAL DE DECISIONES

No preguntes constantemente por detalles menores.

Si una decisión pequeña no está definida:
- usa la solución más coherente con el diseño
- documenta el supuesto
- continúa

Sólo detente y pregunta si aparece una decisión importante que pueda cambiar:
- la identidad del juego
- la arquitectura
- el gameplay principal
- la plataforma
- el objetivo técnico

No cambies una decisión congelada sin una razón técnica seria.

## 3. IDENTIDAD DE BETWEEN WORLDS

Between Worlds es un shooter PvP 2D competitivo:

- 5 vs 5
- PC + navegador
- partidas estándar de 8–12 minutos
- combate rápido pero táctico
- construcción similar en espíritu a Fortoresse
- gran parte del terreno destruible
- movimiento fuertemente inspirado en Fortoresse
- pixel art + ilustración
- universo militar / tecnológico
- dos civilizaciones
- lore ligero, con prioridad absoluta al PvP

Filosofía principal:

SHOOT + MOVE + BUILD + DESTROY + CONTROL + TEAMWORK

No es un clon literal de Fortoresse.

No copies:
- código
- assets
- personajes
- mapas
- sonidos
- música
- nombres protegidos
- interfaz
- contenido propietario

Fortoresse es únicamente una referencia conceptual y de gameplay.

## 4. REGLAS DE GAMEPLAY CONGELADAS

### PLAYER

- 100 HP
- no existe regeneración automática de HP
- recuperación de HP sólo mediante recuperación externa
- armadura basada en equipamiento
- armadura reduce un porcentaje del daño
- armadura NO se degrada durante la vida
- armadura NO regenera
- armadura NO reduce knockback
- headshots activados
- sólo existen dos zonas de daño: HEAD y BODY
- extremidades no tienen multiplicadores propios
- multiplicador global de headshot: 1.5x
- NUNCA debe existir one-shot por headshot convencional

### ARMOR

LIGHT:
- 10% damage reduction
- +10% horizontal movement speed

MEDIUM:
- 20% damage reduction
- velocidad horizontal normal

HEAVY:
- 30% damage reduction
- -10% horizontal movement speed

El salto es igual para las tres.

La armadura debe ser visualmente claramente diferente:
- Light
- Medium
- Heavy

La diferencia de peso afecta principalmente:
- mitigación de daño
- velocidad horizontal

No modificar la altura de salto.

### LOADOUT

- Primary weapon
- Secondary weapon
- 1 Armor slot
- 1 Utility slot

Armor y Utility sólo pueden cambiarse al morir.

No permitir cambio libre durante una vida.

### COMBAT

- las balas normales hacen DAÑO ÚNICAMENTE
- las balas normales NO hacen knockback
- Damage y Knockback deben estar separados internamente para futuras armas/utilidades especiales
- el combate debe ser rápido pero permitir reaccionar
- movimiento, construcción y cobertura forman parte de la supervivencia

### RESPAWN

- modos normales: respawn rápido
- VIP: reglas especiales
- Domination: una vida durante la ronda

### PICKUPS

- Health
- Armor
- Ammo
- recuperación aproximada de 25–40%
- nunca superar máximos

IMPORTANTE:
La documentación contiene una tensión entre:
- armadura fija durante la vida
- Armor Pickup

No inventes una solución permanente como si fuese definitiva. Mantén esta parte modular hasta resolverla formalmente. Si necesitas una solución provisional para el prototipo, documenta claramente que es provisional.

## 5. CONSTRUCCIÓN

La construcción es una mecánica central.

Debe mantener el espíritu de Fortoresse:

- rápida
- basada en grid
- disponible para todos
- útil ofensivamente
- útil defensivamente
- modifica rutas
- modifica líneas de tiro
- crea cobertura
- cambia el flujo de la partida

El terreno debe ser parcialmente destruible.

Separar claramente:

- Permanent geometry
- Destructible geometry
- Constructible geometry

Los mapas deben representarse como DATOS, no como lógica hardcodeada.

La arquitectura debe permitir un futuro Map Editor.

## 6. ARQUITECTURA

No hagas un proyecto monolítico.

Separar:

### CLIENT
- input
- rendering
- animation
- audio
- UI
- local prediction
- presentation

### GAME SERVER
- authoritative movement
- combat
- damage
- construction
- destruction
- objectives
- respawn
- game rules

### BACKEND
- accounts
- progression
- statistics
- matchmaking
- friends
- moderation

### DATABASE
- player data
- statistics
- progression
- inventory

El servidor debe ser autoritativo para:

- posición válida
- movimiento
- daño
- armas
- munición
- construcción
- pickups
- objetivos
- resultado de partida

Nunca confíes en el cliente para decidir:

- daño
- kills
- inventario
- moneda
- resultado de partida

## 7. TECNOLOGÍA

Godot es el candidato técnico principal, salvo que durante la implementación aparezca una incompatibilidad seria con los requisitos.

El proyecto debe quedar preparado para:

- PC
- Web
- servidor dedicado

Mantén separadas las partes de cliente y servidor.

No cambies de motor arbitrariamente.

Si aparece una limitación técnica real:
1. documenta el problema
2. analiza alternativas
3. elige la solución menos destructiva
4. continúa

## 8. OBJETIVO DEL PRIMER PROTOTIPO

NO desarrolles todo Between Worlds de una vez.

Primero construye un FIRST PLAYABLE PROTOTYPE.

Debe demostrar como mínimo:

1. proyecto funcional
2. Player Controller 2D
3. movimiento inspirado en Fortoresse
4. salto
5. crouch si encaja en la arquitectura inicial
6. cámara
7. 100 HP
8. Light / Medium / Heavy
9. modificador horizontal +10 / 0 / -10%
10. armor mitigation 10 / 20 / 30%
11. Primary weapon
12. Secondary weapon
13. disparo
14. munición
15. recarga
16. cambio de arma
17. headshots
18. multiplicador global 1.5x
19. no one-shot
20. construcción en grid
21. bloques construidos
22. destrucción
23. Health pickup
24. Armor pickup como sistema modular/provisional
25. Ammo pickup
26. muerte
27. respawn rápido
28. primer escenario de prueba

## 9. METODOLOGÍA DE IMPLEMENTACIÓN

Trabaja de forma incremental.

Antes de cada sistema importante:
- inspecciona el código
- identifica dependencias
- revisa arquitectura
- implementa una parte pequeña
- prueba
- corrige
- continúa

Después de cada milestone:
- ejecuta las pruebas disponibles
- revisa errores
- revisa warnings relevantes
- verifica que no rompiste sistemas anteriores

Evita:
- archivos gigantes
- duplicación
- dependencias innecesarias
- hardcodear valores de gameplay si pueden ser configurables

Usa nombres claros.

Documenta las decisiones técnicas relevantes.

## 10. QUÉ NO CONSTRUIR TODAVÍA

No implementar todavía:

- tienda
- battle pass
- economía completa
- ranking online
- matchmaking público
- campaña
- lore profundo
- cientos de armas
- cientos de mapas
- monetización
- sistemas sociales complejos
- contenido que no sea necesario para validar el core gameplay

Primero debe ser divertido el núcleo.

## 11. PRIORIDADES

Orden de prioridad:

1. Gameplay
2. Física
3. Responsividad del input
4. Arquitectura
5. Networking
6. Rendimiento
7. Seguridad
8. Mantenibilidad
9. UI
10. Contenido

## 12. COMPORTAMIENTO DEL AGENTE

Trabaja de forma autónoma.

No preguntes decisiones pequeñas.

Cuando una decisión menor esté abierta:
- usa una solución razonable
- registra el supuesto
- continúa

Cuando una decisión importante necesite cambiar:
- explica la razón
- explica el impacto
- pide confirmación antes de alterar el diseño fundamental

No inventes características sin justificación.

No presentes algo como terminado si no está realmente implementado y probado.

## 13. PRIMERA ACCIÓN

Empieza ahora.

1. Lee toda la documentación.
2. Inspecciona el repositorio.
3. Comprueba herramientas disponibles.
4. Comprueba si Godot está instalado.
5. Comprueba dependencias.
6. Crea un diagnóstico del estado actual.
7. Crea un plan técnico del primer prototipo.
8. Después empieza inmediatamente a implementar el primer milestone.

NO te limites a entregar un plan.

QUIERO QUE EMPIECES A CONSTRUIR EL PROYECTO.

## 14. OBJETIVO DE ESTA PRIMERA SESIÓN

Al terminar quiero tener, como mínimo si el entorno lo permite:

- proyecto ejecutable
- arquitectura inicial limpia
- player funcional
- movimiento funcional
- primera arma funcional
- HP/armor funcional
- construcción básica funcional
- destrucción básica funcional
- respawn funcional

Si algo queda bloqueado por una dependencia externa o un problema real del entorno:
- no finjas que está terminado
- documenta el bloqueo
- continúa con todo lo que sí sea posible

Al final entrega un informe con:

1. qué implementaste
2. qué archivos creaste/modificaste
3. qué pruebas ejecutaste
4. qué funciona
5. qué no funciona
6. qué queda pendiente
7. próximos pasos recomendados

Empieza.
