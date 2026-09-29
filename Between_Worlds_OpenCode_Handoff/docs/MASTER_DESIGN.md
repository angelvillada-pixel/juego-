# BETWEEN WORLDS
MASTER DESIGN DOCUMENT v1.0
Investigación + Diseño + Arquitectura preliminar
18 de septiembre de 2026
Estado: Fase de preproducción. No se ha iniciado la programación del juego.


Nota de nombre: “Between Worlds” queda como nombre de trabajo. Existen otros usos comerciales del nombre, por lo que la validación de marca, dominio y tiendas se hará antes del branding definitivo.

1. Resumen ejecutivo
Between Worlds será un shooter PvP 2D 5v5, rápido pero táctico, pensado desde el inicio para PC y navegador. Su núcleo combina movimiento preciso, armas diferenciadas, construcción libre similar a Fortoresse, destrucción de gran parte del terreno y objetivos que hacen que el espacio de combate cambie durante la partida.
La historia existe principalmente para dar identidad al mundo: dos civilizaciones militar-tecnológicas enfrentadas. El lore será ligero y el PvP será siempre la prioridad.
La regla de diseño central queda expresada así: el jugador no combate solamente contra otros jugadores; combate por el control de un espacio que puede construir, destruir y transformar.
2. Decisiones congeladas

3. ADN de Fortoresse que se conserva
Combate 2D con lectura visual inmediata.
Dos armas activas durante la partida.
Construcción inmediata como herramienta de combate, no como crafting.
Bloques que cambian cobertura, rutas, líneas de tiro y movilidad.
Movimiento técnico con salto, crouch, recoil y control del espacio.
Respawn rápido en partidas normales.
Modos con reglas de supervivencia diferentes, como VIP y Domination.
Profundidad emergente: movimiento + arma + terreno + construcción + equipo.
4. Lo que Between Worlds mejora o moderniza
Cliente moderno sin Flash/SWF.
Servidor autoritativo.
Predicción/reconciliación para mantener sensación de respuesta.
Arquitectura preparada para PC y Web.
Datos de armas, mapas y reglas separados del código.
Map State dinámico: destrucción, construcción y objetivos pueden cambiar el escenario.
Métricas/telemetría para balance.
Seguridad de inventario, resultados, daño y economía del lado servidor.
Editor de mapas contemplado desde la arquitectura.
Pipeline preparado para actualizaciones y contenido futuro.

5. Investigación de Fortoresse — conclusiones
La evidencia pública disponible permite reconstruir con alta confianza la naturaleza del cliente y gran parte del gameplay, aunque no existe un repositorio público completo del servidor privado original de Fortoresse. Por eso este documento distingue entre hechos confirmados, evidencia histórica comunitaria e inferencias.
5.1 Tecnología histórica
Fortoresse pertenece al ecosistema histórico de Atelier 801 y se documenta como cliente basado en Flash/SWF/ActionScript 3.
El ecosistema de Atelier 801 también muestra desarrollo de cliente AS3 y servidor Java en material público de la época.
Proyectos públicos de proxy/loader relacionados con Atelier 801 muestran comunicación mediante sockets y soporte explícito para Fortoresse.
La arquitectura original completa del servidor no es pública; no se debe inventar una lista de clases o módulos internos.
5.2 Gameplay histórico
Fuente oficial de Godot consultada para esta decisión técnica.
Fuente de referencia: guía avanzada “Pro’s guide to M40 A5” de Solfn en el foro de Atelier 801.
5.3 Lecciones que adoptamos
La profundidad está en la interacción entre sistemas, no en tener cientos de armas.
Construcción y movilidad deben diseñarse conjuntamente.
El terreno es parte del combate, no sólo decoración.
El balance debe considerar daño al jugador y daño a estructuras.
Las técnicas avanzadas deben poder emerger de reglas básicas coherentes.
5.4 Lecciones que NO repetiremos
Dependencia de Flash.
Autoridad del cliente sobre resultados competitivos.
Interacciones físicas ambiguas o explotables como base del gameplay.
Arquitectura difícil de actualizar y mantener.
Falta de separación clara entre contenido y lógica.
6. Core Gameplay Loop
### Bucle principal:
OBSERVAR → POSICIONARSE → COMBATIR → CONSTRUIR/DESTRUIR → CAMBIAR EL ESPACIO → CUMPLIR OBJETIVO → MORIR/RESPAWN → VOLVER
La decisión de diseño clave es que morir en una partida normal no significa abandonar la ronda. El jugador vuelve rápido y el mapa sigue evolucionando.
7. Jugador y Loadout

7.1 Armaduras

