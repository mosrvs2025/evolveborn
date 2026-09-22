extends RefCounted
class_name Palette
## Shared colours. Regions read their mood from here so the five areas feel like
## one world lit differently rather than five unrelated scenes.

const UI_BG := Color(0.043, 0.055, 0.078, 0.92)
const UI_PANEL := Color(0.078, 0.098, 0.133, 0.95)
const UI_LINE := Color(0.35, 0.55, 0.68, 0.55)
const UI_TEXT := Color(0.86, 0.93, 0.98)
const UI_DIM := Color(0.55, 0.64, 0.72)
const UI_ACCENT := Color(0.45, 0.92, 0.85)
const UI_WARN := Color(1.0, 0.62, 0.35)
const UI_BAD := Color(1.0, 0.38, 0.42)
const UI_GOOD := Color(0.55, 0.95, 0.6)

const HEALTH := Color(0.95, 0.35, 0.42)
const ESSENCE := Color(0.55, 0.9, 1.0)
const CORE := Color(0.5, 0.95, 0.9)

const STATUS := {
	"poison": Color(0.55, 0.95, 0.4),
	"burn": Color(1.0, 0.55, 0.2),
	"shock": Color(0.62, 0.88, 1.0),
	"root": Color(0.92, 0.95, 0.85),
	"mark": Color(0.72, 0.55, 1.0),
}

## Also carried as a glyph, so status is never colour-only.
const STATUS_GLYPH := {
	"poison": "☣", "burn": "▲", "shock": "⚡", "root": "✳", "mark": "◈",
}

const REGIONS := {
	"awakening_cavern": {
		"fog": Color(0.035, 0.05, 0.085), "ambient": Color(0.30, 0.40, 0.58),
		"key": Color(0.60, 0.76, 1.0), "ground": Color(0.42, 0.45, 0.55),
		"ground_alt": Color(0.27, 0.31, 0.42), "accent": Color(0.4, 0.75, 1.0),
		"fog_density": 0.016,
	},
	"fungal_grotto": {
		"fog": Color(0.035, 0.075, 0.07), "ambient": Color(0.28, 0.48, 0.40),
		"key": Color(0.5, 1.0, 0.75), "ground": Color(0.34, 0.46, 0.38),
		"ground_alt": Color(0.22, 0.33, 0.30), "accent": Color(0.55, 1.0, 0.6),
		"fog_density": 0.022,
	},
	"sunken_ruins": {
		"fog": Color(0.05, 0.055, 0.085), "ambient": Color(0.38, 0.38, 0.50),
		"key": Color(0.85, 0.82, 1.0), "ground": Color(0.48, 0.48, 0.52),
		"ground_alt": Color(0.33, 0.34, 0.40), "accent": Color(0.75, 0.7, 1.0),
		"fog_density": 0.016,
	},
	"verdant_basin": {
		"fog": Color(0.10, 0.15, 0.16), "ambient": Color(0.34, 0.42, 0.40),
		"key": Color(1.0, 0.95, 0.80), "ground": Color(0.34, 0.50, 0.30),
		"ground_alt": Color(0.44, 0.58, 0.34), "accent": Color(0.95, 0.9, 0.5),
		"fog_density": 0.010,
	},
	"ancient_nest": {
		"fog": Color(0.07, 0.03, 0.06), "ambient": Color(0.40, 0.26, 0.36),
		"key": Color(1.0, 0.55, 0.65), "ground": Color(0.44, 0.32, 0.34),
		"ground_alt": Color(0.31, 0.21, 0.27), "accent": Color(0.95, 0.4, 0.55),
		"fog_density": 0.020,
	},
	"horizon": {
		"fog": Color(0.42, 0.52, 0.68), "ambient": Color(0.55, 0.60, 0.70),
		"key": Color(1.0, 0.88, 0.72), "ground": Color(0.32, 0.36, 0.30),
		"ground_alt": Color(0.40, 0.42, 0.34), "accent": Color(1.0, 0.85, 0.6),
		"fog_density": 0.004,
	},
}

static func region(id: String) -> Dictionary:
	return REGIONS.get(id, REGIONS["awakening_cavern"])
