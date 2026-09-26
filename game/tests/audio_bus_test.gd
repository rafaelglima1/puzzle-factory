extends "res://tests/framework/test_base.gd"
## M4 audio layout: the real runtime exposes the blueprint buses and routing.
## Asserts the shipped default bus layout through AudioServer, not by grepping.

const AudioContract := preload("res://audio/audio_contract.gd")

const EXPECTED_BUSES: Array[String] = ["Master", "Music", "SFX", "UI"]
const CHILD_BUSES: Array[String] = ["Music", "SFX", "UI"]


func run() -> void:
	_runtime_exposes_four_buses()
	_contract_names_are_real_buses()
	_children_route_to_master()
	_master_has_no_send()
	_buses_start_unmuted_at_zero_db()


func _index(bus_name: String) -> int:
	return AudioServer.get_bus_index(bus_name)


func _runtime_exposes_four_buses() -> void:
	check(AudioServer.get_bus_count() >= 4, "runtime exposes at least four buses (got %d)" % AudioServer.get_bus_count())
	for bus_name in EXPECTED_BUSES:
		check(_index(bus_name) != -1, "runtime bus '%s' exists" % bus_name)


func _contract_names_are_real_buses() -> void:
	var declared: Array = AudioContract.expected_buses()
	check_eq(declared.size(), 4, "audio contract declares four buses")
	for bus_name: Variant in declared:
		check(_index(String(bus_name)) != -1, "contract bus '%s' exists at runtime" % bus_name)


func _children_route_to_master() -> void:
	for bus_name in CHILD_BUSES:
		var index := _index(bus_name)
		if index == -1:
			continue
		check_eq(AudioServer.get_bus_send(index), &"Master", "bus '%s' routes to Master" % bus_name)


func _master_has_no_send() -> void:
	var index := _index("Master")
	if index == -1:
		return
	check_eq(String(AudioServer.get_bus_send(index)), "", "Master has no further send target")


func _buses_start_unmuted_at_zero_db() -> void:
	for bus_name in EXPECTED_BUSES:
		var index := _index(bus_name)
		if index == -1:
			continue
		check(not AudioServer.is_bus_mute(index), "bus '%s' starts unmuted" % bus_name)
		check_eq(AudioServer.get_bus_volume_db(index), 0.0, "bus '%s' starts at 0 dB" % bus_name)
