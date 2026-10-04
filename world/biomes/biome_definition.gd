class_name BiomeDefinition
extends RefCounted
## Climate-placed terrain style. The default generator picks the biome whose
## (temperature, humidity) point is closest to the local climate and blends
## terrain height between neighbouring biomes.

var id: String = ""
var display_name: String = ""
## Climate point in 0..1.
var temperature: float = 0.5
var humidity: float = 0.5
var surface_block: String = "blockyworld:grass"
var subsurface_block: String = "blockyworld:dirt"
var subsurface_depth: int = 3
var stone_block: String = "blockyworld:stone"
## Added to the base terrain height (blocks).
var height_offset: float = 0.0
## Multiplier for terrain noise amplitude.
var height_variation: float = 1.0
## [{type: feature id, chance: float, ...feature params}]
var features: Array = []
var source_mod: String = ""
