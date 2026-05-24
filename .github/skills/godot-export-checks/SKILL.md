---
name: godot-export-checks
description: 'Run Godot export/build verification on Windows with executable fallback resolution. Use for export smoke checks, CI parity checks, and build diagnostics when PATH is missing godot.'
argument-hint: 'Project path, export preset name, and optional output path'
---

# Godot Export Checks (Windows)

Use this skill to run export/build checks with reliable executable resolution.

## When To Use

- You need to validate export presets from terminal.
- You need repeatable build checks after gameplay/system changes.
- `godot` is not available in PATH and exports must still run.

## Executable Resolution

Use the same resolver workflow as godot-cli-paths:

1. Try `godot` from PATH.
2. If missing, probe and use first existing:
- `C:\Users\maste\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`
- `C:\Users\edwin\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`

## Procedure

1. Confirm project root and target export preset from arguments.
2. Resolve executable.
3. Verify preset exists in `export_presets.cfg`.
4. Run one of:
- export dry smoke (headless startup only):
  - `"<exe>" --headless --quit --path .`
- full export check:
  - `"<exe>" --headless --path . --export-release "<PresetName>" "<OutputPath>"`
5. Capture and report:
- executable path
- preset
- command
- exit code
- key output/errors

## Decision Logic

- If preset is missing, stop with `FAIL (Preset Not Found)`.
- If executable is unresolved, stop with `FAIL (Executable Not Found)`.
- If command exits non-zero, return `FAIL (Export Error)`.
- Otherwise return `PASS`.

## Completion Checks

- Executable path is explicit in output.
- Preset was validated before running export command.
- Exit code and key output were reported.
- Failure class is specific and actionable.
