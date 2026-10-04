class_name GameConfig
extends RefCounted
## Engine-wide tunables. Anything that would otherwise be a magic number shared
## between systems lives here.

# --- Voxel layout -----------------------------------------------------------
## Horizontal chunk size in blocks.
const CHUNK_SIZE_X := 16
const CHUNK_SIZE_Z := 16
## World height in blocks. Chunks are full-height columns.
const CHUNK_SIZE_Y := 128
## Columns are split vertically into sections for meshing: editing a block only
## remeshes one section (plus neighbours on borders) and empty sections are
## skipped entirely. Must divide CHUNK_SIZE_Y.
const SECTION_HEIGHT := 16
const SECTION_COUNT := 8
const CHUNK_LAYER := CHUNK_SIZE_X * CHUNK_SIZE_Z
const CHUNK_VOLUME := CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z

# --- Streaming --------------------------------------------------------------
const DEFAULT_RENDER_DISTANCE := 6
const MOBILE_RENDER_DISTANCE := 4
const RENDER_DISTANCE_OPTIONS: Array[int] = [2, 4, 6, 8, 10, 12]
## Chunks within render distance + 1 hold block data (needed to cull and shade
## the outer ring of meshes). Chunks further than this + UNLOAD_MARGIN unload.
const UNLOAD_MARGIN := 1
## Upper bound for simultaneous background chunk jobs.
const MAX_CHUNK_JOBS := 6
## Main-thread time budget per frame for integrating finished chunk work.
const MAIN_THREAD_BUDGET_USEC := 4000

# --- World ------------------------------------------------------------------
## Seed used when the player leaves the seed field empty is random; this one is
## used by Blocky Lab and tests so results are reproducible.
const DEFAULT_WORLD_SEED := 1337
const AUTOSAVE_INTERVAL_SEC := 60.0
const DEFAULT_GENERATOR := "blockyworld:default"
const LAB_GENERATOR := "blockyworld:lab"
const LAB_WORLD_NAME := "Blocky Lab"

# --- Rendering --------------------------------------------------------------
## Fallback texture size for generated placeholder textures. Real textures may
## be larger; the block texture array uses the largest size found.
const BLOCK_TEXTURE_SIZE := 16
const ENABLE_AMBIENT_OCCLUSION := true

# --- Interaction ------------------------------------------------------------
const REACH_DISTANCE := 6.0
const BREAK_SECONDS_PER_HARDNESS := 0.3
const PLACE_REPEAT_SECONDS := 0.22

# --- Physics layers ---------------------------------------------------------
const LAYER_WORLD := 1
const LAYER_ENTITIES := 2
