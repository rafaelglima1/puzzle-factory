extends RefCounted
## Cosmetic interaction lock for presentation transitions (blueprint §32, §5.5).
##
## Rules enforced here so no caller can create an indefinite lock:
## - every request is CLAMPED to `max_lock`;
## - locks are owned by a StringName owner + reason (traceable);
## - `tick(delta)` decrements and AUTO-RELEASES at zero (failsafe);
## - release()/release_all() allow explicit early release.
##
## The simulation never sees this gate: it is presentation-only and can never
## decide puzzle correctness (ADR-003).

signal lock_changed(locked: bool)

const DEFAULT_MAX_LOCK := 0.6

var max_lock := DEFAULT_MAX_LOCK

var _locks: Dictionary = {}
var _locked := false


func set_max_lock(seconds: float) -> void:
	max_lock = maxf(seconds, 0.0)
	_reevaluate()


## Requests a lock and returns the granted duration (clamped to `max_lock`).
func request(owner: StringName, reason: StringName, duration: float) -> float:
	var granted := clampf(duration, 0.0, max_lock)
	_locks[owner] = {"reason": reason, "remaining": granted, "requested": duration}
	_reevaluate()
	return granted


func release(owner: StringName) -> void:
	if _locks.erase(owner):
		_reevaluate()


func release_all() -> void:
	if _locks.is_empty():
		return
	_locks.clear()
	_reevaluate()


## Advances every lock. Call from `_process` at runtime, or directly in tests.
func tick(delta: float) -> void:
	if _locks.is_empty():
		return
	var expired: Array = []
	for owner: StringName in _locks.keys():
		var entry: Dictionary = _locks[owner]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			expired.append(owner)
	for owner: StringName in expired:
		_locks.erase(owner)
	_reevaluate()


func update(delta: float) -> void:
	tick(delta)


func is_locked() -> bool:
	return _locked


func lock_count() -> int:
	return _locks.size()


func remaining() -> float:
	var longest := 0.0
	for entry: Dictionary in _locks.values():
		longest = maxf(longest, float(entry["remaining"]))
	return longest


func owner_reason(owner: StringName) -> StringName:
	if _locks.has(owner):
		return _locks[owner]["reason"]
	return &""


func active_locks() -> Array:
	return _locks.keys()


func _reevaluate() -> void:
	var now_locked := not _locks.is_empty()
	if now_locked != _locked:
		_locked = now_locked
		lock_changed.emit(_locked)
