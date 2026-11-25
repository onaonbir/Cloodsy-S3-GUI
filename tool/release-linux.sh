#!/usr/bin/env bash
# Linux packages of a Cloodsy S3 GUI release, built in WSL (tool/release.ps1
# -Platforms linux calls this; docs/RELEASE.md): the AppImage (also the
# updater's package, signed) and the .deb.
#
#   bash tool/release-linux.sh <version> <out dir>
#
# Needs Rust, Node (nvm) and the Tauri Linux packages (libwebkit2gtk-4.1-dev,
# libayatana-appindicator3-dev, librsvg2-dev, libdbus-1-dev, patchelf).
# TAURI_SIGNING_PRIVATE_KEY (and its empty password) come from the environment
# (WSLENV); the key is never written to disk here.
#
# The build runs on a copy of the sources in the Linux file system: `npm ci` in
# the Windows checkout would replace its node_modules with Linux packages, and
# a Linux target directory of its own keeps the Windows build's target/ untouched.
set -euo pipefail
fail() { echo "release-linux: $*" >&2; exit 1; }
[[ $# -eq 2 ]] || fail "usage: release-linux.sh <version> <out dir>"
version=$1
out=$2
checkout=$(cd "$(dirname "$0")/.." && pwd)
root=${CLOODSY_S3_GUI_LINUX_SRC:-$HOME/.cache/cloodsy-s3-gui-release-src}
export CARGO_TARGET_DIR=${CLOODSY_S3_GUI_LINUX_TARGET:-$HOME/.cache/cloodsy-s3-gui-target-linux}

# `wsl.exe -e bash` starts no login shell: load rustup's cargo and WSL's own
# Node (nvm), never the Windows Node that WSL puts on the PATH.
# shellcheck disable=SC1091
[[ -s $HOME/.cargo/env ]] && source "$HOME/.cargo/env"
export NVM_DIR=${NVM_DIR:-$HOME/.nvm}
# shellcheck disable=SC1091
[[ -s $NVM_DIR/nvm.sh ]] && source "$NVM_DIR/nvm.sh" >/dev/null
case "$(command -v npm || true)" in
  "" | /mnt/*) fail "no Linux npm (install Node in WSL, e.g. with nvm)" ;;
esac
command -v cargo >/dev/null || fail "no cargo (install Rust in WSL with rustup)"
[[ -n ${TAURI_SIGNING_PRIVATE_KEY:-} ]] || fail "TAURI_SIGNING_PRIVATE_KEY is not set (the updater key; release.ps1 passes it)"
export TAURI_SIGNING_PRIVATE_KEY_PASSWORD=${TAURI_SIGNING_PRIVATE_KEY_PASSWORD:-}

pkg_version=$(node -p "require('$checkout/package.json').version")
[[ $pkg_version == "$version" ]] || fail "package.json is $pkg_version, not $version"
mkdir -p "$out" "$root"

# The Tauri sources only: no build output, no Flutter 2.x leftovers.
rsync -a --delete \
  --exclude /.git/ --exclude /target/ --exclude /node_modules/ \
  --exclude /dist/ --exclude /dist-setup/ --exclude /dist-release/ \
  --exclude /build/ --exclude /.dart_tool/ --exclude /.fvm/ --exclude /.idea/ \
  --exclude /android/ --exclude /ios/ --exclude /linux/ --exclude /macos/ \
  --exclude /windows/ --exclude /web/ --exclude /snap/ \
  "$checkout/" "$root/"

# tauri.conf.json keeps bundling off (Windows has its own setup); a release
# turns it on here, with the updater's signed artifacts.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config=$tmp/release.json
echo '{"bundle":{"active":true,"createUpdaterArtifacts":true,"targets":["appimage","deb"]}}' >"$config"

cd "$root"
npm ci --silent --no-audit --no-fund
bundle=$CARGO_TARGET_DIR/release/bundle
rm -rf "$bundle/appimage" "$bundle/deb"
npm run tauri build -- --config "$config"

# Tauri names them "<productName>_<version>_amd64.*".
shopt -s nullglob
appimages=("$bundle"/appimage/*_"${version}"_amd64.AppImage)
debs=("$bundle"/deb/*_"${version}"_amd64.deb)
[[ ${#appimages[@]} -eq 1 ]] || fail "expected one AppImage in $bundle/appimage"
[[ ${#debs[@]} -eq 1 ]] || fail "expected one .deb in $bundle/deb"
[[ -f ${appimages[0]}.sig ]] || fail "no updater signature next to ${appimages[0]}"

name=cloodsy-s3-gui-$version-linux-x64
rm -f "$out/$name".*
cp "${appimages[0]}" "$out/$name.AppImage"
cp "${appimages[0]}.sig" "$out/$name.AppImage.sig"
cp "${debs[0]}" "$out/$name.deb"
# Newer bundlers sign the .deb as well (the updater's linux-x86_64-deb entry).
[[ -f ${debs[0]}.sig ]] && cp "${debs[0]}.sig" "$out/$name.deb.sig"
echo "linux packages in $out:"
ls -l "$out/$name".*
