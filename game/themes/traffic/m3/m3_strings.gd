extends RefCounted
## TEMPORARY M3 presentation text catalog (English).
##
## The localization runtime (blueprint §58) is not implemented yet. Until it is,
## every M3 shell string is resolved here by key, so no user-facing text is
## hardcoded inside screens and the swap to the real localization system is a
## single seam. Replace this catalog at/after M3 cross-integration.
##
## Keys mirror the documented localization key space (`ui.*`, `level.*`).

const _EN := {
	&"ui.project_title": "Project Traffic",
	&"ui.play": "PLAY",
	&"ui.level_select": "LEVEL SELECT",
	&"ui.select_level": "Select Level",
	&"ui.restart": "Restart",
	&"ui.menu": "Menu",
	&"ui.next": "NEXT",
	&"ui.retry": "RETRY",
	&"ui.level": "Level",
	&"ui.level_n": "Level %d",
	&"ui.level_of": "Level %d / %d",
	&"ui.level_complete": "LEVEL COMPLETE",
	&"ui.all_n_levels_complete": "ALL %d LEVELS COMPLETE",
	&"ui.try_again": "TRY AGAIN",
	&"level.fail.staging_full": "The holding area filled up.",
	&"level.fail.no_moves": "No more valid moves.",
	&"level.fail.move_limit": "You ran out of moves.",
	&"level.fail.time_limit": "Time ran out.",
	&"level.fail.special": "A special objective failed.",
	&"level.fail.unknown": "The level could not be completed.",
}


static func has_text(key: StringName) -> bool:
	return _EN.has(key)


## Returns the display text for `key`, or the key itself when unknown (never an
## empty string, so the UI stays debuggable without inventing copy).
static func text(key: StringName) -> String:
	return str(_EN.get(key, key))


static func format_text(key: StringName, args: Array) -> String:
	var template := text(key)
	if args.is_empty():
		return template
	return template % args
