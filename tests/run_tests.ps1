# Thin entry point; the runnable suite lives inside the Godot project.
# See tests/README.md for the layout rationale.
& "$PSScriptRoot\..\scripts\run_tests.ps1" @args
exit $LASTEXITCODE
