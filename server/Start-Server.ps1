param(
    [switch]$BuildLocal
)

$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot 'compose.yaml'
$composeArguments = @('--file', $composeFile)
$developmentComposeFile = Join-Path $PSScriptRoot 'compose.dev.yaml'
if ($BuildLocal) {
    $composeArguments += @('--file', $developmentComposeFile)
}
$environmentFile = Join-Path $PSScriptRoot '.env'

if (Test-Path -LiteralPath $environmentFile) {
    $composeArguments += @('--env-file', $environmentFile)
}

if ($BuildLocal) {
    & docker compose @composeArguments up --detach --build
} else {
    & docker compose @composeArguments up --detach
}
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed to start the GMod server (exit $LASTEXITCODE)."
}
