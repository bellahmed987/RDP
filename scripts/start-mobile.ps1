$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "C:\src\flutter\bin;C:\Android\Sdk\platform-tools;$env:Path"
Push-Location (Join-Path $root 'mobile')
try { flutter run } finally { Pop-Location }
