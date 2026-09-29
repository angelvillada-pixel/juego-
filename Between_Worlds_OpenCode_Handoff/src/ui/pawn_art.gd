class_name PawnArt
## Dibujo procedural de peones (Punto 4, provisional hasta el pixel-art final).
## - Las tres armaduras son distinguibles por SILUETA, no solo por color:
##   Light = esbelto + antena, Medium = hombrera, Heavy = placa ancha + visor doble.
## - El equipo se lee en el trim lateral (color de facción).
## Se llama dentro del `_draw()` del CanvasItem (usa sus draw_*).


static func draw_pawn(ci: CanvasItem, w: float, h: float, armor_id: String, team_id: int, crouching: bool) -> void:
	var armor_col: Color = ArmorData.get_def(armor_id)["color"]
	var hh := h * 0.6 if crouching else h
	# Cuerpo base.
	ci.draw_rect(Rect2(-w * 0.5, -hh, w, hh), armor_col)
	# Visor (franja clara arriba).
	ci.draw_rect(Rect2(-w * 0.5, -hh, w, 8.0), Color(1, 1, 1, 0.25))
	match armor_id:
		ArmorData.ARMOR_LIGHT:
			# Antena fina.
			ci.draw_line(Vector2(w * 0.25, -hh), Vector2(w * 0.35, -hh - 6.0), Color(0, 0, 0, 0.7), 1.0)
			ci.draw_circle(Vector2(w * 0.35, -hh - 6.0), 1.2, Color(1, 1, 1, 0.9))
		ArmorData.ARMOR_MEDIUM:
			# Hombrera.
			ci.draw_rect(Rect2(-w * 0.5 - 2.0, -hh, 4.0, 7.0), armor_col.darkened(0.3))
		_:
			# Heavy: placa ancha + visor doble.
			ci.draw_rect(Rect2(-w * 0.5 - 2.5, -hh + 2.0, w + 5.0, hh - 2.0), armor_col.darkened(0.25))
			ci.draw_rect(Rect2(-w * 0.5, -hh + 3.0, w, 2.5), Color(1, 0.2, 0.2, 0.9))
	# Sombra inferior.
	ci.draw_rect(Rect2(-w * 0.5, -2.0, w, 2.0), Color(0, 0, 0, 0.6))
	# Trim de equipo (facción) en el lateral izquierdo.
	var edge: Color = FactionData.team_color(team_id)
	ci.draw_rect(Rect2(-w * 0.5, -hh, 2.5, hh), edge)
