<#
.SYNOPSIS
  Checks a downloaded installer against the official-download-sources dataset.

.DESCRIPTION
  Computes the file's SHA-256 and looks it up in data/software.json.
  - MATCH:     the hash equals a publisher-listed hash for a known release.
  - MISMATCH:  the file name belongs to a known release but the hash differs. Do not run it;
               download it again from the official site listed.
  - UNKNOWN:   the file is not in the dataset. That is not a verdict; the dataset is small.
  It also prints the Authenticode signer Windows reports, next to the signer we recorded.
  A matching hash proves the bytes equal the publisher's file. It is not a malware scan.

.EXAMPLE
  .\Test-Download.ps1 -Path "$HOME\Downloads\rufus-4.15.exe"

.EXAMPLE
  # Use the dataset straight from GitHub instead of a local copy
  .\Test-Download.ps1 -Path .\7z2501-x64.exe -DataUrl https://raw.githubusercontent.com/abdelrahmanpoet59-tech/official-download-sources/main/data/software.json
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [string]$DataPath = (Join-Path $PSScriptRoot '..\data\software.json'),
  [string]$DataUrl
)

$ErrorActionPreference = 'Stop'
$file = Get-Item -LiteralPath $Path
$hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

if ($DataUrl) {
  $data = Invoke-RestMethod -Uri $DataUrl
} else {
  $data = Get-Content -LiteralPath $DataPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$byHash = $null; $byName = $null
foreach ($entry in $data) {
  foreach ($f in @($entry.files)) {
    if (-not $f) { continue }
    if ($f.sha256 -eq $hash) { $byHash = @{ entry = $entry; file = $f } }
    elseif ($f.filename -ieq $file.Name) { $byName = @{ entry = $entry; file = $f } }
  }
}

$sig = Get-AuthenticodeSignature -LiteralPath $file.FullName
$signer = if ($sig.SignerCertificate) { $sig.SignerCertificate.GetNameInfo('SimpleName', $false) } else { '(not signed)' }

Write-Host ''
Write-Host "File     : $($file.Name)"
Write-Host "SHA-256  : $hash"
Write-Host "Signature: $($sig.Status)  $signer"
Write-Host ''

if ($byHash) {
  $e = $byHash.entry
  Write-Host "MATCH  $($e.name) $($e.version) - $($byHash.file.build)" -ForegroundColor Green
  Write-Host "Official site : $($e.official_site)"
  if ($e.signer) { Write-Host "Expected signer: $($e.signer)" }
  if ($e.checked) { Write-Host "Hash recorded  : $($e.checked)" }
  Write-Host "Details        : $($e.details_url)"
  exit 0
}
elseif ($byName) {
  $e = $byName.entry
  Write-Host "MISMATCH  '$($file.Name)' is listed for $($e.name) $($e.version), but the hash is different." -ForegroundColor Red
  Write-Host "Expected : $($byName.file.sha256)"
  Write-Host "Do not run this file. Download it again from: $($e.official_site)"
  exit 2
}
else {
  Write-Host 'UNKNOWN  This file is not in the dataset. That is not a verdict.' -ForegroundColor Yellow
  Write-Host 'Compare the hash with the value on the publisher''s own release page.'
  exit 1
}
