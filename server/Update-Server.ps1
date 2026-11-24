$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot 'compose.yaml'
$composeArguments = @('--file', $composeFile)
$environmentFile = Join-Path $PSScriptRoot '.env'
if (Test-Path -LiteralPath $environmentFile) {
    $composeArguments += @('--env-file', $environmentFile)
}
$runningServices = @(& docker compose @composeArguments ps --status running --services)
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect Docker Compose state (exit $LASTEXITCODE)."
}
if ($runningServices -contains 'gmod') {
    throw 'Stop the GMod server before updating it. Use Stop-Server.ps1 first.'
}

& docker compose @composeArguments run --rm --no-deps --entrypoint /usr/local/bin/update-server gmod
if ($LASTEXITCODE -ne 0) {
    throw "SteamCMD update failed (exit $LASTEXITCODE)."
}
