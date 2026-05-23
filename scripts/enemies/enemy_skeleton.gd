# Implements a simple melee skeleton that patrols before aggro.
extends "res://scripts/enemies/enemy_basic.gd"
class_name EnemySkeleton

func _ready() -> void:
	if enemy_type_id == StringName() or enemy_type_id == &"enemy_basic":
		enemy_type_id = &"skeleton"
	super._ready()
