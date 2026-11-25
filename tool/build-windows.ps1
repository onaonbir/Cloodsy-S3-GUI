<#
.SYNOPSIS
  Builds the Windows setup of Cloodsy S3 GUI: dist-release/cloodsy-s3-gui-<version>-windows-x64-setup.exe.

.DESCRIPTION
  Our own setup (installer/README.md) instead of Tauri's NSIS bundle:
    1. the GUI (npm run tauri build -- --no-bundle) -> target/release/cloodsy-s3.exe
    2. the setup window's page (npm run build:setup) -> dist-setup/
    3. the setup exe (installer/setup, the page embedded) -> target/release/cloodsy-s3-gui-setup.exe
    4. the GUI and its licence texts packed into the setup exe (installer/pack)
  The version is package.json's (the GUI's only version). Run on Windows from
  any folder: pwsh tool/build-windows.ps1
#>
param(
    # Reuse target/release/cloodsy-s3.exe as it is (only the setup is rebuilt).
    [switch]$SkipApp
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host "build-windows: $text" -ForegroundColor Red; exit 1 }
function Need($path, $what) { if (-not (Test-Path $path)) { Fail "$what is missing: $path" } }

$Version = (Get-Content (Join-Path $Root 'package.json') -Raw | ConvertFrom-Json).version
if (-not $Version) { Fail 'no version in package.json' }
$Out = Join-Path $Root 'dist-release'
New-Item -ItemType Directory -Force $Out | Out-Null
$Setup = Join-Path $Out "cloodsy-s3-gui-$Version-windows-x64-setup.exe"
Write-Host "Cloodsy S3 GUI $Version -> $Setup" -ForegroundColor Green

Push-Location $Root
try {
    if (-not $SkipApp) {
        Step 'The GUI (tauri build, no bundle)'
        npm run tauri build -- --no-bundle
        if ($LASTEXITCODE) { Fail 'the GUI build failed' }
    }
    $appExe = Join-Path $Root 'target/release/cloodsy-s3.exe'
    Need $appExe 'The GUI'

    Step 'The setup window (src-setup -> dist-setup)'
    npm run build:setup
    if ($LASTEXITCODE) { Fail 'the setup page build failed' }

    Step 'The setup exe (installer/setup)'
    cargo build --release -p cloodsy_s3_gui_setup --features custom-protocol
    if ($LASTEXITCODE) { Fail 'the setup build failed' }
    $stub = Join-Path $Root 'target/release/cloodsy-s3-gui-setup.exe'
    Need $stub 'The setup'

    Step 'Packing'
    # What the setup installs: everything in this folder, paths kept.
    $stage = Join-Path $Root 'target/windows-setup-stage'
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force (Join-Path $stage 'licenses') | Out-Null
    Copy-Item $appExe (Join-Path $stage 'cloodsy-s3.exe')
    Copy-Item (Join-Path $Root 'LICENSE') (Join-Path $stage 'licenses/LICENSE.txt')
    Copy-Item (Join-Path $Root 'assets/fonts/OFL-*.txt') (Join-Path $stage 'licenses')
    Remove-Item $Setup, "$Setup.sig" -ErrorAction SilentlyContinue
    cargo run -q --release -p cloodsy_s3_gui_pack -- $stub $Setup cloodsy-s3-gui $Version $stage
    if ($LASTEXITCODE) { Fail 'packing the setup failed' }
    Remove-Item $stage -Recurse -Force

    # The updater signature (minisign, "$Setup.sig"): the Tauri updater checks
    # it with the public key in tauri.conf.json before it runs the setup with
    # /P /UPDATE /R. The private key never enters the repository: its path is
    # $env:CLOODSY_S3_GUI_UPDATER_KEY (or tool/release.local.ps1).
    $local = Join-Path $PSScriptRoot 'release.local.ps1'
    if (Test-Path $local) { . $local }
    $key = $env:CLOODSY_S3_GUI_UPDATER_KEY
    if ($key -and (Test-Path $key)) {
        Step 'Updater signature'
        $env:TAURI_SIGNING_PRIVATE_KEY = Get-Content $key -Raw
        $env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD = ''
        try {
            npm run tauri signer sign -- $Setup | Out-Null
            if ($LASTEXITCODE) { Fail 'signing the setup for the updater failed' }
        } finally {
            Remove-Item Env:TAURI_SIGNING_PRIVATE_KEY, Env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD -ErrorAction SilentlyContinue
        }
        Need "$Setup.sig" 'The updater signature'
    } else {
        Write-Host "No updater key (CLOODSY_S3_GUI_UPDATER_KEY): the setup is not signed for the updater (fine for a local build, not for a release)." -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}

$size = [math]::Round((Get-Item $Setup).Length / 1MB, 1)
Write-Host "`nBuilt: $Setup ($size MB)" -ForegroundColor Green
