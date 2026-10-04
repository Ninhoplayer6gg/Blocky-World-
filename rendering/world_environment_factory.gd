class_name WorldEnvironmentFactory
extends RefCounted
## Sky, ambient light, sun and distance fog for a world. Fog starts near the
## render distance so chunk loading at the horizon is not distracting.


static func create(render_distance: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Environment"
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.33, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.68, 0.8, 0.92)
	sky_material.ground_horizon_color = Color(0.68, 0.8, 0.92)
	sky_material.ground_bottom_color = Color(0.3, 0.35, 0.4)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.68, 0.8, 0.92)
	environment.fog_density = 0.0
	environment.fog_sky_affect = 0.0
	update_fog(environment, render_distance)
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = false
	root.add_child(sun)
	return root


static func update_fog(environment: Environment, render_distance: int) -> void:
	var far := float(render_distance * GameConfig.CHUNK_SIZE_X)
	# Depth fog (Godot 4.3+ fog_mode) where available; density fallback otherwise.
	if "fog_mode" in environment:
		environment.set("fog_mode", 1)
		environment.set("fog_depth_begin", far * 0.6)
		environment.set("fog_depth_end", far)
	else:
		environment.fog_density = 2.0 / maxf(far, 1.0)
