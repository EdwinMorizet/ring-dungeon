---
description: "Run a Godot project smoke check with deterministic output and executable path fallback handling."
name: "Godot Smoke Check"
argument-hint: "Project path and mode: headless or editor"
agent: "agent"
---
Run a Godot startup smoke check for this workspace.

Requirements:
1. Resolve executable using the godot-cli-paths workflow:
- first try `godot` from PATH
- if missing, probe:
  - `C:\\Users\\maste\\Documents\\DEV\\Godot_v4.6.2-stable_win64.exe\\Godot_v4.6.2-stable_win64_console.exe`
  - `C:\\Users\\edwin\\Documents\\DEV\\Godot_v4.6.2-stable_win64.exe\\Godot_v4.6.2-stable_win64_console.exe`
- use the first existing path
2. Run from project root.
3. Use mode from prompt argument:
- `headless` => `--headless --quit --path .`
- `editor` => `--quit --path .`
- default to `headless`
4. If no executable is found, stop and report that clearly.

Output format (exact headings):
- `Executable`
- `Command`
- `Working Directory`
- `Exit Code`
- `Key Output`
- `Result`

For `Result`, use one of:
- `PASS`
- `FAIL (Executable Not Found)`
- `FAIL (Launch Error)`
