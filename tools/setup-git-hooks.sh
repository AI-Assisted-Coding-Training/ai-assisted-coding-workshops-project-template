#!/bin/sh
# Install only the pinned repository-local scanner; never use sudo or PATH installs.
set -eu

fail() {
  printf 'setup-git-hooks: %s\n' "$*" >&2
  exit 1
}

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$root"
for tool in git curl tar awk uname mktemp; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required tool not found: $tool"
done
git_root=$(git rev-parse --show-toplevel)
git_root=$(CDPATH= cd -- "$git_root" && pwd -P)
[ "$git_root" = "$root" ] || fail 'Run setup from this repository.'

# An existing hook manager must be handled explicitly, not silently replaced.
current=$(git config --get core.hooksPath) || {
  status=$?
  [ "$status" -eq 1 ] || fail 'Could not read core.hooksPath.'
  current=
}
case "$current" in
  '')
    default_hooks=$(git rev-parse --git-path hooks)
    for hook in "$default_hooks"/*; do
      # Git ignores samples and non-executable files. Treat other executables
      # conservatively as hook candidates, including hooks other than pre-commit.
      case "$hook" in *.sample) continue ;; esac
      if [ -f "$hook" ] && [ -x "$hook" ]; then
        fail "Existing executable in default hooks directory: $hook; reconcile existing hooks before setup."
      fi
    done
    ;;
  .githooks) ;;
  *) fail "core.hooksPath is already '$current'; resolve the conflict before setup." ;;
esac

case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) fail 'Supported platforms: macOS/Linux (x64 or ARM64). On Windows use tools/setup-git-hooks.ps1.' ;;
esac
case "$(uname -m)" in
  x86_64|amd64) arch=x64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) fail 'Unsupported architecture; expected x64 or ARM64.' ;;
esac

IFS= read -r version < tools/gitleaks-release.txt
printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail 'Invalid pinned version.'
asset="gitleaks_${version}_${os}_${arch}.tar.gz"
expected=$(awk -v asset="$asset" '$2 == asset { print $1 }' tools/gitleaks-release.txt)
printf '%s\n' "$expected" | grep -Eq '^[0-9a-f]{64}$' || fail "Missing or invalid checksum for $asset."
if command -v sha256sum >/dev/null 2>&1; then
  hash_tool=sha256sum
elif command -v shasum >/dev/null 2>&1; then
  hash_tool=shasum
else
  fail 'Install sha256sum or shasum before setup.'
fi

mkdir -p .tools/gitleaks
stage=$(mktemp -d "$root/.tools/gitleaks/.install.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 1' HUP INT TERM
archive="$stage/$asset"
url="https://github.com/gitleaks/gitleaks/releases/download/v$version/$asset"
printf 'Downloading Gitleaks %s (%s/%s)...\n' "$version" "$os" "$arch"
curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
  --connect-timeout 15 --max-time 180 --output "$archive" "$url"
if [ "$hash_tool" = sha256sum ]; then
  actual=$(sha256sum "$archive" | awk '{ print $1 }')
else
  actual=$(shasum -a 256 "$archive" | awk '{ print $1 }')
fi
[ "$actual" = "$expected" ] || fail 'Checksum mismatch; binary and hook configuration were not changed.'

# Extract only the expected regular file, never arbitrary archive paths or links.
entry_type=$(tar -tvzf "$archive" gitleaks | awk '{ print substr($0, 1, 1) }')
[ "$entry_type" = '-' ] || fail 'Archive must contain exactly one regular gitleaks executable.'
tar -xzf "$archive" -C "$stage" gitleaks
[ -f "$stage/gitleaks" ] && [ ! -L "$stage/gitleaks" ] || fail 'Invalid executable in archive.'
chmod 755 "$stage/gitleaks"
[ "$("$stage/gitleaks" version)" = "$version" ] || fail 'Downloaded executable has an unexpected version.'

# Keep any existing binary until the replacement has been verified.
target=".tools/gitleaks/$version"
mkdir -p "$target"
[ ! -L "$target/gitleaks" ] || fail 'Refusing to replace a symlink at the install destination.'
mv -f "$stage/gitleaks" "$target/gitleaks"
git config --local core.hooksPath .githooks
printf 'Gitleaks %s installed in %s; repository hooks enabled.\n' "$version" "$target"
