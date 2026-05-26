extends Node3D


func _ready() -> void:
	scale = Vector3(0,0,0)
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.08)
	tween.play()
