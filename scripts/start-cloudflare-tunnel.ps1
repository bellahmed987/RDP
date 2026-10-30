$ErrorActionPreference = 'Stop'

$cloudflaredCommand = Get-Command 'cloudflared' -ErrorAction SilentlyContinue
$cloudflaredExe = if ($cloudflaredCommand) { $cloudflaredCommand.Source } else { $null }

if (-not $cloudflaredExe) {
    $downloadsExe = Join-Path $env:USERPROFILE 'Downloads\cloudflared-windows-amd64.exe'
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $installedExe = Join-Path $programFilesX86 'cloudflared\cloudflared.exe'
    if (Test-Path $downloadsExe) {
        $cloudflaredExe = $downloadsExe
    } elseif (Test-Path $installedExe) {
        $cloudflaredExe = $installedExe
    }
}

if (-not $cloudflaredExe) {
    throw 'cloudflared was not found. Install the Windows 64-bit MSI from https://developers.cloudflare.com/tunnel/downloads/, then open a new PowerShell window.'
}

$backend = Test-NetConnection -ComputerName 'localhost' -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue
if (-not $backend) {
    throw 'The backend is not listening on localhost:8080. Start MariaDB and run .\scripts\start-backend.ps1 in another PowerShell window first.'
}

Write-Host 'Starting a temporary public Cloudflare Quick Tunnel for http://localhost:8080.' -ForegroundColor Cyan
Write-Host 'Keep this window open. Copy the https://*.trycloudflare.com URL from the output to build the phone APK.' -ForegroundColor Yellow
Write-Host 'The URL changes when this tunnel is restarted.' -ForegroundColor Yellow

& $cloudflaredExe tunnel --url 'http://localhost:8080'
if ($LASTEXITCODE -ne 0) {
    throw "cloudflared exited with code $LASTEXITCODE."
}
