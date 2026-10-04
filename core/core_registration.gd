class_name CoreRegistration
extends RefCounted
## LOAD_CORE phase: registers the code-backed types of the base game. Data
## content (blocks, items, biomes...) is NOT registered here; it comes from
## the base content pack (res://packs/blockyworld) exactly like a mod.


static func register_code_types(registries: ContentRegistries) -> void:
	var components := registries.components
	components.register_type("blockyworld:movement", MovementComponent, "Walk/fly locomotion driven by MovementIntent")
	components.register_type("blockyworld:health", HealthComponent, "Health bounded by blockyworld:max_health")
	components.register_type("blockyworld:wander", WanderComponent, "Idle/walk random wandering AI")

	var generators := registries.generators
	generators.register_type("blockyworld:default", preload("res://world/generators/terrain_generator.gd"), "Biome terrain with caves and trees")
	generators.register_type("blockyworld:lab", preload("res://world/generators/lab_generator.gd"), "Blocky Lab flat test world")

	var features := registries.features
	features.register_type("blockyworld:tree", preload("res://world/generators/features/tree_feature.gd"), "Trunk with leaf crown")
	features.register_type("blockyworld:column", preload("res://world/generators/features/column_feature.gd"), "Vertical column (cactus)")
