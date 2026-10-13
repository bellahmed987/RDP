$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "C:\src\flutter\bin;C:\Android\Sdk\platform-tools;$env:Path"
$mapArgs = @()
if (Test-Path (Join-Path $root 'mobile\maptiler.env.json')) {
    $mapArgs += '--dart-define-from-file=maptiler.env.json'
}
Push-Location (Join-Path $root 'mobile')
try { flutter build apk --debug @mapArgs } finally { Pop-Location }
