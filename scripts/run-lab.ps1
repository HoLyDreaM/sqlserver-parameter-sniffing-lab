#Requires -Version 5.1
<#
.SYNOPSIS
  Waits for SQL Server container health, prints status and sqlcmd bootstrap chain.
#>
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Get-DotEnvValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Default = $null
    )
    if (-not (Test-Path $Path)) { return $Default }
    $pattern = "^\s*$([regex]::Escape($Name))=(.*)$"
    foreach ($line in Get-Content $Path) {
        if ($line -match $pattern) {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $Default
}

$Container = "sqlserver-parameter-sniffing-lab"
$MaxWaitSec = 180
$PollSec = 5
$EnvFile = Join-Path $Root ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Host ".env missing — run .\scripts\setup.ps1 first"
    exit 1
}

$hostPort = Get-DotEnvValue -Path $EnvFile -Name "MSSQL_HOST_PORT" -Default "14335"
$saPassword = Get-DotEnvValue -Path $EnvFile -Name "MSSQL_SA_PASSWORD"

Write-Host "Host port (127.0.0.1): $hostPort"

$running = docker ps -q -f "name=^/${Container}$"
if (-not $running) {
    Write-Host "Container not running. Starting with docker compose up -d ..."
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }
}

Write-Host "Waiting for health (max ${MaxWaitSec}s)..."
$elapsed = 0
do {
    $status = docker inspect --format="{{.State.Health.Status}}" $Container 2>$null
    if ($status -eq "healthy") {
        Write-Host "Health: healthy"
        break
    }
    if ($elapsed -ge $MaxWaitSec) {
        Write-Host "Timed out. Last status: $status"
        docker compose ps
        exit 1
    }
    Write-Host "  status=$status  elapsed=${elapsed}s"
    Start-Sleep -Seconds $PollSec
    $elapsed += $PollSec
} while ($true)

Write-Host ""
Write-Host "=== Lab ready ==="
docker compose ps
Write-Host ""
Write-Host "sqlcmd bootstrap chain (host tools / Azure Data Studio):"
Write-Host "  sqlcmd -S localhost,$hostPort -U sa -P `"<MSSQL_SA_PASSWORD from .env>`" -C -I -f 65001 -Q `"SELECT @@VERSION`""
Write-Host "  sqlcmd -S localhost,$hostPort -U sa -P `"<MSSQL_SA_PASSWORD from .env>`" -C -I -f 65001 -i .\database\01-create-database.sql"
Write-Host "  sqlcmd -S localhost,$hostPort -U sa -P `"<MSSQL_SA_PASSWORD from .env>`" -C -I -f 65001 -d SniffLab -i .\database\02-create-schema.sql"
Write-Host "  sqlcmd -S localhost,$hostPort -U sa -P `"<MSSQL_SA_PASSWORD from .env>`" -C -I -f 65001 -d SniffLab -i .\database\03-seed-data.sql"
Write-Host "  sqlcmd -S localhost,$hostPort -U sa -P `"<MSSQL_SA_PASSWORD from .env>`" -C -I -f 65001 -d SniffLab -i .\database\04-enable-query-store.sql"
Write-Host "  sqlcmd -S localhost,$hostPort -U sa -P `"<MSSQL_SA_PASSWORD from .env>`" -C -I -f 65001 -i .\scripts\run-smoke-tests.sql"
Write-Host ""
Write-Host "Inside container (always port 1433):"
Write-Host "  docker exec -it $Container /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P `"`$env:MSSQL_SA_PASSWORD`" -C"
Write-Host ""
Write-Host "Lab mounts (read-only): /lab/database  /lab/labs  /lab-scripts"
Write-Host "Stop:  docker compose down"
Write-Host "Wipe data volume:  docker compose down -v"

if ($saPassword) {
    Write-Host ""
    Write-Host "(Password loaded from .env for local use — not printed.)"
}
