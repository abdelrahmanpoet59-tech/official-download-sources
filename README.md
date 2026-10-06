# Official Download Sources

An open, machine-readable list of where popular software is **officially** downloaded, the SHA-256 of the publisher's own files, the code-signing name Windows should show, the winget ID, and domains that credible sources have flagged as impostors.

Search results and ads put look-alike sites next to real projects. In January 2026 an unofficial `7zip.com` served a trojanised installer for about ten days. This dataset helps you check a download before you run it.

Maintained by [Abdelrahman Mohammed](https://softwares-academy.com/about/) at [Softwares Academy](https://softwares-academy.com/how-we-verify/), which publishes the same data per program with notes.

## What's in it

| File | Contents |
|---|---|
| [`data/software.json`](data/software.json) | One record per program: official site and domain, download page, source repository, winget ID, version, release date, licence, expected signer, files with SHA-256, and the date the data was checked. |
| [`data/impostors.json`](data/impostors.json) | Domains that a publisher, security vendor, CERT or major outlet has named as fake, unofficial or malicious, each with its source link. |
| [`tools/Test-Download.ps1`](tools/Test-Download.ps1) | Checks a downloaded file against the dataset (SHA-256 plus Authenticode signer). |
| [`tools/Test-DownloadSite.ps1`](tools/Test-DownloadSite.ps1) | Tells you whether a site is the official one, a reported impostor, or unknown. Handles look-alike Unicode domains. |
| [`schema/`](schema) | JSON Schemas for both data files. |

## Check a file in 10 seconds (Windows PowerShell)

```powershell
# from a clone of this repository
.\tools\Test-Download.ps1 -Path "$HOME\Downloads\rufus-4.15.exe"
```

Check a site before you download:

```powershell
.\tools\Test-DownloadSite.ps1 -Url https://7zip.com/
# REPORTED  7zip.com  (reported-malicious) - impersonates 7-Zip
```

Possible results for a file:

- **MATCH**: the file's SHA-256 equals the hash the publisher listed for that release.
- **MISMATCH**: the file name belongs to a listed release but the bytes differ. Don't run it. Download it again from the official site shown.
- **UNKNOWN**: the file isn't in the dataset. That is not a verdict; compare the hash with the publisher's own release page.

No PowerShell? `certutil -hashfile file.exe SHA256` on Windows, `shasum -a 256 file` on macOS, `sha256sum file` on Linux. A browser version that never uploads the file is at [softwares-academy.com/sha256-checker](https://softwares-academy.com/sha256-checker/).

## What a match does and does not mean

A matching hash proves the bytes are identical to the file the publisher hashed. It does **not** prove the software is free of bugs or malware, and an unsigned file is not automatically unsafe (many open-source projects don't sign). The signer field records what Windows reported when we checked; certificates change between releases.

## How entries are checked

- Official domains come from the publisher's own site, repository or store listing.
- Hashes come from the publisher (release notes, `SHA256SUMS`, or GitHub's release asset digest) and carry the date they were recorded. Releases move on; an old hash is only valid for that old file.
- Impostor domains are listed **only** when a cited source names them. The `classification` field says what the source claimed: `reported-malicious`, `unofficial-warned` or `typosquat-reported`. We do not visit those domains to "confirm" them.

## Use the data

```text
https://raw.githubusercontent.com/abdelrahmanpoet59-tech/official-download-sources/main/data/software.json
https://raw.githubusercontent.com/abdelrahmanpoet59-tech/official-download-sources/main/data/impostors.json
```

Data is licensed [CC BY 4.0](LICENSE-DATA): use it anywhere, including commercially, with attribution to "Official Download Sources by Softwares Academy". Code is [MIT](LICENSE).

## Corrections and new entries

Open an issue or a pull request. For an impostor domain, include a public source that names it. For a hash, link the publisher page it comes from. See [CONTRIBUTING.md](CONTRIBUTING.md).

If a listing concerns your domain and you believe it is wrong, open an issue with the evidence and it will be reviewed.
