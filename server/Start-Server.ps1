$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot 'compose.yaml'
$composeArguments = @('--file', $composeFile)
$environmentFile = Join-Path $PSScriptRoot '.env'

if (Test-Path -LiteralPath $environmentFile) {
    $composeArguments += @('--env-file', $environmentFile)
}

& docker compose @composeArguments up --detach --build
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed to start the GMod server (exit $LASTEXITCODE)."
}
