class_name Layers
extends RefCounted
## Physics and render layer masks used across the app.

# --- Physics layers (names set in Project Settings) ---
const GROUND := 1 << 0  # layer 1
const PROPS := 1 << 1   # layer 2
const GIZMOS := 1 << 2  # layer 3: virtual-camera handles (clickable, never a surface)

## What the placement ray is allowed to land on.
const PLACEMENT_MASK := GROUND | PROPS
## What a selection click can pick.
const SELECTABLE := PROPS | GIZMOS

# --- Render (visual) layers ---
## Visual layer 20: editor-only visuals (grid, ghost, camera gizmos, selection
## brackets). Visible to the editor camera, never in previews or exported video.
const EDITOR_ONLY_VISUAL := 1 << 19
const ALL_VISUAL := (1 << 20) - 1
const FINAL_RENDER_MASK := ALL_VISUAL & ~EDITOR_ONLY_VISUAL
