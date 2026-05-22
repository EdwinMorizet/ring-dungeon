# Draws the center crosshair used by the first-person HUD.
extends Control
class_name HudCrosshair

@export var radius: float = 7.0
@export var thickness: float = 2.0
@export var line_color: Color = Color(1.0, 1.0, 1.0, 1.0)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_arc(center, radius, 0.0, TAU, 48, line_color, thickness, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
