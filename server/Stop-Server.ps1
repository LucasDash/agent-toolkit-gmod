$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot 'compose.yaml'
$composeArguments = @('--file', $composeFile)
$environmentFile = Join-Path $PSScriptRoot '.env'
if (Test-Path -LiteralPath $environmentFile) {
    $composeArguments += @('--env-file', $environmentFile)
}

& docker compose @composeArguments stop --timeout 60
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed to stop the GMod server (exit $LASTEXITCODE)."
}
