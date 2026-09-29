class_name GameConstants
## Between Worlds — valores de reglas de juego (provisionales del primer prototipo).
## Los valores marcados como provisionales se validarán con el prototipo de balance.

# Jugador / combate
const MAX_HP := 100.0
const MAX_SHIELD := 50.0  # provisional Punto 1: escudo temporal separado, máx 50 para no duplicar TTK
const HEADSHOT_MULTIPLIER := 1.5
const BODY_MULTIPLIER := 1.0
const RESPAWN_DELAY := 3.0
const STARTING_LIVES := 3

# Armadura: velocidad horizontal base (Medium = referencia)
const BASE_RUN_SPEED := 240.0
const CROUCH_SPEED_FACTOR := 0.6  # provisional
const CROUCH_ACCEL_FACTOR := 0.5  # provisional

# Movimiento (provisionales, para calibrar el feeling)
const GROUND_ACCEL := 1500.0
const AIR_ACCEL := 1200.0
const GROUND_FRICTION := 1800.0
const MAX_FALL_SPEED := 900.0
const JUMP_VELOCITY := -360.0

# Mundo / construcción
const GRID_SIZE := 16
const MAP_W_CELLS := 200
const MAP_H_CELLS := 112
const BUILD_RANGE_CELLS := 4       # radio de construcción en celdas
const BUILD_RANGE_PX := BUILD_RANGE_CELLS * GRID_SIZE

# Pickups (% sobre el máximo de cada recurso, rango objetivo 25-40%)
const PICKUP_HEALTH_FRACTION := 0.30
const PICKUP_ARMOR_FRACTION := 0.30   # provisional: escudo temporal separado de la armadura base
const PICKUP_AMMO_FRACTION := 0.40
const PICKUP_MAX_AMMO_PERCENT := 1.00  # el pickup nunca supera el máximo normal

# Bloques de construcción
const BUILD_BLOCK_HP := 200.0
const MAP_DESTRUCTIBLE_HP := 100.0
const MAP_TARGET_HP := 120.0

# Equipos / modos (Punto 2, provisional)
const TEAM_SIZE := 5  # 5v5
const TEAM_COUNT := 2  # equipos 0 y 1
const MATCH_DURATION := 600.0  # 10 min, dentro del estándar 8-12 min
const VIP_EXTRA_HP := 0.0  # provisional: el VIP no recibe HP extra
const DOMINATION_ZONES := 3  # provisional: 3 zonas (izq/centro/der)
const DOMINATION_SCORE_PER_TICK := 1  # punto por tick de control
const DOMINATION_TICK_SECONDS := 1.0  # tick cada segundo
const DOMINATION_WIN_SCORE := 100  # provisional: primero a 100 gana

# Máscaras de colisión (bit, layer)
const LAYER_WORLD := 1 << 0
const LAYER_PLAYER := 1 << 1
const LAYER_PICKUP := 1 << 2
const LAYER_GRAVE := 1 << 3  # zona de muerte (reserva)