La armadura no se degrada y no reduce knockback. Su valor de mitigación permanece fijo hasta la muerte. El cambio de armadura ocurre únicamente al morir.
7.2 Recuperación
HP: 100 máximo; sin regeneración automática.
Armor: sin regeneración automática.
Pickups: Health, Armor, Ammo.
Recuperación objetivo: aproximadamente 25–40%.
Nunca se supera el máximo normal.
Decisión provisional del proyecto para resolver la interacción entre “armadura fija” y “Armor Pickup”: el pickup se tratará como un recurso externo separado de la armadura base, sujeto a prueba durante el prototipo de balance. La mecánica exacta de ese recurso queda deliberadamente como parámetro de prueba y no como regla final.
8. Sistema de daño
### Modelo base:
Daño final = Daño base × Multiplicador de zona × (1 − mitigación de armadura)

No existen multiplicadores independientes para brazos o piernas. No existe one-shot convencional por headshot.
8.1 Filosofía TTK
El combate debe ser rápido pero permitir reacción.
El jugador debe poder responder mediante movimiento, cobertura o construcción tras recibir daño.
El headshot premia puntería sin eliminar la posibilidad de respuesta de un solo impacto.
El TTK real dependerá de precisión, movimiento, cobertura, recoil y construcción; no se balanceará sólo con DPS teórico.
9. Player Controller — dirección de diseño
El movimiento debe sentirse muy cercano a Fortoresse, pero implementado con reglas explícitas y deterministas. No se copiarán constantes desconocidas del juego original por especulación.
Movimiento horizontal con aceleración/desaceleración controladas.
Salto y gravedad compartidos entre Light/Medium/Heavy.
Crouch como mecánica de movimiento/posicionamiento.
Recoil como estado de combate separado del daño.
Air control suficiente para conservar un techo de habilidad alto.
Knockback separado del daño; las balas normales no generan knockback.
Cámara y orientación del arma tratadas como parte del feeling de combate.
9.1 Regla de diseño
Las tres armaduras cambian la estrategia horizontal, pero no cambian la gramática fundamental del movimiento. Un jugador veterano debe poder dominar el mismo conjunto de saltos y técnicas independientemente del peso.

## 10. Construcción y destrucción
La construcción será la segunda herramienta de combate junto al arma. Se conservará el espíritu de la conjuración de Fortoresse: rápida, libre, basada en grid y capaz de alterar cobertura, rutas y líneas de tiro.
10.1 Tipos conceptuales

10.2 Principios
Gran parte del terreno será destruible.
El mapa conservará un esqueleto permanente para mantener rutas, objetivos y lectura.
Los bloques tendrán estado y reglas de colisión independientes del arte.
La construcción debe poder crear defensa, rutas, altura, bloqueo y contraataque.
Los exploits de física no deben ser requisitos para jugar bien.
El servidor será autoridad sobre colocación y destrucción.

## 11. Map System
Los mapas serán datos, no código. Se diseñarán para tener un estado inicial y un estado tardío después de varios minutos de destrucción/construcción.

11.1 Map State
MAP(t0) → COMBATE → BUILD/DESTROY → MAP(t1) → OBJETIVO → MAP(t2)
El mapa es un sistema vivo. El estado del mapa forma parte de la partida y debe ser replicable por el servidor.

## 12. Modos de juego

Se contempla posteriormente un modo base propio de Between Worlds, con nombre provisional FRONTLINE, pero sus reglas exactas se cerrarán después de la especificación de objetivos y mapas.

## 13. Mundo y dirección artística
Dos civilizaciones.
Tono militar / tecnológico.
Lore casi inexistente durante la partida; el PvP es la prioridad.
Pixel art + ilustración.
Las armaduras Light/Medium/Heavy deben ser claramente distinguibles visualmente.
Las dos civilizaciones pueden compartir poder competitivo y diferenciarse principalmente mediante identidad visual, audio, efectos y tecnología ficticia.
La interpretación narrativa del título “Between Worlds” queda orientada a dos civilizaciones enfrentadas. La construcción del lore profundo queda deliberadamente contenida hasta que el gameplay necesite elementos concretos del universo.

## 14. Arquitectura online preliminar
CLIENTE PC/WEB → GATEWAY/BACKEND → GAME SERVER AUTORITATIVO → ESTADO DE PARTIDA
14.1 Separación

14.2 Principio autoritativo
El cliente solicita acciones; el servidor decide resultados.
El servidor valida daño, munición, cooldown, construcción, pickups y objetivos.
El servidor no depende del cliente para determinar quién murió o quién ganó.
El cliente usa prediction/interpolation para conservar la respuesta visual.

