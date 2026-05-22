extends Area3D
class_name CurrencyPickup

enum CurrencyKind {
	GOLD,
	GEMS,
}

@export var currency_kind: CurrencyKind = CurrencyKind.GOLD
@export var amount: int = 1
@export var pickup_radius: float = 0.25

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

var _is_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_collision_shape()
	_refresh_visuals()

func configure(next_currency_kind: int, next_amount: int) -> void:
	if next_currency_kind == int(CurrencyKind.GEMS):
		currency_kind = CurrencyKind.GEMS
	else:
		currency_kind = CurrencyKind.GOLD
	amount = maxi(next_amount, 1)
	_refresh_visuals()

func _refresh_collision_shape() -> void:
	if _collision_shape == null:
		return
	if not _collision_shape.shape is SphereShape3D:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = maxf(pickup_radius, 0.05)
		_collision_shape.shape = sphere
		return
	var current_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
	current_shape.radius = maxf(pickup_radius, 0.05)

func _refresh_visuals() -> void:
	if _mesh_instance == null:
		return
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	_mesh_instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission_energy_multiplier = 1.1
	if currency_kind == CurrencyKind.GEMS:
		material.albedo_color = Color(0.2, 0.95, 0.85, 1.0)
		material.emission = Color(0.1, 0.8, 0.75, 1.0)
	else:
		material.albedo_color = Color(0.98, 0.82, 0.18, 1.0)
		material.emission = Color(0.8, 0.6, 0.12, 1.0)
	_mesh_instance.set_surface_override_material(0, material)

func _on_body_entered(body: Node) -> void:
	if _is_collected:
		return
	if body == null or not body.is_in_group("player"):
		return
	if not has_node("/root/InventoryManager"):
		return
	var collected_amount: int = 0
	if currency_kind == CurrencyKind.GEMS:
		collected_amount = InventoryManager.add_player_gems(amount)
	else:
		collected_amount = InventoryManager.add_player_gold(amount)
	if collected_amount <= 0:
		return
	_is_collected = true
	queue_free()
