class_name MatchingRule
extends RefCounted
## Contract for "may this entity take this item?" (blueprint §14).
##
## M2 implements ColorKey matching. Future rules (destination, symbol,
## priority, wildcard, multi-color) are added as new subclasses; they must not
## change existing rule semantics. Rules are pure: no state mutation, no
## randomness, no presentation dependency.


## Stable rule id (used by tests and analytics).
func rule_name() -> StringName:
	return &"matching_rule"


func matches(_entity: Entity, _item: Item) -> bool:
	return false
