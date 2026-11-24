$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot 'compose.yaml'
$composeArguments = @('--file', $composeFile)
$environmentFile = Join-Path $PSScriptRoot '.env'
if (Test-Path -LiteralPath $environmentFile) {
    $composeArguments += @('--env-file', $environmentFile)
}

& docker compose @composeArguments ps
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect Docker Compose state (exit $LASTEXITCODE)."
}

& docker compose @composeArguments logs --tail 80 gmod
if ($LASTEXITCODE -ne 0) {
    throw "Could not read GMod server logs (exit $LASTEXITCODE)."
}
