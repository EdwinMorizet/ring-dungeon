extends Node3D
class_name FireballAoeBurst

const DEFAULT_DURATION_SECONDS: float = 0.22
const LESSER_ALPHA: float = 0.35
const GREATER_ALPHA: float = 0.5

@onready var _sphere_mesh: MeshInstance3D = $Sphere
@onready var _particles: GPUParticles3D = $BurstParticles

var _duration_seconds: float = DEFAULT_DURATION_SECONDS

func play(aoe_radius: float, is_lesser: bool) -> void:
	var clamped_radius: float = max(aoe_radius, 0.05)
	_duration_seconds = DEFAULT_DURATION_SECONDS if is_lesser else DEFAULT_DURATION_SECONDS * 1.2

	if _sphere_mesh != null:
		_sphere_mesh.scale = Vector3.ONE * 0.02
		var sphere_material: StandardMaterial3D = _sphere_mesh.get_active_material(0) as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = LESSER_ALPHA if is_lesser else GREATER_ALPHA

	if _particles != null:
		_particles.amount = maxi(int(roundf(clamped_radius * 42.0)), 12)
		var process_material: ParticleProcessMaterial = _particles.process_material as ParticleProcessMaterial
		if process_material != null:
			var spread_angle: float = clampf(clamped_radius * 22.0, 20.0, 75.0)
			process_material.spread = spread_angle
		_particles.restart()
		_particles.emitting = true

	if _sphere_mesh == null:
		queue_free()
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sphere_mesh, "scale", Vector3.ONE * clamped_radius, _duration_seconds)
	tween.tween_property(_sphere_mesh, "transparency", 1.0, _duration_seconds)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
