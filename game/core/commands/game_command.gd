class_name GameCommand
extends RefCounted
## Base contract for commands (blueprint §12).
##
## Flow: command → validate → apply logical mutation → create result →
## emit domain events. Commands must be fully testable without scenes and
## must never touch presentation, audio, analytics or file IO.

## Stable machine-readable command name (used by tests and future analytics).
func command_name() -> StringName:
	return &"game_command"


## Executes the command against [param context]. Subclasses override this.
func execute(_context: CommandContext) -> CommandResult:
	return CommandResult.rejected(
		CommandResult.Status.INVALID,
		&"not_implemented",
		[DomainEvent.command_rejected(CommandResult.Status.INVALID, &"not_implemented")]
	)
