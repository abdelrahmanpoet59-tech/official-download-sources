<#
.SYNOPSIS
  Compares an HTTP(S) URL or host with the exact hosts recorded in the dataset.

.DESCRIPTION
  Normalizes Unicode host names, a leading www. and trailing DNS dots.
  Unlisted subdomains do not inherit an official or reported verdict.
  Does not visit the URL, follow redirects, verify a repository path, or scan a file.

.EXAMPLE
  .\Test-DownloadSite.ps1 -Url https://7zip.com/download.html
.EXAMPLE
  .\Test-DownloadSite.ps1 -Url obsproject.com
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Url,
  [string]$DataDir = (Join-Path $PSScriptRoot '..\data')
)

$ErrorActionPreference = 'Stop'
function Get-RecordedHost([string]$Value) {
  $value = $Value.Trim()
  if (-not $value -or $value -match '[\s\\]' -or $value.StartsWith('/')) {
    throw 'Use an HTTP(S) URL or a host without credentials, spaces or backslashes.'
  }
  $candidate = if ($value -match '^[a-z][a-z0-9+.-]*://') { $value } else { "https://$value" }
  $parsed = $null
  if ($candidate -notmatch '^https?://[^/]' -or
      -not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$parsed) -or
      $parsed.Scheme -notin @('http', 'https') -or $parsed.UserInfo -or -not $parsed.Host) {
    throw 'Use an HTTP(S) URL or a host without credentials.'
  }
  return ($parsed.IdnHost.ToLowerInvariant().TrimEnd('.') -replace '^www\.', '')
}

try { $hostName = Get-RecordedHost $Url }
catch {
  Write-Host 'INVALID   Use an HTTP(S) URL or host without credentials, spaces or backslashes.' -ForegroundColor Yellow
  exit 3
}

$software  = Get-Content -LiteralPath (Join-Path $DataDir 'software.json')  -Raw -Encoding UTF8 | ConvertFrom-Json
$impostors = Get-Content -LiteralPath (Join-Path $DataDir 'impostors.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Test-RecordedHost([string]$h, [string]$d) {
  if (-not $d) { return $false }
  # A report or publisher listing covers only the host it names.
  return $h -eq (Get-RecordedHost $d)
}

Write-Host 'Scope    : Exact recorded host only; shared-host URL paths and redirects are not verified.'
Write-Host 'Limits   : No live ownership check or malware verdict. Record dates are not a freshness guarantee.'

$bad = $impostors | Where-Object { Test-RecordedHost $hostName $_.impostor_domain }
if ($bad) {
  foreach ($b in $bad) {
    Write-Host "REPORTED  $hostName  ($($b.classification)) - source report concerning $($b.software)" -ForegroundColor Red
    Write-Host "Official : $($b.official_domains -join ', ')"
    Write-Host "Source   : $($b.source_name)  $($b.source_url)"
    $reportDate = if ($b.first_reported) { $b.first_reported } else { '(not recorded)' }
    Write-Host "Reported : $reportDate (as recorded in the dataset)"
  }
  exit 2
}

$good = $software | Where-Object { $_.official_domain -and (Test-RecordedHost $hostName $_.official_domain) }
if ($good) {
  Write-Host "OFFICIAL  $hostName matches a recorded official host for: $(($good | ForEach-Object name) -join ', ')" -ForegroundColor Green
  foreach ($entry in $good) {
    $checked = if ($entry.checked) { $entry.checked } else { '(not recorded)' }
    Write-Host "Recorded : $($entry.name) - $checked"
    if ($entry.official_site) { Write-Host "Source   : $($entry.official_site)" }
  }
  exit 0
}

Write-Host "UNKNOWN   $hostName is not in the dataset. That is not a verdict." -ForegroundColor Yellow
Write-Host 'Find the publisher''s own site or repository and confirm the specific download source.'
exit 1
