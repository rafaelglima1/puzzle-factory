class_name ArrivalResolver
extends RefCounted
## Generic arrival resolution: after an entity reaches its destination, load
## matching items from the destination queue (strict FIFO, bounded by entity
## capacity and destination capacity) and decide the entity's fate.
##
## Deterministic rules (see docs/GAME_RULES.md):
## - Loading inspects the queue FRONT only. If the front item does not match
##   (different color key, or destination does not accept it), loading stops;
##   items are never skipped.
## - Loading also stops when the entity capacity or the destination capacity
##   is reached.
## - At least one item loaded -> the entity COMPLETES and leaves the board.
## - Zero items loaded -> the entity is STAGED (it waits for service). If the
##   staging area is full, the level is lost with STAGING_FULL (the caller
##   raises the failure; this resolver only reports the outcome).
##
## The resolver never reads presentation state and never waits for animation.

const OUTCOME_COMPLETED := &"completed"
const OUTCOME_STAGED := &"staged"
const OUTCOME_STAGING_FULL := &"staging_full"

var _matching_rule: MatchingRule


func _init(matching_rule: MatchingRule = null) -> void:
	_matching_rule = matching_rule if matching_rule != null else ColorKeyMatchingRule.new()


func matching_rule() -> MatchingRule:
	return _matching_rule


## Mutates state/emits events. Returns:
## { loaded_count: int, outcome: StringName, destination_id: StringName, color_key: StringName }
func resolve(context: CommandContext, entity: Entity) -> Dictionary:
	var state := context.state
	var destination := state.get_destination(entity.destination_id)
	var loaded_count := 0
	var remaining_capacity := entity.capacity if entity.capacity > 0 else -1

	var queue: ItemQueue = null
	if destination != null and destination.queue_id != &"":
		queue = state.get_queue(destination.queue_id)

	while destination != null and queue != null and not queue.is_empty():
		if remaining_capacity == 0:
			break
		if not destination.has_capacity():
			break
		var item_id := queue.peek()
		var item := state.get_item(item_id)
		if item == null:
			break
		if not destination.accepts(item.color_key):
			break
		if not _matching_rule.matches(entity, item):
			break
		queue.take()
		state.remove_item(item_id)
		destination.processed_count += 1
		loaded_count += 1
		if remaining_capacity > 0:
			remaining_capacity -= 1
		context.emit_event(DomainEvent.item_loaded(entity.id, item_id, item.color_key, destination.id, loaded_count))
	if destination != null:
		destination.refresh_state()

	if loaded_count > 0:
		context.emit_event(DomainEvent.match_occurred(entity.id, entity.color_key, loaded_count))
		entity.set_state(EntityState.Value.COMPLETED)
		state.board.remove_entity(entity)
		context.emit_event(DomainEvent.entity_completed(entity.id, destination.id if destination != null else &""))
		return {
			"loaded_count": loaded_count,
			"outcome": OUTCOME_COMPLETED,
			"destination_id": entity.destination_id,
			"color_key": entity.color_key,
		}

	var slot_index := state.staging.add(entity.id)
	entity.set_state(EntityState.Value.WAITING)
	if slot_index < 0:
		return {
			"loaded_count": 0,
			"outcome": OUTCOME_STAGING_FULL,
			"destination_id": entity.destination_id,
			"color_key": entity.color_key,
		}
	state.board.remove_entity(entity)
	context.emit_event(DomainEvent.staging_changed(DomainEvent.STAGING_ADDED, entity.id, slot_index, state.staging))
	return {
		"loaded_count": 0,
		"outcome": OUTCOME_STAGED,
		"destination_id": entity.destination_id,
		"color_key": entity.color_key,
	}
