class_name SceneClock
extends RefCounted
## Scene time for scripts (lights flickering, effects): timeline time while
## playing or exporting, plus a free-running clock while editing. Shaders read
## the same value from the global shader parameter "scene_time".

static var now := 0.0
