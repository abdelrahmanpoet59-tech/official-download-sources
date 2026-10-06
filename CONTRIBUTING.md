# Contributing

Thanks for helping people download the real thing.

## Add or correct a program (`data/software.json`)

- `official_site` must be the publisher's own site, repository or store page.
- Every `sha256` must come from a publisher source: release notes, a `SHA256SUMS` file, a signed checksum file, or the GitHub release asset digest. Put that link in the pull request.
- Update `version`, `released` and `checked` together. Don't change a hash without changing the file name or version it belongs to.

## Add an impostor domain (`data/impostors.json`)

- Include a public `source_url` that **names the domain**: a publisher warning, a security-vendor report, a CERT advisory or a major news outlet.
- Pick the `classification` that matches what the source says. Don't upgrade "unofficial" to "malicious" without a source that says so.
- Don't include links that make the domain clickable, and never attach files from it.

## Disputes

If you operate a listed domain, open an issue with your evidence (for example, a statement from the software's publisher). Entries are removed when the cited source is withdrawn or corrected.

Validate before you open a pull request:

```powershell
Get-Content data\software.json -Raw | ConvertFrom-Json | Out-Null
Get-Content data\impostors.json -Raw | ConvertFrom-Json | Out-Null
```
