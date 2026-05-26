# Stores progression pools used to select floor configs by run progression.
extends Resource
class_name FloorDifficultyTable

# Ordered progression pools used to resolve floor config by run index.
@export var pools: Array[FloorConfigPoolEntry] = []
