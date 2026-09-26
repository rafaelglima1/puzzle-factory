class_name ColorKeyMatchingRule
extends MatchingRule
## M2 matching rule: the entity and the item share the same stable color key.
##
## Keys are logical identities such as COLOR_A / COLOR_B; presentation colors
## are irrelevant here and never referenced (blueprint §14, §59).
## Empty keys never match anything.

const RULE_NAME := &"color_key"


func rule_name() -> StringName:
	return RULE_NAME


func matches(entity: Entity, item: Item) -> bool:
	if entity == null or item == null:
		return false
	if entity.color_key == &"" or item.color_key == &"":
		return false
	return entity.color_key == item.color_key
