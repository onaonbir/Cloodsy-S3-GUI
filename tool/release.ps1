<#
.SYNOPSIS
  Builds a Cloodsy S3 GUI release on this computer and, with -Publish, uploads
  it to a draft GitHub release. No CI: every package is built locally
  (docs/RELEASE.md).

.DESCRIPTION
  1. Builds the chosen platforms into dist-release/:
       windows  this PC (tool/build-windows.ps1: our setup + updater signature)
       linux    WSL (tool/release-linux.sh: AppImage + .deb)
       macos    the Mac over SSH (tool/release-macos.sh: .dmg + updater .app.tar.gz,
                Apple Silicon and Intel)
  2. Writes latest.json (what the app's updater reads, for the platforms built
     in this run) and SHA256SUMS.txt.
  3. With -Publish, creates the GitHub release v<version> as a DRAFT and uploads
     the files, latest.json last. A person reviews and publishes the draft on
     GitHub; only then does the updater see it. Without -Publish nothing leaves
     this computer: it prints what it would upload.

  The version is package.json's. The updater key is not in this repository: its
  path is $env:CLOODSY_S3_GUI_UPDATER_KEY, and it reaches WSL and the Mac only
  through environment variables and stdin, never their disks. The Mac is
  $env:CLOODSY_S3_GUI_MAC_HOST (or -MacHost). Both can be set in
  tool/release.local.ps1 (ignored by git; see release.local.example.ps1).

.PARAMETER Platforms
  windows, linux, macos (default: all three).

.PARAMETER SkipApp
  Passed to build-windows.ps1: reuse target/release/cloodsy-s3.exe as it is.

.PARAMETER SkipBuild
  Build nothing; write latest.json and SHA256SUMS.txt from the packages already
  in dist-release/ (for the chosen platforms) and publish them with -Publish.

.PARAMETER Target
  With -Publish: the branch or commit gh tags v<version> from. Without it the
  tag v<version> must already exist on GitHub (gh --verify-tag).

.EXAMPLE
  pwsh tool/release.ps1
  pwsh tool/release.ps1 -Platforms linux,macos
  pwsh tool/release.ps1 -SkipBuild -Publish
