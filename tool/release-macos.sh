#!/usr/bin/env bash
# macOS packages of a Cloodsy S3 GUI release, built on the Mac (tool/release.ps1
# -Platforms macos copies the sources over and runs this over SSH;
# docs/RELEASE.md): for Apple Silicon (arm64) and Intel (x64), the .dmg (first
# install) and the updater's .app.tar.gz with its signature.
#
#   bash tool/release-macos.sh <version> <out dir>     (the updater key on stdin)
#
# The key is read from stdin into the environment of the build, never written
# to the Mac's disk. Without an Apple Developer ID the app is signed ad hoc
# ("-"), not notarized: macOS warns on first open. Set APPLE_SIGNING_IDENTITY
# (and the notarization variables Tauri reads) to sign it for real.
set -euo pipefail
fail() { echo "release-macos: $*" >&2; exit 1; }
[[ $# -eq 2 ]] || fail "usage: release-macos.sh <version> <out dir>  (updater key on stdin)"
version=$1
out=$2
root=$(cd "$(dirname "$0")/.." && pwd)

# An SSH command gets no login shell: load rustup's cargo and Homebrew's Node.
# shellcheck disable=SC1091
[[ -s $HOME/.cargo/env ]] && source "$HOME/.cargo/env"
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v cargo >/dev/null || fail "no cargo (install Rust with rustup)"
command -v npm >/dev/null || fail "no npm (install Node)"
export CARGO_TARGET_DIR=${CLOODSY_S3_GUI_MAC_TARGET:-$HOME/Library/Caches/cloodsy-s3-gui-target-macos}

# PowerShell ends what it pipes to ssh with CRLF: drop the CR.
TAURI_SIGNING_PRIVATE_KEY=$(tr -d '\r')
[[ -n $TAURI_SIGNING_PRIVATE_KEY ]] || fail "no updater key on stdin"
export TAURI_SIGNING_PRIVATE_KEY TAURI_SIGNING_PRIVATE_KEY_PASSWORD=''

pkg_version=$(node -p "require('$root/package.json').version")
[[ $pkg_version == "$version" ]] || fail "package.json is $pkg_version, not $version"
mkdir -p "$out"

# tauri.conf.json keeps bundling off (Windows has its own setup); a release
# turns it on here, with the updater's signed artifacts.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config=$tmp/release.json
echo '{"bundle":{"active":true,"createUpdaterArtifacts":true,"targets":["app","dmg"],"macOS":{"signingIdentity":"-"}}}' >"$config"

cd "$root"
npm ci --silent --no-audit --no-fund
shopt -s nullglob
for pair in aarch64:arm64 x86_64:x64; do
  triple=${pair%%:*}-apple-darwin
  arch=${pair##*:}
  rustup target list --installed | grep -qx "$triple" || rustup target add "$triple"
  bundle=$CARGO_TARGET_DIR/$triple/release/bundle
  rm -rf "$bundle/dmg" "$bundle/macos"
  npm run tauri build -- --target "$triple" --config "$config"
  # Tauri names them "<productName>_<version>_<arch>.dmg" and "<productName>.app.tar.gz".
  dmgs=("$bundle"/dmg/*_"${version}"_*.dmg)
  tars=("$bundle"/macos/*.app.tar.gz)
  [[ ${#dmgs[@]} -eq 1 ]] || fail "expected one .dmg in $bundle/dmg"
  [[ ${#tars[@]} -eq 1 ]] || fail "expected one .app.tar.gz in $bundle/macos"
  [[ -f ${tars[0]}.sig ]] || fail "no updater signature next to ${tars[0]}"
  name=cloodsy-s3-gui-$version-macos-$arch
  rm -f "$out/$name".*
  cp "${dmgs[0]}" "$out/$name.dmg"
  cp "${tars[0]}" "$out/$name.app.tar.gz"
  cp "${tars[0]}.sig" "$out/$name.app.tar.gz.sig"
done
echo "macos packages in $out:"
ls -l "$out"/cloodsy-s3-gui-"$version"-macos-*
