extends RefCounted
## Traffic theme package (AGENT-2-owned concrete theme).
##
## Binds the generic `ThemeContract` (game/themes/base/**, AGENT-1-owned) to
## Traffic presentation: palette (ColorKey -> color + symbol), presentation
## stems and terminology. This file consumes the base contract; it never
## modifies it and never imports core/puzzle.

const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")

const THEME_ID := "traffic"
const THEME_VERSION := 1
const ASSET_BUNDLE_VERSION := 1

## Manifest shape required by ThemeContract (blueprint §39).
const MANIFEST := {
	"themeId": THEME_ID,
	"themeVersion": THEME_VERSION,
	"entityPresentation": "vehicle",
	"itemPresentation": "passenger",
	"destinationPresentation": "station",
	"assetBundleVersion": ASSET_BUNDLE_VERSION,
}

## Logical direction name -> presentation rotation in degrees (cardinal).
const DIRECTION_DEGREES := {
	&"north": 0.0,
	&"east": 90.0,
	&"south": 180.0,
	&"west": 270.0,
}


func theme_id() -> StringName:
	return StringName(THEME_ID)


func manifest() -> Dictionary:
	return MANIFEST.duplicate(true)


func palette() -> PaletteScript:
	return PaletteScript.new()


## Empty result means the manifest satisfies the generic contract.
func validation_errors() -> PackedStringArray:
	return ThemeContract.validate_manifest(MANIFEST)


## Traffic binds every generic presentation slot by name (never by file path).
func supports_all_slots() -> bool:
	for slot: String in ThemeContract.PRESENTATION_SLOTS:
		if not ThemeContract.is_known_slot(slot):
			return false
	return true


func accepts_color_key(color_key: StringName) -> bool:
	return ThemeContract.is_valid_color_key(color_key)


func direction_degrees(direction_name: StringName) -> float:
	return float(DIRECTION_DEGREES.get(direction_name, 0.0))
