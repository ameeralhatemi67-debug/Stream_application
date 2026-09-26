param([Parameter(Mandatory=$true)][string]$SupabaseCli)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runtime = Join-Path $repo 'brief/.runtime/wave4v2'
$config = Join-Path $runtime 'supabase/config.toml'
if (Test-Path -LiteralPath $config) { throw 'Runtime already exists. Inspect it; this script never resets or overwrites a stack.' }
$busy = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -ge 55920 -and $_.LocalPort -le 55929 }
if ($busy) { throw 'Wave4v2 port range is occupied. Do not stop its owner.' }
New-Item -ItemType Directory -Path (Split-Path $config) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'brief/evidence/2026-09-26/p6s-wave4v2/local-stack.toml') -Destination $config
Copy-Item -LiteralPath (Join-Path $repo 'supabase/migrations') -Destination (Split-Path $config) -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'supabase/tests') -Destination (Split-Path $config) -Recurse
$env:DO_NOT_TRACK = '1'
& $SupabaseCli start --workdir $runtime --exclude studio,pgadmin-schema-diff,migra,postgres-meta,logflare,vector,imgproxy,edge-runtime,supavisor,inbucket *> (Join-Path $runtime 'start-private.log')
if ($LASTEXITCODE -ne 0) { throw 'Local start failed; inspect the ignored start-private.log. It may contain local credentials.' }
$statusText = & $SupabaseCli status --workdir $runtime -o json 2> (Join-Path $runtime 'status-private.log')
if ($LASTEXITCODE -ne 0) { throw 'Local status failed.' }
$status = ($statusText -join "`n") | ConvertFrom-Json
if ($status.API_URL -ne 'http://127.0.0.1:55921') { throw 'Refusing unexpected backend identity.' }
@{
  SUPABASE_URL=$status.API_URL
  SUPABASE_ANON_KEY=$status.ANON_KEY
  YOUTUBE_API_KEY=''
  OAUTH_REDIRECT_URL='sa.hadayah.streamerapp.wave4v2://login-callback'
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtime 'defines.no-key.json') -Encoding utf8
Write-Output 'Local diagnostic backend: Streamer_wave4v2 at 127.0.0.1:55921. No Google OAuth or YouTube test key provisioned.'
Write-Output 'Only the anon key is in the ignored no-key build configuration. No hosted project was linked or operated.'
