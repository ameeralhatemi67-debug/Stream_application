# Creates the Google Play upload key and project\android\key.properties.
#
# Run it YOURSELF in a normal PowerShell window (not through Claude): it asks for
# the key password, and that password must never be typed into chat or committed.
#
#   cd "<repo root>"
#   powershell -ExecutionPolicy Bypass -File brief\launch\make_upload_key.ps1
#
# It refuses to overwrite an existing keystore. Back up the printed file and the
# password in two places afterwards (see brief\launch\01_OWNER_STEPS.md section 6).

$ErrorActionPreference = 'Stop'

$keyDir = Join-Path $env:USERPROFILE 'hadayah-keys'
$jks    = Join-Path $keyDir 'upload-keystore.jks'
$props  = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\project\android\key.properties'))

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
  throw 'keytool was not found. Install a JDK or use the one in Android Studio (jbr\bin).'
}
if (Test-Path $jks)   { throw "A keystore already exists at $jks. Not overwriting it." }
if (Test-Path $props) { throw "$props already exists. Not overwriting it." }

function Read-Secret($prompt) {
  $secure = Read-Host $prompt -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$password = Read-Secret 'Choose a key password (12+ characters, write it in your password manager)'
$again    = Read-Secret 'Type it again'
if ($password -ne $again)   { throw 'The two passwords differ. Nothing was created.' }
if ($password.Length -lt 12) { throw 'Use at least 12 characters. Nothing was created.' }
if ($password -match '["''\s]') { throw 'Avoid spaces and quotes in the password. Nothing was created.' }

New-Item -ItemType Directory -Force -Path $keyDir | Out-Null

& keytool -genkeypair -v -keystore $jks -alias upload -keyalg RSA -keysize 2048 `
  -validity 10000 -storetype PKCS12 -storepass $password -keypass $password `
  -dname 'CN=Hadayah Live, OU=Mobile, O=Hadayah, L=Al Khobar, ST=Eastern Province, C=SA'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $jks)) { throw 'keytool failed. Nothing was written to key.properties.' }

# Gradle reads this file as Java properties, so use forward slashes in the path.
$storeFile = $jks -replace '\\', '/'
@(
  "storePassword=$password"
  "keyPassword=$password"
  'keyAlias=upload'
  "storeFile=$storeFile"
) | Set-Content -Path $props -Encoding ASCII

Write-Host ''
Write-Host "Keystore:       $jks"
Write-Host "key.properties: $props  (git-ignored)"
Write-Host ''
Write-Host 'Fingerprints (needed for the Google API key restriction):'
& keytool -list -v -keystore $jks -alias upload -storepass $password |
  Select-String -Pattern 'SHA1:|SHA256:' | ForEach-Object { $_.Line.Trim() }
Write-Host ''
Write-Host 'NEXT: copy upload-keystore.jks and the password to two safe places now.'
Write-Host 'Then tell Claude "the upload key is ready" (do not send the password).'
$password = $null; $again = $null
