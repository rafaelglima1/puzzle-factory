class_name LevelLoadResult
extends RefCounted
## Structured outcome of loading a level definition from JSON, file or dict.
##
## [member errors] carries machine-readable codes; [member definition] is only
## non-null on [constant Status.OK].

enum Status {
	OK,
	FILE_NOT_FOUND,
	IO_ERROR,
	INVALID_JSON,
	NOT_A_DICTIONARY,
	UNSUPPORTED_SCHEMA_VERSION,
	MIGRATION_FAILED,
	VALIDATION_FAILED,
}

var status: int = Status.OK
var definition: LevelDefinition = null
var errors: PackedStringArray = PackedStringArray()
var source_path: String = ""
var schema_version: int = 0


func is_ok() -> bool:
	return status == Status.OK


func error_codes() -> PackedStringArray:
	return errors
