# Plays a brief beam-like tracer so skeleton archer shots read clearly in gameplay.
extends Node3D
class_name SkeletonArcherShotVfx

@export var life_time: float = 0.12
@export var beam_width: float = 0.08
@export var impact_scale: float = 0.18

@onready var _beam: MeshInstance3D = $Beam
@onready var _impact_flash: MeshInstance3D = $ImpactFlash

func play(origin: Vector3, hit_position: Vector3) -> void:
	var shot_vector: Vector3 = hit_position - origin
	var shot_length: float = shot_vector.length()
	if shot_length <= 0.01:
		queue_free()
		return
	global_position = origin.lerp(hit_position, 0.5)
	look_at(hit_position, Vector3.UP)
	if _beam != null:
		var beam_mesh: BoxMesh = _beam.mesh as BoxMesh
		if beam_mesh != null:
			beam_mesh.size = Vector3(beam_width, beam_width, shot_length)
		_beam.transparency = 0.0
	if _impact_flash != null:
		_impact_flash.global_position = hit_position
		_impact_flash.scale = Vector3.ONE * impact_scale
		_impact_flash.transparency = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if _beam != null:
		tween.tween_property(_beam, "transparency", 1.0, life_time)
	if _impact_flash != null:
		tween.tween_property(_impact_flash, "scale", Vector3.ONE * (impact_scale * 2.2), life_time)
		tween.tween_property(_impact_flash, "transparency", 1.0, life_time)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
