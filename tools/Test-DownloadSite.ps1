<#
.SYNOPSIS
  Tells you whether a download site is the official one, a reported impostor, or unknown.

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
$u = if ($Url -match '^[a-z]+://') { $Url } else { "https://$Url" }
$hostName = ([Uri]$u).IdnHost.ToLowerInvariant() -replace '^www\.', ''

$software  = Get-Content -LiteralPath (Join-Path $DataDir 'software.json')  -Raw -Encoding UTF8 | ConvertFrom-Json
$impostors = Get-Content -LiteralPath (Join-Path $DataDir 'impostors.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Test-Under([string]$h, [string]$d) { $d = $d.ToLowerInvariant() -replace '^www\.', ''; return ($h -eq $d -or $h.EndsWith(".$d")) }

$bad = $impostors | Where-Object { Test-Under $hostName $_.impostor_domain }
if ($bad) {
  foreach ($b in $bad) {
    Write-Host "REPORTED  $hostName  ($($b.classification)) - impersonates $($b.software)" -ForegroundColor Red
    Write-Host "Official : $($b.official_domains -join ', ')"
    Write-Host "Source   : $($b.source_name)  $($b.source_url)"
  }
  exit 2
}

$good = $software | Where-Object { $_.official_domain -and (Test-Under $hostName $_.official_domain) }
if ($good) {
  Write-Host "OFFICIAL  $hostName is the official site for: $(($good | ForEach-Object name) -join ', ')" -ForegroundColor Green
  exit 0
}

Write-Host "UNKNOWN   $hostName is not in the dataset. That is not a verdict." -ForegroundColor Yellow
Write-Host 'Start from the project''s own repository or Wikipedia article and follow its download link.'
exit 1
