#!/usr/bin/env sh
set -eu

# This script is meant to live in a **public** GitHub repo that only hosts
# release artifacts for the `cxp` binary. Your actual source code can remain
# in a separate private repository.

# Default public repo that hosts releases (override with CXP_REPO)
REPO="${CXP_REPO:-syv-labs/cxp}"

VERSION="${CXP_VERSION:-latest}"
BIN_NAME="cxp"
PKG_NAME="cxp"

uname_s="$(uname -s 2>/dev/null || echo unknown)"
uname_m="$(uname -m 2>/dev/null || echo unknown)"

case "$uname_s" in
  Darwin) os="darwin" ;;
  Linux) os="linux" ;;
  *) echo "Unsupported OS: $uname_s" >&2; exit 1 ;;
esac

case "$uname_m" in
  x86_64|amd64) arch="x86_64" ;;
  arm64|aarch64) arch="aarch64" ;;
  *) echo "Unsupported architecture: $uname_m" >&2; exit 1 ;;
esac

case "$os-$arch" in
  darwin-x86_64) target="x86_64-apple-darwin" ;;
  darwin-aarch64) target="aarch64-apple-darwin" ;;
  linux-x86_64) target="x86_64-unknown-linux-musl" ;;
  linux-aarch64) target="aarch64-unknown-linux-musl" ;;
  *) echo "Unsupported platform: $os-$arch" >&2; exit 1 ;;
esac

tmpdir="$(mktemp -d 2>/dev/null || mktemp -d -t cxp)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT INT TERM

if [ "$VERSION" = "latest" ]; then
  tag="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | awk -F'"' '/\"tag_name\":/ {print $4; exit}')"
else
  tag="v$VERSION"
fi

if [ -z "${tag:-}" ]; then
  echo "Could not determine release tag. Set CXP_VERSION=0.1.0 or publish a GitHub Release." >&2
  exit 1
fi

version_no_v="${tag#v}"
asset="${PKG_NAME}-v${version_no_v}-${target}.tar.gz"
base_url="https://github.com/${REPO}/releases/download/${tag}"

archive_url="${base_url}/${asset}"
checksum_url="${base_url}/checksums.txt"

echo "Downloading ${asset} from ${REPO} (${tag})"
curl -fsSL "$archive_url" -o "${tmpdir}/${asset}"

if curl -fsSL "$checksum_url" -o "${tmpdir}/checksums.txt"; then
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$tmpdir" && sha256sum -c checksums.txt 2>/dev/null | grep "${asset}: OK" >/dev/null) || {
      echo "Checksum verification failed for ${asset}" >&2
      exit 1
    }
  elif command -v shasum >/dev/null 2>&1; then
    expected="$(awk -v a="$asset" '$2==a {print $1}' "$tmpdir/checksums.txt" | head -n 1)"
    actual="$(shasum -a 256 "$tmpdir/$asset" | awk '{print $1}')"
    [ -n "$expected" ] && [ "$expected" = "$actual" ] || {
      echo "Checksum verification failed for ${asset}" >&2
      exit 1
    }
  else
    echo "Warning: no sha256 tool found; skipping checksum verification" >&2
  fi
else
  echo "Warning: checksums.txt not found; skipping checksum verification" >&2
fi

install_dir="${CXP_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$install_dir"

tar -C "$tmpdir" -xzf "${tmpdir}/${asset}"
chmod +x "${tmpdir}/${BIN_NAME}"
mv "${tmpdir}/${BIN_NAME}" "${install_dir}/${BIN_NAME}"

echo "Installed ${BIN_NAME} to ${install_dir}/${BIN_NAME}"
if ! command -v "$BIN_NAME" >/dev/null 2>&1; then
  echo ""
  echo "Add this to your shell profile:"
  echo "  export PATH=\"${install_dir}:\$PATH\""
fi

echo ""
echo "Registering contextpool MCP server with Claude Code and Cursor..."
"${install_dir}/${BIN_NAME}" install --binary-path "${install_dir}/${BIN_NAME}" || true

