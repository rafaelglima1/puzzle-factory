extends "res://tests/framework/test_base.gd"
## Generic matching abstraction and the M2 color-key rule.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


## Test-local rule proving the abstraction is extensible without touching core.
class AlwaysMatchesRule extends MatchingRule:
	func rule_name() -> StringName:
		return &"always_matches"

	func matches(_entity: Entity, _item: Item) -> bool:
		return true


func run() -> void:
	_contract_defaults()
	_color_key_rule()
	_key_format_separation()
	_extensibility()


func _contract_defaults() -> void:
	var base := MatchingRule.new()
	check_eq(base.rule_name(), &"matching_rule", "base rule name")
	check(not base.matches(Fixture.make_entity(&"e1"), Item.new(&"i1")), "base rule never matches")


func _color_key_rule() -> void:
	var rule := ColorKeyMatchingRule.new()
	check_eq(rule.rule_name(), ColorKeyMatchingRule.RULE_NAME, "rule name is stable")
	check_eq(rule.rule_name(), &"color_key", "rule name value")

	var red_entity := Fixture.make_entity(&"e1")
	red_entity.color_key = &"COLOR_A"
	var matching_item := Item.new(&"i1", &"unit_item", &"COLOR_A")
	var other_item := Item.new(&"i2", &"unit_item", &"COLOR_B")
	var unkeyed_item := Item.new(&"i3", &"unit_item", &"")

	check(rule.matches(red_entity, matching_item), "same color key matches")
	check(not rule.matches(red_entity, other_item), "different color key does not match")
	check(not rule.matches(red_entity, unkeyed_item), "item without a key never matches")

	var unkeyed_entity := Fixture.make_entity(&"e2")
	check(not rule.matches(unkeyed_entity, matching_item), "entity without a key never matches")
	check(not rule.matches(null, matching_item), "null entity is safe")
	check(not rule.matches(red_entity, null), "null item is safe")


func _key_format_separation() -> void:
	# Logical identity and presentation color are separate: stable keys follow
	# the theme-base format, literal render colors do not (blueprint §14, §59).
	check(ThemeContract.is_valid_color_key(&"COLOR_A"), "COLOR_A is a valid logical key")
	check(ThemeContract.is_valid_color_key(&"COLOR_12"), "numeric key suffix is valid")
	check(not ThemeContract.is_valid_color_key(&"blue"), "literal render color is not a logical key")
	check(not ThemeContract.is_valid_color_key(&"COLOR_"), "empty suffix is not a valid key")
	check(not ThemeContract.is_valid_color_key(&""), "empty key is not valid")
	var rule := ColorKeyMatchingRule.new()
	var entity := Fixture.make_entity(&"e1")
	entity.color_key = &"COLOR_A"
	var item := Item.new(&"i1", &"unit_item", &"COLOR_A")
	check(rule.matches(entity, item), "matching compares opaque keys, not render colors")


func _extensibility() -> void:
	var custom := AlwaysMatchesRule.new()
	check_eq(custom.rule_name(), &"always_matches", "custom rule name")
	check(custom.matches(Fixture.make_entity(&"e1"), Item.new(&"i1")), "custom rule can match anything")
	check(custom is MatchingRule, "custom rule honours the contract")
