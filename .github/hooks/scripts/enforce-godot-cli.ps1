$ErrorActionPreference = 'SilentlyContinue'

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) {
    exit 0
}

$payload = $null
try {
    $payload = $inputJson | ConvertFrom-Json -Depth 20
} catch {
    exit 0
}

$toolName = ''
if ($payload.toolName) {
    $toolName = [string]$payload.toolName
} elseif ($payload.tool_name) {
    $toolName = [string]$payload.tool_name
}

if ($toolName -ne 'run_in_terminal') {
    exit 0
}

$commandText = ''
if ($payload.toolInput -and $payload.toolInput.command) {
    $commandText = [string]$payload.toolInput.command
} elseif ($payload.tool_input -and $payload.tool_input.command) {
    $commandText = [string]$payload.tool_input.command
}

if ([string]::IsNullOrWhiteSpace($commandText)) {
    exit 0
}

$normalized = $commandText.ToLowerInvariant()
$looksLikeRunOrTest = $false
if ($normalized -match 'godot|--path|--headless|(^|\s)(run|test|export)(\s|$)') {
    $looksLikeRunOrTest = $true
}

if (-not $looksLikeRunOrTest) {
    exit 0
}

$hasGodotInPath = $false
if (Get-Command godot -ErrorAction SilentlyContinue) {
    $hasGodotInPath = $true
}
if (Get-Command godot4 -ErrorAction SilentlyContinue) {
    $hasGodotInPath = $true
}

if ($hasGodotInPath) {
    exit 0
}

$candidatePaths = @(
    'C:\Users\maste\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe',
    'C:\Users\edwin\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
)

$resolvedPath = $null
foreach ($path in $candidatePaths) {
    if (Test-Path $path) {
        $resolvedPath = $path
        break
    }
}

if ($resolvedPath) {
    exit 0
}

$result = @{
    hookSpecificOutput = @{
        hookEventName = 'PreToolUse'
        permissionDecision = 'deny'
        permissionDecisionReason = 'No Godot executable resolved from PATH or configured fallback paths.'
    }
}

$result | ConvertTo-Json -Depth 10 -Compress | Write-Output
exit 2
