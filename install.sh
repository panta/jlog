#!/bin/sh
# Installs the latest jlog release for this machine, verifying its SHA-256 checksum.
# Usage: curl -fsSL https://jlog.logging.work/install.sh | sh
set -eu
base="${JLOG_BASE_URL:-https://jlog.logging.work}"
dest="${JLOG_INSTALL_DIR:-$HOME/.local/bin}"

case "$(uname -s)" in
    Linux) os=unknown-linux-gnu ;;
    Darwin) os=apple-darwin ;;
    *) echo "jlog: unsupported system $(uname -s); download a release manually from $base" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    arm64 | aarch64) arch=aarch64 ;;
    *) echo "jlog: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

fetch() { curl -fsSL "$1" -o "$2"; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

version=$(curl -fsSL "$base/latest/VERSION")
file="jlog-${version}-${arch}-${os}.tar.gz"
echo "jlog: downloading $file"
fetch "$base/latest/$file" "$tmp/$file"
fetch "$base/latest/SHA256SUMS" "$tmp/SHA256SUMS"

expected=$(grep " $file\$" "$tmp/SHA256SUMS" | cut -d' ' -f1)
if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$tmp/$file" | cut -d' ' -f1)
else
    actual=$(shasum -a 256 "$tmp/$file" | cut -d' ' -f1)
fi
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
    echo "jlog: checksum mismatch for $file; not installing" >&2
    exit 1
fi

tar -xzf "$tmp/$file" -C "$tmp"
mkdir -p "$dest"
install -m 0755 "$tmp/jlog-${version}-${arch}-${os}/jlog" "$dest/jlog"
echo "jlog: installed $version to $dest/jlog"
case ":$PATH:" in *":$dest:"*) ;; *) echo "jlog: add $dest to your PATH" ;; esac