## 15. Decisión tecnológica provisional
Después de comparar los requisitos del proyecto con la documentación técnica actual, la recomendación provisional es **Godot 4.7.2 stable** para el cliente y para un servidor dedicado/headless basado en el mismo proyecto, manteniendo separadas las responsabilidades de cliente y servidor.
Fuente oficial: archivo de releases de Godot Engine. Godot 4.7.2 es una versión estable publicada el 18 de agosto de 2026; Godot 4.8 estaba todavía en desarrollo en septiembre de 2026.
Fuente oficial: Godot 4.7 — CharacterBody2D y High-level Multiplayer. CharacterBody2D permite control preciso de personajes 2D y el sistema de multiplayer ofrece ENet, WebRTC y WebSocket como capas de transporte disponibles.
Fuente oficial: documentación de exportación web de Godot 4. El export web requiere WebAssembly + WebGL 2.0; para este proyecto se contempla el renderer Compatibility y despliegue HTTPS con compresión de WASM/PCK.
Fuente oficial: documentación web de Godot 4. C# no se puede exportar actualmente a la web con Godot 4; por eso la ruta principal prevista es GDScript, con C++ sólo cuando una necesidad concreta lo justifique.
15.1 Networking — decisión de arquitectura
No se congela todavía un transporte único para todo. La arquitectura utilizará una interfaz abstracta de transporte y se validarán dos rutas durante el prototipo de networking: WebSocket seguro para control/plano de sesión y WebRTC/DataChannel como candidato para tráfico de juego de baja latencia. Esto evita casar toda la arquitectura con TCP antes de medirlo.
Fuente oficial: documentación de networking de Godot. WebSocket usa TCP; WebRTC permite canales apropiados para comunicación en tiempo real. La arquitectura de Between Worlds mantendrá ambos detrás de una capa de transporte para poder validarlos en prototipo.
15.2 ¿Por qué no Unity como primera opción?
Unity 6 dispone de soporte Web y un paquete oficial de Dedicated Server.
La plataforma Web sigue sujeta a las restricciones de networking propias del navegador; WebGL no dispone de sockets IP directos y el networking web utiliza mecanismos como WebSockets/WebRTC.
Para este proyecto 2D, la simplicidad del stack, el control del servidor headless y el enfoque 2D de Godot encajan mejor con el alcance actual.
Esto no significa que Unity sea incapaz de realizar Between Worlds. Significa que, con nuestras restricciones actuales, Godot presenta un encaje inicial más directo y menos pesado.

## 16. Seguridad y anti-cheat
El cliente nunca adjudica kills, daño, moneda, inventario o victoria.
El servidor valida rate of fire, munición, posiciones plausibles, construcción y pickups.
Las acciones de gameplay tienen límites y validación de tamaño/frecuencia.
Las partidas pueden producir registros de eventos para moderación y debugging.
Las futuras herramientas de reporte, espectador y replay deberán apoyarse en el estado autoritativo del servidor.

## 17. Data-driven content
Armas, armaduras, utilidades, mapas, bloques y reglas de modo se tratarán como definiciones de datos versionadas. El objetivo es poder balancear contenido sin reescribir el núcleo del juego.


## 18. Producción y documentación
### La estructura del proyecto documental queda organizada por niveles:
Visión: qué es Between Worlds.
Game Design: cómo se juega.
Technical Design: cómo se implementa.
Production: cómo se desarrolla, prueba, despliega y mantiene.
NO CODE → DESIGN → TECH SPEC → PROTOTYPE → VERTICAL SLICE → ALPHA → BETA → RELEASE

## 19. Lo que falta para cerrar completamente la Fase 1
La investigación general de Fortoresse ya está suficientemente cerrada para nuestro propósito. Los huecos restantes corresponden a especificación de Between Worlds, no a seguir buscando indefinidamente el código privado de Fortoresse.


## 20. Próxima etapa — la parte interesante
A partir de aquí dejamos de hacer rondas largas de preguntas. Las decisiones pequeñas las asumirá el diseño y quedarán marcadas como “provisionales” cuando deban validarse con pruebas.
La siguiente entrega será el **Prototype Blueprint**: un documento corto y visual que definirá exactamente qué tendría el primer prototipo jugable y cómo mediríamos si el núcleo funciona.
Un mapa de prueba.
Un jugador controlable.
Light/Medium/Heavy.
Una primaria, una secundaria y una utilidad inicial.
100 HP + armadura + headshots.
Construcción en grid.
Destrucción de terreno.
Respawn rápido.
Partida pequeña local/servidor de prueba.
Telemetría mínima para TTK, movimiento y construcción.
El objetivo no será “hacer el juego”. Será comprobar que caminar, saltar, apuntar, disparar, construir, destruir y volver al combate producen la sensación correcta. Si ese núcleo funciona, el resto del proyecto tendrá una base real.

