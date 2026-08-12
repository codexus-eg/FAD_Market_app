param(
  [string]$KeystorePath = "android/upload-keystore.jks",
  [string]$PropertiesPath = "android/key.properties"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $KeystorePath)) {
  throw "Keystore not found: $KeystorePath"
}
if (-not (Test-Path $PropertiesPath)) {
  throw "key.properties not found: $PropertiesPath"
}

$properties = @{}
Get-Content $PropertiesPath | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
    $parts = $line.Split("=", 2)
    $properties[$parts[0].Trim()] = $parts[1].Trim()
  }
}

$required = @("keyAlias", "keyPassword", "storePassword")
foreach ($key in $required) {
  if (-not $properties.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($properties[$key])) {
    throw "Missing $key in $PropertiesPath"
  }
}

$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $KeystorePath)))

Write-Host "Create these GitHub Actions secrets:" -ForegroundColor Cyan
Write-Host "ANDROID_KEYSTORE_BASE64=$base64"
Write-Host "ANDROID_KEY_ALIAS=$($properties['keyAlias'])"
Write-Host "ANDROID_KEY_PASSWORD=$($properties['keyPassword'])"
Write-Host "ANDROID_STORE_PASSWORD=$($properties['storePassword'])"
Write-Host ""
Write-Host "Keep this output private. Never commit it to GitHub." -ForegroundColor Yellow
