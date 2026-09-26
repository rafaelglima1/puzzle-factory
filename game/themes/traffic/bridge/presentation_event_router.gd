extends RefCounted
## Thin presentation adapter boundary for future simulation events (M1/M2).
##
## Intentionally NOT an enum: AGENT-1 has not published the K1 presentation
## bridge contract yet, so event names are data (`PROVISIONAL_EVENTS`), taken
## from docs/UX_IMPLEMENTATION_PLAN.md §2.2. When the real contract lands, the
## router keeps working unchanged (subscribe/dispatch) and only the producer
## side is re-pointed. Unknown events are ignored safely, never crash.

signal event_forwarded(event_name: StringName, payload: Dictionary)

## Proposed generic event names. NOT a locked contract — see heading above.
const PROVISIONAL_EVENTS: Array[StringName] = [
	&"EntitySelected",
	&"EntityBlocked",
	&"EntityMoveStarted",
	&"EntityArrived",
	&"EntityExited",
	&"ItemQueued",
	&"ItemLoaded",
	&"MatchOccurred",
	&"StagingReceived",
	&"StagingPressureChanged",
	&"ObjectiveProgress",
	&"ObjectiveCompleted",
	&"ComboIncreased",
	&"ScoreChanged",
	&"LevelCompleted",
	&"LevelFailed",
	&"BoosterApplied",
	&"UndoApplied",
]

var forwarded_count := 0
var ignored_count := 0

var _subscribers: Dictionary = {}


func subscribe(event_name: StringName, callback: Callable) -> bool:
	if not callback.is_valid():
		return false
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	var callbacks: Array = _subscribers[event_name]
	if callbacks.has(callback):
		return false
	callbacks.append(callback)
	return true


func unsubscribe(event_name: StringName, callback: Callable) -> bool:
	if not _subscribers.has(event_name):
		return false
	var callbacks: Array = _subscribers[event_name]
	var index := callbacks.find(callback)
	if index < 0:
		return false
	callbacks.remove_at(index)
	if callbacks.is_empty():
		_subscribers.erase(event_name)
	return true


func subscriber_count(event_name: StringName = &"") -> int:
	if event_name == &"":
		var total := 0
		for callbacks: Array in _subscribers.values():
			total += callbacks.size()
		return total
	if not _subscribers.has(event_name):
		return 0
	return _subscribers[event_name].size()


## Returns how many subscribers received the event.
func dispatch(event_name: StringName, payload: Dictionary = {}) -> int:
	if not _subscribers.has(event_name):
		ignored_count += 1
		return 0
	var delivered := 0
	var callbacks: Array = _subscribers[event_name]
	for callback: Callable in callbacks:
		if callback.is_valid():
			callback.call(event_name, payload)
			delivered += 1
	forwarded_count += 1
	event_forwarded.emit(event_name, payload)
	return delivered
