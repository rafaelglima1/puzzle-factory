extends "res://tests/framework/test_base.gd"
## Generic FIFO queue: ordering, empty safety, serialization determinism.


func run() -> void:
	_empty_behaviour()
	_fifo_ordering()
	_mutation_guards()
	_serialization()
	_determinism()


func _empty_behaviour() -> void:
	var queue := ItemQueue.new(&"q1")
	check(queue.is_empty(), "new queue is empty")
	check_eq(queue.remaining_count(), 0, "empty remaining count")
	check_eq(queue.peek(), &"", "peek on empty queue returns empty id")
	check_eq(queue.take(), &"", "take on empty queue returns empty id")
	check_eq(queue.take(), &"", "repeated take on empty queue stays safe")
	check(queue.is_empty(), "queue still empty after empty takes")
	check_eq(queue.policy, ItemQueue.Policy.FIFO, "default policy is FIFO")
	check_eq(ItemQueue.policy_to_string_name(queue.policy), &"fifo", "policy name is stable")


func _fifo_ordering() -> void:
	var queue := ItemQueue.new(&"q1")
	check(queue.enqueue(&"a"), "enqueue a")
	check(queue.enqueue(&"b"), "enqueue b")
	check(queue.enqueue(&"c"), "enqueue c")
	check_eq(queue.remaining_count(), 3, "remaining count")
	check_eq(queue.peek(), &"a", "peek returns front without removing")
	check_eq(queue.remaining_count(), 3, "peek does not consume")
	check_eq(queue.take(), &"a", "take returns front (1)")
	check_eq(queue.take(), &"b", "take returns front (2)")
	check_eq(queue.take(), &"c", "take returns front (3)")
	check(queue.is_empty(), "queue drains in FIFO order")
	check_eq(queue.item_ids(), [], "empty item id list")


func _mutation_guards() -> void:
	var queue := ItemQueue.new(&"q1")
	queue.enqueue(&"a")
	check(not queue.enqueue(&"a"), "duplicate id rejected")
	check(not queue.enqueue(&""), "empty id rejected")
	check_eq(queue.remaining_count(), 1, "guards do not corrupt the queue")
	check(queue.contains(&"a"), "contains reports queued item")
	check(not queue.contains(&"z"), "contains reports unknown item")
	queue.enqueue(&"b")
	check(queue.remove(&"a"), "remove existing item")
	check(not queue.remove(&"a"), "double remove rejected")
	var remaining: Array[StringName] = [&"b"]
	check_eq(queue.item_ids(), remaining, "order preserved after removal")
	var ids := queue.item_ids()
	check_eq(ids.size(), 1, "item_ids returns a copy of the queue")
	ids.append(&"injected")
	check_eq(queue.remaining_count(), 1, "mutating the copy does not touch the queue")
	queue.clear()
	check(queue.is_empty(), "clear empties the queue")


func _serialization() -> void:
	var queue := ItemQueue.new(&"q1")
	queue.visible_count = 2
	queue.enqueue(&"c")
	queue.enqueue(&"a")
	queue.enqueue(&"b")
	var restored := ItemQueue.from_dictionary(queue.to_dictionary())
	check(restored.logical_equals(queue), "queue roundtrip preserves state")
	check_eq(restored.item_ids(), queue.item_ids(), "FIFO order survives serialization")
	check_eq(restored.visible_count, 2, "visible count survives serialization")
	check_eq(restored.id, &"q1", "id survives serialization")
	var unknown_policy := ItemQueue.from_dictionary({"id": "q2", "policy": "not_a_policy", "item_ids": []})
	check_eq(unknown_policy.policy, ItemQueue.Policy.FIFO, "unknown policy falls back to FIFO")
	check_eq(ItemQueue.policy_from_string_name(&"not_a_policy"), -1, "unknown policy name reports -1")


func _determinism() -> void:
	var first := ItemQueue.new(&"q1")
	var second := ItemQueue.new(&"q1")
	for item_id in [&"x", &"y", &"z", &"w"]:
		first.enqueue(item_id)
		second.enqueue(item_id)
	check_eq(first.item_ids(), second.item_ids(), "same operations produce the same order")
	check_eq(first.take(), second.take(), "takes stay in lockstep")
	check_eq(first.to_dictionary(), second.to_dictionary(), "serialized queues are identical")