## 21. Fuentes principales de investigación
Atelier 801 — Pro’s guide to M40 A5 / técnicas avanzadas de Fortoresse: https://atelier801.com/topic?f=8&t=772149
Fortoresse Wiki — Armory / weapons: https://fortoresse.fandom.com/wiki/Armory/weapons
Godot 4.7 — CharacterBody2D: https://docs.godotengine.org/en/4.7/tutorials/physics/using_character_body_2d.html
Godot 4.7 — High-level multiplayer: https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html
Godot — Web export: https://docs.godotengine.org/en/4.x/tutorials/export/exporting_for_web.html
Godot — WebRTC: https://docs.godotengine.org/en/latest/tutorials/networking/webrtc.html
Godot — Dedicated servers: https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_dedicated_servers.html
Godot — Release archive: https://godotengine.org/download/archive/
Unity 6 — Web networking: https://docs.unity3d.com/6000.0/Manual/webgl-networking.html
Unity 6 — Dedicated Server: https://docs.unity3d.com/6000.0/Manual/com.unity.dedicated-server.html
Bloxel Arena — current 5v5/destructible positioning: https://play.google.com/store/apps/details?id=com.bloxelarena.prod


## 22. Prototype Blueprint v0.1
Objetivo: crear únicamente el núcleo jugable que permita comprobar si Between Worlds se siente bien antes de invertir en contenido, lore o producción visual definitiva.
22.1 Motor provisional
Godot 4.7.2 stable. La decisión se mantiene provisional hasta completar una prueba de networking Web/PC. La ruta principal de scripting será GDScript; C++ queda reservado para módulos concretos si las mediciones lo justifican.
22.2 Alcance del primer prototipo
Un mapa de prueba; movimiento; cámara; 100 HP; Light/Medium/Heavy; una primaria; una secundaria; una utilidad simple; construcción; destrucción; pickups; respawn rápido; una condición de victoria sencilla. Sin cuentas, tienda, matchmaking público ni lore profundo.
22.3 Primer mapa de laboratorio
Mapa 3200x1800 unidades de diseño, grid de 16 px como baseline de prototipo. Aproximadamente 60% de la geometría mutable/destruible, un esqueleto permanente para rutas y objetivos, y zonas de construcción claramente controladas. El tamaño exacto se ajustará después de probar la cámara y el traversal.
22.4 Player baseline
Medium como referencia. Velocidad horizontal de referencia 240 px/s de diseño; Light 264; Heavy 216. Salto común a las tres armaduras. Estos valores no son finales: sólo sirven para medir el feeling inicial.
22.5 Combat baseline
100 HP; Light 10%, Medium 20%, Heavy 30% de mitigación; headshot global 1.5x; sin one-shot; balas normales sin knockback. Las primeras armas de prueba serán arquetipos, no nombres definitivos.
22.6 Armas de prueba
Rifle: 20 daño, 600 RPM, cargador 30, recarga aproximada 2.1 s. Precision: 60 daño, 100 RPM, cargador 5, recarga aproximada 3.0 s. Secondary: arma de emergencia de menor DPS. Los números se usarán para medir TTK y no son todavía el arsenal final.
22.7 Construcción de prueba
Bloques de 16x16 px. Colocación sólo en celdas válidas. Bloque básico con HP propio, propiedad de equipo y reglas de colisión. Destrucción replicada por servidor. El prototipo medirá cuánto cambia una ruta cuando se construye o destruye cobertura.
22.8 Networking por etapas
Etapa 1: servidor local autoritativo. Etapa 2: LAN. Etapa 3: navegador contra servidor remoto. Etapa 4: comparar WebSocket y WebRTC bajo latencia/pérdida simulada. No se implementará matchmaking público hasta validar la simulación.
22.9 Pruebas de éxito
El prototipo debe permitir: moverse con sensación cercana a Fortoresse; apuntar y disparar sin latencia perceptible local; reconocer headshots; entender Light/Medium/Heavy a simple vista; construir/romper sin desync; morir y volver rápido; y producir una partida pequeña que siga siendo divertida aunque el mapa se transforme.
22.10 Qué NO se hará todavía
No skins, tienda, battle pass, campaña, multitudes de armas, mapas finales, cinemáticas, voz, lore profundo, anti-cheat avanzado, ranking global ni infraestructura comercial. Todo eso viene después de validar el núcleo.

## 23. Estado del proyecto al cerrar esta fase
Investigación general de Fortoresse: cerrada a nivel útil para el proyecto. Los detalles internos privados que no son públicos no se inventarán.
GDD de gameplay: suficientemente definido para pasar a especificación técnica y prototipo.
Baseline de combate: definido para simulación.
Arquitectura: definida conceptualmente; Godot 4.7.2 queda como recomendación provisional.
Siguiente bloque de trabajo: Player Controller + construcción + network prototype specification.
Modo de trabajo: no habrá más cuestionarios pequeños; las decisiones menores se asumirán y se registrarán como provisionales.