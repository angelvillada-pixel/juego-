class_name Pickup
extends Area2D
## Pickup de laboratorio: Health / Armor(escudo temporal) / Ammo.
## Aplicado por PickupService (clamp a máximos, nunca supera el máximo).

var pickup_id := PickupData.PICKUP_HEALTH

signal consumed(pickup_id: String)


func setup(p_pickup_id: String) -> void:
	pickup_id = p_pickup_id
	queue_redraw()


func _ready() -> void:
	if pickup_id.is_empty():
		setup(PickupData.PICKUP_HEALTH)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	# Path relativa a nuestro TestMap (sendor/cliente comparten el nombre determinista).
	var map := _find_map_ancestor()
	if map == null:
		return
	Client.send({"type": NetMsg.PICKUP_CLAIM, "path": str(map.get_path_to(self))})


func _find_map_ancestor() -> Node:
	var current := get_parent()
	while current != null:
		if current is TestMap:
			return current
		current = current.get_parent()
	return null

func _draw() -> void:
	var def := PickupData.get_def(pickup_id)
	var col: Color = def["color"]
	draw_rect(Rect2(-8, -8, 16, 16), col.darkened(0.3))
	draw_rect(Rect2(-8, -8, 16, 16), Color(1, 1, 1, 0.5), false, 1.0)
	match pickup_id:
		PickupData.PICKUP_HEALTH:
			draw_rect(Rect2(-3, -6, 6, 12), Color.WHITE)
			draw_rect(Rect2(-6, -3, 12, 6), Color.WHITE)
		PickupData.PICKUP_ARMOR:
			draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.9))
		PickupData.PICKUP_AMMO:
			draw_rect(Rect2(-5, -4, 10, 8), Color.WHITE)
			draw_rect(Rect2(-6, -6, 12, 3), Color.WHITE)