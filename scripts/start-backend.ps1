$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envFile = Join-Path $root '.env.local'
if (-not (Test-Path $envFile)) { & (Join-Path $PSScriptRoot 'initialize-local.ps1') }
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#\s=]+)\s*=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim(), 'Process')
    }
}
if (-not (Test-NetConnection -ComputerName localhost -Port 3306 -InformationLevel Quiet)) {
    throw 'MariaDB is not listening on port 3306. Start MySQL in XAMPP, then retry.'
}
$sql = Join-Path $root 'backend\database\create_database.sql'
Get-Content $sql | & 'C:\xampp\mysql\bin\mysql.exe' -h localhost -u $env:DB_USERNAME
if ($LASTEXITCODE -ne 0) { throw 'Could not prepare the local database.' }
Push-Location (Join-Path $root 'backend')
try {
    $env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot'
    $env:Path = "$env:JAVA_HOME\bin;C:\Tools\Maven\apache-maven-3.9.16\bin;$env:Path"
    & 'C:\Tools\Maven\apache-maven-3.9.16\bin\mvn.cmd' spring-boot:run
} finally { Pop-Location }
