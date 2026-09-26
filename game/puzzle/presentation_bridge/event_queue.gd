class_name SimulationEventQueue
extends RefCounted
## Presentation-side FIFO queue for simulation events.
##
## The simulation emits events synchronously as part of a [CommandResult]
## (facts already decided). Presentation enqueues them and animates at its own
## pace; it never blocks the simulation and never writes back into state.
##
## Ordering is preserved exactly as emitted (blueprint §8.2 / contract doc
## docs/PRESENTATION_BRIDGE.md).

var _events: Array[DomainEvent] = []


func enqueue(event: DomainEvent) -> void:
	if event != null:
		_events.append(event)


## Appends a result's events in emission order.
func enqueue_result(result: CommandResult) -> void:
	if result == null:
		return
	for event in result.events:
		_events.append(event)


func enqueue_all(events: Array[DomainEvent]) -> void:
	for event in events:
		enqueue(event)


func dequeue() -> DomainEvent:
	if _events.is_empty():
		return null
	return _events.pop_front()


func peek() -> DomainEvent:
	if _events.is_empty():
		return null
	return _events[0]


func size() -> int:
	return _events.size()


func is_empty() -> bool:
	return _events.is_empty()


func clear() -> void:
	_events.clear()


## Returns every pending event in order and empties the queue.
func drain() -> Array[DomainEvent]:
	var drained: Array[DomainEvent] = []
	drained.assign(_events)
	_events.clear()
	return drained


func to_dictionary() -> Dictionary:
	var serialized: Array = []
	for event in _events:
		serialized.append(event.to_dictionary())
	return {"size": _events.size(), "events": serialized}
