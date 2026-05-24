# Stores tunable projectile and damage parameters for fireball behavior.
extends Resource
class_name FireballConfig

# Projectile travel speed in world units per second.
@export var speed: float = 30.0
# Gravity multiplier applied to projectile arc simulation.
@export var gravity_influence: float = 0.2
# Probability (0.0–1.0) that a wall hit triggers a bounce; halved on the projectile after each trigger.
@export var bounce_chance: float = 0.0
# Probability (0.0–1.0) that an enemy hit triggers a pierce; halved on the projectile after each trigger.
@export var pierce_chance: float = 0.0
# Number of extra split projectiles emitted per cast.
@export var split_count: int = 0
# Base area-of-effect radius used by explosion handling.
@export var aoe: float = 2.5
# Base hit damage before equipment multipliers are applied.
@export var damage: int = 20
# Visual/physics size scalar used by projectile scene.
@export var size: float = 0.45
# Accuracy spread in degrees used for random shot deviation.
@export var accuracy: float = 0.75
# Mana consumed for one cast before equipment modifiers.
@export var mana_cost: float = 20.0
# Cooldown delay in seconds between casts.
@export var cast_delay_seconds: float = 0.45
