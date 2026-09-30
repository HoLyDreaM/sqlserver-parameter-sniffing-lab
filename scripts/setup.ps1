#Requires -Version 5.1
<#
.SYNOPSIS
  Copies .env.example -> .env (if missing) and starts SQL Server Parameter Sniffing Lab.
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

$EnvFile = Join-Path $Root ".env"
$EnvExample = Join-Path $Root ".env.example"

if (-not (Test-Path $EnvExample)) {
    throw ".env.example not found at $EnvExample"
}

if (-not (Test-Path $EnvFile)) {
    Copy-Item -Path $EnvExample -Destination $EnvFile
    Write-Host "Created .env from .env.example"
} else {
    Write-Host ".env already exists — left unchanged"
}

$hostPort = Get-DotEnvValue -Path $EnvFile -Name "MSSQL_HOST_PORT" -Default "14335"
Write-Host "Host port (127.0.0.1): $hostPort"

foreach ($dir in @("database", "labs")) {
    $path = Join-Path $Root $dir
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Write-Host "Created empty ./$dir for read-only mount"
    }
}

Write-Host "Validating compose..."
docker compose config --quiet
if ($LASTEXITCODE -ne 0) { throw "docker compose config failed" }

Write-Host "Starting sqlserver-parameter-sniffing-lab on 127.0.0.1:${hostPort} -> 1433 ..."
docker compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

Write-Host ""
Write-Host "Setup complete. Wait for healthy, then connect:"
Write-Host "  docker compose ps"
Write-Host "  .\scripts\run-lab.ps1"
Write-Host "  sqlcmd -S localhost,$hostPort -U sa -P `"<MSSQL_SA_PASSWORD from .env>`" -C -Q `"SELECT @@VERSION`""
