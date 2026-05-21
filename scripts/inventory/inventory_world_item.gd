extends Node3D
class_name InventoryWorldItem

const _BAND_COLOR: Color = Color(0.22, 0.78, 0.92, 1.0)
const _RING_COLOR: Color = Color(0.98, 0.78, 0.18, 1.0)
const _DEFAULT_COLOR: Color = Color(0.75, 0.75, 0.8, 1.0)
const RingBandConstantsScript = preload("res://scripts/inventory/ring_band_constants.gd")

@export var item_definition: InventoryItemDefinition

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	_refresh_visuals()

func configure(definition: InventoryItemDefinition) -> void:
	item_definition = definition
	_refresh_visuals()

func _refresh_visuals() -> void:
	if _mesh_instance == null:
		return
	_mesh_instance.scale = Vector3.ONE * 0.35
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _DEFAULT_COLOR
	material.emission_enabled = true
	material.emission_energy_multiplier = 1.6
	if item_definition != null:
		var rarity_color: Color = RingBandConstantsScript.get_rarity_color(item_definition.rarity)
		if item_definition.is_ring():
			material.albedo_color = _RING_COLOR.lerp(rarity_color, 0.45)
			material.emission = rarity_color
		else:
			material.albedo_color = _BAND_COLOR.lerp(rarity_color, 0.45)
			material.emission = rarity_color
	else:
		material.emission = _DEFAULT_COLOR
	_mesh_instance.set_surface_override_material(0, material)