#>
param(
    [ValidateSet('windows', 'linux', 'macos')]
    [string[]]$Platforms = @('windows', 'linux', 'macos'),
    [switch]$SkipApp,
    [switch]$SkipBuild,
    [switch]$Publish,
    [string]$Target = '',
    [string]$Repo = 'onaonbir/Cloodsy-S3-GUI',
    # user@host with an SSH key login; default $env:CLOODSY_S3_GUI_MAC_HOST.
    [string]$MacHost = '',
    # The Mac's build folder: src/ (replaced on every build) and out/<version>/.
    [string]$MacDir = '~/Workspace/cloodsy-s3-gui-release'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$LocalSettings = Join-Path $PSScriptRoot 'release.local.ps1'
if (Test-Path $LocalSettings) { . $LocalSettings }
$UpdaterKey = $env:CLOODSY_S3_GUI_UPDATER_KEY
if (-not $MacHost) { $MacHost = $env:CLOODSY_S3_GUI_MAC_HOST }

function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host "release: $text" -ForegroundColor Red; exit 1 }
function Need($path, $what) { if (-not (Test-Path -LiteralPath $path)) { Fail "$what is missing: $path" } }
function Write-Utf8($path, $text) {
    # UTF-8 without a BOM and with LF line ends (latest.json, SHA256SUMS.txt).
    [IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

# ── version and output ───────────────────────────────────────────────────
$Version = (Get-Content (Join-Path $Root 'package.json') -Raw | ConvertFrom-Json).version
if (-not $Version) { Fail 'no version in package.json' }
$Tag = "v$Version"
$Out = Join-Path $Root 'dist-release'
New-Item -ItemType Directory -Force $Out | Out-Null
$Platforms = @($Platforms | Select-Object -Unique)
Write-Host "Cloodsy S3 GUI $Version ($($Platforms -join ', ')) -> $Out" -ForegroundColor Green
if (-not $SkipBuild) {
    if (-not $UpdaterKey) { Fail 'no updater key: set CLOODSY_S3_GUI_UPDATER_KEY (tool/release.local.ps1)' }
    Need $UpdaterKey 'The updater key'
    if ($Platforms -contains 'macos' -and -not $MacHost) { Fail 'no Mac: set CLOODSY_S3_GUI_MAC_HOST (tool/release.local.ps1) or pass -MacHost' }
}

# What each platform leaves in dist-release/: the files to upload, and the
# updater entries of latest.json (platform key -> package with a .sig next to it).
# (Not $P: PowerShell names are case-insensitive and $p is the platform loop variable.)
$Base = "cloodsy-s3-gui-$Version"
$Layout = [ordered]@{
    windows = @{ files = @("$Base-windows-x64-setup.exe", "$Base-windows-x64-setup.exe.sig")
                 updater = [ordered]@{ 'windows-x86_64' = "$Base-windows-x64-setup.exe" } }
    linux   = @{ files = @("$Base-linux-x64.AppImage", "$Base-linux-x64.AppImage.sig", "$Base-linux-x64.deb")
                 optional = @("$Base-linux-x64.deb.sig")
                 updater = [ordered]@{ 'linux-x86_64' = "$Base-linux-x64.AppImage"; 'linux-x86_64-deb' = "$Base-linux-x64.deb" } }
    macos   = @{ files = @("$Base-macos-arm64.dmg", "$Base-macos-arm64.app.tar.gz", "$Base-macos-arm64.app.tar.gz.sig",
                           "$Base-macos-x64.dmg", "$Base-macos-x64.app.tar.gz", "$Base-macos-x64.app.tar.gz.sig")
                 updater = [ordered]@{ 'darwin-aarch64' = "$Base-macos-arm64.app.tar.gz"; 'darwin-x86_64' = "$Base-macos-x64.app.tar.gz" } }
}

# ── builds ───────────────────────────────────────────────────────────────
function Build-Windows {
    Step 'Windows (tool/build-windows.ps1)'
    # It reads the same updater key and signs the setup for the updater.
    & (Join-Path $PSScriptRoot 'build-windows.ps1') -SkipApp:$SkipApp
    if ($LASTEXITCODE) { Fail 'the Windows build failed' }
}

function Build-Linux {
    Step 'Linux in WSL (tool/release-linux.sh: AppImage, .deb)'
    $wslRoot = (wsl.exe -e wslpath -a ($Root -replace '\\', '/')).Trim()
    $wslOut = (wsl.exe -e wslpath -a ($Out -replace '\\', '/')).Trim()
    if (-not $wslRoot -or -not $wslOut) { Fail 'WSL is not reachable (wsl.exe -e wslpath)' }
    $env:WSLENV = 'TAURI_SIGNING_PRIVATE_KEY/u:TAURI_SIGNING_PRIVATE_KEY_PASSWORD/u'
    $env:TAURI_SIGNING_PRIVATE_KEY = (Get-Content $UpdaterKey -Raw).Trim()
    $env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD = ''
    try {
        wsl.exe -e bash "$wslRoot/tool/release-linux.sh" $Version $wslOut
        if ($LASTEXITCODE) { Fail 'the Linux build failed' }
    } finally {
        Remove-Item Env:TAURI_SIGNING_PRIVATE_KEY, Env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD, Env:WSLENV -ErrorAction SilentlyContinue
    }
}

function Build-MacOS {
    Step "macOS on $MacHost (tool/release-macos.sh: .dmg, updater .app.tar.gz)"
    $ssh = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15')
    ssh @ssh $MacHost 'true'
    if ($LASTEXITCODE) { Fail "no SSH key login to $MacHost (ssh -o BatchMode=yes $MacHost)" }

    # The working tree (also what is not committed yet), without build output,
    # dependencies or the Flutter 2.x folders, to $MacDir/src.
    $skip = @('.git', 'target', 'node_modules', 'dist', 'dist-setup', 'dist-release', 'build', '.dart_tool',
        '.fvm', '.idea', 'android', 'ios', 'linux', 'macos', 'windows', 'web', 'snap')
    $items = @(Get-ChildItem $Root -Force | Where-Object { $_.Name -notin $skip } | ForEach-Object Name)
    $tarball = Join-Path ([IO.Path]::GetTempPath()) "cloodsy-s3-gui-src-$Version.tar.gz"
    try {
        & "$env:SystemRoot\System32\tar.exe" -czf $tarball -C $Root @items
        if ($LASTEXITCODE) { Fail 'packing the sources failed' }
        ssh @ssh $MacHost "mkdir -p $MacDir"
        if ($LASTEXITCODE) { Fail "creating $MacDir on the Mac failed" }
        scp -q @ssh $tarball "${MacHost}:$MacDir/src.tar.gz"
        if ($LASTEXITCODE) { Fail 'copying the sources to the Mac failed' }
    } finally {
        Remove-Item $tarball -ErrorAction SilentlyContinue
    }
    ssh @ssh $MacHost "rm -rf $MacDir/src && mkdir -p $MacDir/src && tar -xzf $MacDir/src.tar.gz -C $MacDir/src && rm $MacDir/src.tar.gz"
    if ($LASTEXITCODE) { Fail 'unpacking the sources on the Mac failed' }

    # The key travels on stdin, never on the command line or to the Mac's disk.
    (Get-Content $UpdaterKey -Raw).Trim() | ssh @ssh $MacHost "bash $MacDir/src/tool/release-macos.sh $Version $MacDir/out/$Version"
    if ($LASTEXITCODE) { Fail 'the macOS build failed' }
    Get-ChildItem $Out -Filter "$Base-macos-*" | Remove-Item
    scp -q @ssh "${MacHost}:$MacDir/out/$Version/$Base-macos-*" $Out
    if ($LASTEXITCODE) { Fail 'copying the macOS packages failed' }
}

if (-not $SkipBuild) {
    foreach ($p in $Platforms) {
        switch ($p) {
            'windows' { Build-Windows }
            'linux' { Build-Linux }
            'macos' { Build-MacOS }
        }
    }
}

# ── what was built ───────────────────────────────────────────────────────
Step 'Packages'
$files = @()
foreach ($p in $Platforms) {
    foreach ($f in $Layout[$p].files) { Need (Join-Path $Out $f) "The $p package" ; $files += $f }
    foreach ($f in @($Layout[$p].optional)) { if ($f -and (Test-Path (Join-Path $Out $f))) { $files += $f } }
}

# ── latest.json ──────────────────────────────────────────────────────────
# Notes: CHANGELOG.md's "## [<version>]" section, else "## [Unreleased]".
function Get-ChangelogSection($name) {
    $text = Get-Content (Join-Path $Root 'CHANGELOG.md') -Raw -ErrorAction SilentlyContinue
    if (-not $text) { return $null }
    $m = [regex]::Match($text, "(?ms)^## \[$([regex]::Escape($name))\][^\n]*\n(.*?)(?=^## |\z)")
    if ($m.Success) { return ($m.Groups[1].Value -replace "`r`n", "`n").Trim() }
    return $null
}
$notes = Get-ChangelogSection $Version
if (-not $notes) {
    Write-Host "CHANGELOG.md has no [$Version] section: the notes are [Unreleased]'s" -ForegroundColor Yellow
    $notes = Get-ChangelogSection 'Unreleased'
}
if (-not $notes) { $notes = "Cloodsy S3 GUI $Version" }

$download = "https://github.com/$Repo/releases/download/$Tag"
$updaterPlatforms = [ordered]@{}
foreach ($p in $Platforms) {
    foreach ($entry in $Layout[$p].updater.GetEnumerator()) {
        $sig = Join-Path $Out "$($entry.Value).sig"
        if (-not (Test-Path $sig)) { continue }   # e.g. a .deb without a signature
        $updaterPlatforms[$entry.Key] = [ordered]@{
            signature = (Get-Content $sig -Raw).Trim()
            url       = "$download/$($entry.Value)"
        }
    }
}
$latest = [ordered]@{
    version   = $Version
    notes     = $notes
    pub_date  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
    platforms = $updaterPlatforms
}
$latestFile = Join-Path $Out 'latest.json'
Write-Utf8 $latestFile (($latest | ConvertTo-Json -Depth 5) + "`n")
Write-Host "latest.json: $($updaterPlatforms.Keys -join ', ')"

# ── SHA256SUMS.txt ───────────────────────────────────────────────────────
$sumsFile = Join-Path $Out 'SHA256SUMS.txt'
$sums = foreach ($f in $files) {
    "$((Get-FileHash -Algorithm SHA256 (Join-Path $Out $f)).Hash.ToLowerInvariant())  $f"
}
Write-Utf8 $sumsFile (($sums -join "`n") + "`n")

# latest.json goes last: the updater must never see a version whose packages are not there yet.
$uploads = @($files) + 'SHA256SUMS.txt' + 'latest.json'
foreach ($f in $uploads) {
    $size = (Get-Item (Join-Path $Out $f)).Length
    Write-Host ('  {0,-60} {1,10:N1} MB' -f $f, ($size / 1MB))
}

# ── publish (a draft) ────────────────────────────────────────────────────
# The release page's text: the same notes as latest.json's.
$notesFile = Join-Path ([IO.Path]::GetTempPath()) "cloodsy-s3-gui-notes-$Version.md"
$tagArgs = if ($Target) { @('--target', $Target) } else { @('--verify-tag') }
$createArgs = @('release', 'create', $Tag, '--repo', $Repo, '--draft', '--title', "Cloodsy S3 GUI $Version",
    '--notes-file', $notesFile) + $tagArgs
if (-not $Publish) {
    Write-Host "`nNot published (no -Publish). It would run, in ${Out}:" -ForegroundColor Green
    Write-Host "  gh $($createArgs -join ' ')   (notes: the latest.json notes)"
    Write-Host "  gh release upload $Tag --repo $Repo --clobber <the files above but latest.json>"
    Write-Host "  gh release upload $Tag --repo $Repo --clobber latest.json"
    exit 0
}

Step "Draft release $Tag on github.com/$Repo"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail 'gh (GitHub CLI) is not installed' }
$existing = gh release view $Tag --repo $Repo --json isDraft 2>$null
if ($LASTEXITCODE -eq 0) {
    if (-not ($existing | ConvertFrom-Json).isDraft) { Fail "$Tag is already published on GitHub; raise the version instead of changing it" }
    Write-Host "$Tag exists as a draft: its files are replaced"
} else {
    Write-Utf8 $notesFile ($notes + "`n")
    gh @createArgs
    if ($LASTEXITCODE) { Fail "creating the draft release $Tag failed" }
}
Push-Location $Out
try {
    $first = @($uploads | Where-Object { $_ -ne 'latest.json' })
    gh release upload $Tag --repo $Repo --clobber @first
    if ($LASTEXITCODE) { Fail 'uploading the packages failed' }
    gh release upload $Tag --repo $Repo --clobber latest.json
    if ($LASTEXITCODE) { Fail 'uploading latest.json failed' }
} finally {
    Pop-Location
    Remove-Item $notesFile -ErrorAction SilentlyContinue
}
Write-Host "`n$Tag is a draft on https://github.com/$Repo/releases: check it and publish it there." -ForegroundColor Green
