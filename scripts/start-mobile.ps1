$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "C:\src\flutter\bin;C:\Android\Sdk\platform-tools;$env:Path"
$googleClientId = ''
$envFile = Join-Path $root '.env.local'
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*GOOGLE_CLIENT_ID\s*=(.*)$') { $googleClientId = $Matches[1].Trim() }
    }
}
$flutterArgs = @('run')
if (-not [string]::IsNullOrWhiteSpace($googleClientId)) {
    $flutterArgs += "--dart-define=GOOGLE_SERVER_CLIENT_ID=$googleClientId"
}
Push-Location (Join-Path $root 'mobile')
try { flutter @flutterArgs } finally { Pop-Location }
