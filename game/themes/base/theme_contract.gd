class_name ThemeContract
extends RefCounted
## Minimum generic theme contract — OWNER: AGENT-1 (game/themes/base/**).
##
## Ownership (recorded decision, 2026-09-26):
## - game/themes/base/**      → AGENT-1 (generic contracts, theme-agnostic)
## - a concrete theme package → AGENT-2 (theme implementation)
## Cross-boundary changes require coordination (docs/AGENT_RULES.md).
##
## A theme may supply: presentation mappings, terminology/localization key
## stems, palette (color key → color + symbol), asset bundle references,
## animation/audio/particle set ids, iconography ids.
## A theme may NEVER: change simulation rules, entity states, command
## validation, matching semantics, capacity/staging rules or level data.
## Simulation/core code must never import a theme.
##
## M1 defines the smallest useful contract (manifest validation + slot names +
## ColorKey format). Richer manifest loading belongs to the milestone that
## consumes it (M2 presentation); this file must stay generic.

const MANIFEST_VERSION := 1

## Required manifest keys (blueprint §39).
const REQUIRED_MANIFEST_KEYS: Array[String] = [
	"themeId",
	"themeVersion",
	"entityPresentation",
	"itemPresentation",
	"destinationPresentation",
	"assetBundleVersion",
]

## Presentation slots a theme binds by name (never by file path).
const PRESENTATION_SLOTS: Array[String] = [
	"entity.body",
	"item.token",
	"destination.badge",
	"staging.slot",
	"fx.match",
]

## Stable color keys look like COLOR_A, COLOR_B, COLOR_12 — never literal
## render colors (blueprint §14).
const COLOR_KEY_PREFIX := "COLOR_"


static func is_known_slot(slot: String) -> bool:
	return PRESENTATION_SLOTS.has(slot)


static func is_valid_color_key(color_key: StringName) -> bool:
	var text := String(color_key)
	if not text.begins_with(COLOR_KEY_PREFIX):
		return false
	var suffix := text.substr(COLOR_KEY_PREFIX.length())
	if suffix.is_empty():
		return false
	for index in suffix.length():
		var character := suffix[index]
		var is_digit := character >= "0" and character <= "9"
		var is_upper := character >= "A" and character <= "Z"
		if not is_digit and not is_upper and character != "_":
			return false
	return true


## Validates a theme manifest dictionary; empty result means valid.
static func validate_manifest(manifest: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(manifest) != TYPE_DICTIONARY:
		errors.append("manifest_not_a_dictionary")
		return errors
	for key in REQUIRED_MANIFEST_KEYS:
		if not manifest.has(key):
			errors.append("missing_manifest_key:%s" % key)
	if errors.is_empty():
		if str(manifest["themeId"]).is_empty():
			errors.append("empty_theme_id")
		if int(manifest["themeVersion"]) < 1:
			errors.append("invalid_theme_version")
		if int(manifest["assetBundleVersion"]) < 1:
			errors.append("invalid_asset_bundle_version")
		for key in ["entityPresentation", "itemPresentation", "destinationPresentation"]:
			if str(manifest[key]).is_empty():
				errors.append("empty_presentation_stem:%s" % key)
	return errors
