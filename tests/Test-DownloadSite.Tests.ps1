<# Offline regression tests. Runs only this repository's site checker, never an installer. #>
[CmdletBinding()]
param([string]$PowerShellPath = (Get-Process -Id $PID).Path)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\tools\Test-DownloadSite.ps1'
$fixturePath = Join-Path $PSScriptRoot 'fixtures\data'
$cases = @(
  @{ Input = 'official.example'; Code = 0; Text = 'OFFICIAL'; Detail = '2026-10-01' },
  @{ Input = ' HTTPS://WWW.OFFICIAL.EXAMPLE./download '; Code = 0; Text = 'OFFICIAL' },
  @{ Input = 'http://official.example:80/download?ref=1#part'; Code = 0; Text = 'OFFICIAL' },
  @{ Input = 'listed.official.example'; Code = 0; Text = 'OFFICIAL' },
  @{ Input = 'unlisted.official.example'; Code = 1; Text = 'UNKNOWN' },
  @{ Input = 'child.listed.official.example'; Code = 1; Text = 'UNKNOWN' },
  @{ Input = 'official.example.evil.example'; Code = 1; Text = 'UNKNOWN' },
  @{ Input = 'notofficial.example'; Code = 1; Text = 'UNKNOWN' },
  @{ Input = 'https://official.example/path/to/another-project'; Code = 0; Text = 'OFFICIAL'; Detail = 'shared-host URL paths and redirects are not verified' },
  @{ Input = 'reported.example'; Code = 2; Text = 'REPORTED'; Detail = '2026-09-30' },
  @{ Input = 'WWW.REPORTED.EXAMPLE.'; Code = 2; Text = 'REPORTED'; Detail = 'https://publisher.example/report' },
  @{ Input = 'child.reported.example'; Code = 1; Text = 'UNKNOWN' },
  @{ Input = 'https://xn--bcher-kva.example'; Code = 0; Text = 'OFFICIAL' },
  @{ Input = ('https://b' + [char]0x00fc + 'cher.example'); Code = 0; Text = 'OFFICIAL' },
  @{ Input = ('https://' + [char]0x043e + 'fficial.example'); Code = 1; Text = 'UNKNOWN' },
  @{ Input = 'undated.example'; Code = 0; Text = 'OFFICIAL'; Detail = '(not recorded)' },
  @{ Input = 'undated.reported.example'; Code = 2; Text = 'REPORTED'; Detail = '(not recorded)' },
  @{ Input = 'unknown.example'; Code = 1; Text = 'UNKNOWN' },
  @{ Input = 'ftp://official.example/file'; Code = 3; Text = 'INVALID' },
  @{ Input = 'file:///official.example'; Code = 3; Text = 'INVALID' },
  @{ Input = 'https://user:password@official.example'; Code = 3; Text = 'INVALID' },
  @{ Input = 'https://official.example@evil.example'; Code = 3; Text = 'INVALID' },
  @{ Input = 'https://official.example\@evil.example'; Code = 3; Text = 'INVALID' },
  @{ Input = 'https:///official.example'; Code = 3; Text = 'INVALID' },
  @{ Input = '//official.example/path'; Code = 3; Text = 'INVALID' },
  @{ Input = 'not a host'; Code = 3; Text = 'INVALID' },
  @{ Input = '   '; Code = 3; Text = 'INVALID' },
  @{ Input = 'https://'; Code = 3; Text = 'INVALID' },
  @{ Input = 'javascript:alert(1)'; Code = 3; Text = 'INVALID' }
)

# Guard the test contract: the site checker must not make requests.
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Checker has PowerShell parse errors.' }
$networkCommands = @($ast.FindAll({ param($node)
  $node -is [System.Management.Automation.Language.CommandAst] -and
  $node.GetCommandName() -in @('Invoke-WebRequest', 'Invoke-RestMethod', 'curl', 'wget')
}, $true))
if ($networkCommands.Count) { throw 'Site checker unexpectedly contains a network command.' }

foreach ($case in $cases) {
  $info = New-Object System.Diagnostics.ProcessStartInfo
  $info.FileName = $PowerShellPath
  # The test cases contain no double quotes; arguments are passed as data.
  $info.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Url "{1}" -DataDir "{2}"' -f $scriptPath, $case.Input, $fixturePath
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($info)
  $output = $process.StandardOutput.ReadToEnd()
  $errors = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne $case.Code -or $output -notmatch $case.Text -or $errors) {
    throw "Input '$($case.Input)': expected code $($case.Code)/$($case.Text), got $($process.ExitCode). $output $errors"
  }
  if ($case.Detail -and -not $output.Contains($case.Detail)) { throw "Missing context for '$($case.Input)': $output" }
  if ($case.Code -ne 3 -and -not $output.Contains('No live ownership check or malware verdict')) { throw 'Missing result limits.' }
  if ($case.Code -eq 3 -and $output.Contains('password')) { throw 'Invalid input leaked credentials.' }
  $process.Dispose()
}
Write-Output "PASS: $($cases.Count) offline cases using $PowerShellPath"
