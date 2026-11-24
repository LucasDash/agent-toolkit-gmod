$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot 'compose.yaml'
$composeArguments = @('--file', $composeFile)
$environmentFile = Join-Path $PSScriptRoot '.env'
if (Test-Path -LiteralPath $environmentFile) {
    $composeArguments += @('--env-file', $environmentFile)
}
$volumeName = 'agent_toolkit_gmod_data'
$backupImage = 'alpine:3.22@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f'
$runningServices = @(& docker compose @composeArguments ps --status running --services)
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect Docker Compose state (exit $LASTEXITCODE)."
}
if ($runningServices -contains 'gmod') {
    throw 'Stop the GMod server before taking a consistent backup. Use Stop-Server.ps1 first.'
}

$backupDirectory = Join-Path $PSScriptRoot 'backups'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupDirectory "agent-toolkit-gmod-$stamp.tar.gz"
$containerName = "agent-toolkit-gmod-backup-$stamp"

& docker create --name $containerName --mount "type=volume,source=$volumeName,target=/data,readonly" $backupImage tar -C /data -czf /tmp/gmod-data.tar.gz . | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not create the backup helper container (exit $LASTEXITCODE)."
}

try {
    & docker start --attach $containerName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "The backup archive could not be created (exit $LASTEXITCODE)."
    }

    & docker cp "${containerName}:/tmp/gmod-data.tar.gz" $backupPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not copy the backup archive out of Docker (exit $LASTEXITCODE)."
    }
    Write-Output "Backup saved to $backupPath"
}
finally {
    & docker rm --force $containerName | Out-Null
}
