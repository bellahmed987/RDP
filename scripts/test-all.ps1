$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot'
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "$env:JAVA_HOME\bin;C:\Tools\Maven\apache-maven-3.9.16\bin;C:\src\flutter\bin;C:\Android\Sdk\platform-tools;$env:Path"
Push-Location (Join-Path $root 'backend')
try { mvn clean verify; if ($LASTEXITCODE -ne 0) { throw 'Backend verification failed.' } } finally { Pop-Location }
Push-Location (Join-Path $root 'mobile')
try {
    flutter analyze; if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    flutter test; if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
    flutter build apk --debug; if ($LASTEXITCODE -ne 0) { throw 'Android APK build failed.' }
} finally { Pop-Location }
