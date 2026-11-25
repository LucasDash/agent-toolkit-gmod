[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
    throw 'Create server/.env from server/.env.example before preparing the collection playtest.'
}

$operatorLine = Get-Content -LiteralPath $envPath |
    Where-Object { $_ -match '^\s*AGENT_SUITE_OPERATOR_STEAMID64\s*=' } |
    Select-Object -Last 1
if (-not $operatorLine) {
    throw 'Set AGENT_SUITE_OPERATOR_STEAMID64 in the ignored server/.env (use 0 to disable the local operator grant).'
}

$operatorSteamId = ($operatorLine -split '=', 2)[1].Trim()
if ($operatorSteamId.Length -ge 2 -and
    (($operatorSteamId.StartsWith('"') -and $operatorSteamId.EndsWith('"')) -or
     ($operatorSteamId.StartsWith("'") -and $operatorSteamId.EndsWith("'")))) {
    $operatorSteamId = $operatorSteamId.Substring(1, $operatorSteamId.Length - 2)
}
if ($operatorSteamId -notmatch '^(0|[0-9]{17})$') {
    throw 'AGENT_SUITE_OPERATOR_STEAMID64 must be 0 or a 17-digit SteamID64.'
}

$stateDirectory = Join-Path $PSScriptRoot '.state\collection'
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$operatorIdPath = Join-Path $stateDirectory 'operator_steamid64.txt'
[System.IO.File]::WriteAllText($operatorIdPath, $operatorSteamId, [System.Text.Encoding]::ASCII)

$operatorConfigured = $operatorSteamId -ne '0'
Write-Output "Prepared ignored collection operator file (local operator configured: $operatorConfigured)."
