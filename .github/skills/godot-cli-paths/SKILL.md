---
name: godot-cli-paths
description: 'Resolve Godot executable path issues and run CLI project smoke checks on Windows. Use when Godot is not found in PATH, when launch commands fail, or when validating project boot from terminal.'
argument-hint: 'Project path and optional run mode (headless or editor)'
---

# Godot CLI Paths (Windows)

Use this skill to reliably find and run Godot from terminal when `godot` is not available in PATH.

## When To Use

- `godot` command is not found in terminal.
- You need a repeatable startup smoke check for a Godot project.
- You need fixed fallback executable paths for this workspace.

## Candidate Executables

Probe these paths and use the first existing executable:

1. `C:\Users\maste\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`
2. `C:\Users\edwin\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`

## Procedure

1. Determine target project root.
2. Check if `godot` is available via PATH.
3. If PATH command is missing, probe the preferred executable paths in order.
4. Select the first existing executable.
5. Choose run mode from prompt argument, then run from project root:
- If mode is `headless`:
  - `"<exe>" --headless --quit --path .`
- If mode is `editor`:
  - `"<exe>" --quit --path .`
- If mode is omitted:
  - default to `headless`.
6. Capture and report outcome:
- executable path used
- command executed
- exit code
- key stderr/stdout lines

## Decision Logic

- If PATH `godot` exists: use it.
- Else probe candidate paths and use the first existing path.
- Else: stop and report that no Godot executable was found.

## Completion Checks

A run is complete when all checks are true:

- A Godot executable was resolved (PATH or fallback path).
- The smoke command executed from the intended project directory.
- Exit code and meaningful output were reported.
- If failed, the failure reason and next action were reported clearly.

## Failure Handling

If no executable is found:

1. Report both expected fallback paths.
2. Ask the user to confirm install location or provide another executable path.
3. Offer a direct command template the user can run with their custom path.

If executable exists but launch fails:

1. Report full command and exit code.
2. Re-run with `--verbose` when helpful.
3. Distinguish project errors from executable resolution errors.
