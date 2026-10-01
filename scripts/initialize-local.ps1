$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envFile = Join-Path $root '.env.local'
$localReadme = Join-Path $root 'README.local.md'
function New-Secret([int]$Bytes) {
    $buffer = New-Object byte[] $Bytes
    [Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
    [Convert]::ToBase64String($buffer)
}
if (-not (Test-Path $envFile)) {
    $jwt = New-Secret 48
    $adminPassword = New-Secret 24
    $demoPassword = New-Secret 24
    $lines = @(
        'DB_URL=jdbc:mariadb://localhost:3306/resource_distribution_db',
        'DB_USERNAME=root',
        'DB_PASSWORD=',
        "JWT_SECRET=$jwt",
        'ADMIN_EMAIL=admin@rdp.local',
        "ADMIN_PASSWORD=$adminPassword",
        "SEED_DEMO_PASSWORD=$demoPassword",
        'FCM_ENABLED=false',
        'FIREBASE_CREDENTIALS=',
        'GOOGLE_CLIENT_ID='
    )
    [IO.File]::WriteAllLines($envFile, $lines, [Text.UTF8Encoding]::new($false))
}
if (-not (Test-Path $localReadme)) {
    $values = @{}
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    $readmeLines = @(
        '# Local development credentials',
        '',
        'These credentials are unique to this computer and are excluded from Git. Do not share this file.',
        '',
        'Administrator',
        "Email: $($values['ADMIN_EMAIL'])",
        "Password: $($values['ADMIN_PASSWORD'])",
        '',
        'Demo donor and recipient',
        'Donor email: donor@example.local',
        'Recipient email: recipient@example.local',
        "Password for both demo accounts: $($values['SEED_DEMO_PASSWORD'])",
        '',
        'Read .env.local for the app configuration. Change the generated passwords before sharing or deploying.'
    )
    [IO.File]::WriteAllLines($localReadme, $readmeLines, [Text.UTF8Encoding]::new($false))
}
Write-Output 'Local secrets are ready in ignored .env.local and README.local.md.'
