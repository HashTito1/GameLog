# Gets a fresh IGDB (Twitch) app access token, saves it to dart_defines.json
# and checks that IGDB answers. Tokens expire after about 60 days.
#
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File scripts\refresh_igdb_token.ps1

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot '..\dart_defines.json'

if (-not (Test-Path $configPath)) {
    Write-Host 'dart_defines.json not found. Copy dart_defines.example.json first.' -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$clientId = $config.IGDB_CLIENT_ID
Write-Host "Client ID: $clientId"
$secure = Read-Host 'Twitch client secret (from dev.twitch.tv/console/apps)' -AsSecureString
$secret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

try {
    $token = Invoke-RestMethod -Method Post -Uri 'https://id.twitch.tv/oauth2/token' -Body @{
        client_id     = $clientId
        client_secret = $secret
        grant_type    = 'client_credentials'
    }
} catch {
    Write-Host 'Twitch rejected the request. Check the client ID and secret.' -ForegroundColor Red
    exit 1
}

$config.IGDB_ACCESS_TOKEN = $token.access_token
# Write without a BOM; Flutter's --dart-define-from-file can't parse one.
[IO.File]::WriteAllText((Resolve-Path $configPath), ($config | ConvertTo-Json))
$days = [math]::Round($token.expires_in / 86400)
Write-Host "New token saved to dart_defines.json (valid for about $days days)." -ForegroundColor Green

$headers = @{ 'Client-ID' = $clientId; 'Authorization' = "Bearer $($token.access_token)" }
$games = Invoke-RestMethod -Method Post -Uri 'https://api.igdb.com/v4/games' -Headers $headers `
    -ContentType 'text/plain' -Body 'search "zelda"; fields name; limit 3;'
Write-Host "IGDB test search returned: $(($games | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Green
