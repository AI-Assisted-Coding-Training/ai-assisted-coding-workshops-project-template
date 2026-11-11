#!/bin/sh
# Integration tests in a disposable repository. Optional argument: local release
# archive to exercise checksum verification without repeated network downloads.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
fixture=${1:-}
if [ -n "$fixture" ]; then
  fixture=$(CDPATH= cd -- "$(dirname -- "$fixture")" && pwd)/$(basename -- "$fixture")
  [ -f "$fixture" ] || { printf 'Archive not found: %s\n' "$fixture" >&2; exit 1; }
fi
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/gitleaks-hook-tests.XXXXXX")
sandbox=$(CDPATH= cd -- "$sandbox" && pwd -P)
trap 'rm -rf -- "$sandbox"' EXIT
trap 'exit 1' HUP INT TERM
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
repo="$sandbox/repo with spaces"
mkdir -p "$repo/tools" "$repo/.githooks" "$repo/docs" "$sandbox/bin"
cp "$root/tools/setup-git-hooks.sh" "$root/tools/setup-git-hooks.ps1" \
  "$root/tools/gitleaks-release.txt" "$root/tools/test-git-hooks.sh" "$repo/tools/"
cp "$root/.githooks/pre-commit" "$repo/.githooks/"
cp "$root/.gitignore" "$root/.gitattributes" "$root/README.md" "$repo/"
cp "$root/docs/git-hooks.md" "$root/docs/implement-skill-prompt.md" "$repo/docs/"
# A separate Git directory catches accidental hard-coding of .git/hooks.
git -c init.templateDir= init -q --separate-git-dir "$sandbox/git metadata" "$repo"
cd "$repo"
git config user.name 'Hook tests'
git config user.email 'hook-tests@example.invalid'
git config core.autocrlf false

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
expect_failure() {
  log=$1
  shift
  if "$@" > "$log" 2>&1; then
    fail "Command unexpectedly succeeded: $*"
  fi
}

# Stub only transport when a fixture is supplied; the real installer still
# validates the pinned archive and runs the actual Gitleaks executable.
if [ -n "$fixture" ]; then
  export GITLEAKS_TEST_ARCHIVE="$fixture"
  printf '%s\n' '#!/bin/sh' 'while [ "$#" -gt 0 ]; do' \
    '  if [ "$1" = --output ]; then cp "$GITLEAKS_TEST_ARCHIVE" "$2"; exit; fi' \
    '  shift' 'done' 'exit 2' > "$sandbox/bin/curl"
  chmod +x "$sandbox/bin/curl"
  PATH="$sandbox/bin:$PATH"
  export PATH
fi

# Existing default-directory hooks must be reconciled before any download or
# activation. Cover both pre-commit and a different hook that would be disabled.
default_hooks=$(git rev-parse --git-path hooks)
mkdir -p "$default_hooks"
for name in pre-commit pre-push; do
  printf '#!/bin/sh\nexit 99\n' > "$default_hooks/$name"
  chmod +x "$default_hooks/$name"
  cp "$default_hooks/$name" "$sandbox/default-hook.saved"
  expect_failure "$sandbox/default-$name.log" sh tools/setup-git-hooks.sh
  grep -q 'Existing executable in default hooks directory' "$sandbox/default-$name.log" || fail "Default $name was not detected."
  cmp "$default_hooks/$name" "$sandbox/default-hook.saved" || fail "Default $name was changed."
  [ -x "$default_hooks/$name" ] || fail "Default $name lost its executable bit."
  if git config --get core.hooksPath >/dev/null; then fail 'Default-hook conflict activated hooks.'; fi
  [ ! -e .tools ] || fail 'Default-hook conflict reached installation.'
  rm -- "$default_hooks/$name"
done
pass 'Default pre-commit and pre-push hooks are preserved and block activation'

# Samples and inactive Unix hooks must not block first-time setup.
printf '#!/bin/sh\nexit 99\n' > "$default_hooks/pre-commit.sample"
chmod +x "$default_hooks/pre-commit.sample"
printf '#!/bin/sh\nexit 99\n' > "$default_hooks/pre-commit"
chmod 644 "$default_hooks/pre-commit"
ln -s "$sandbox" "$sandbox/alias"
sh "$sandbox/alias/repo with spaces/tools/setup-git-hooks.sh" > "$sandbox/setup.log" 2>&1
pass 'Setup accepts a symlinked parent path, samples, and non-executable Unix hooks'
[ "$(git config --get core.hooksPath)" = .githooks ] || fail 'Hooks were not activated.'
IFS= read -r version < tools/gitleaks-release.txt
binary=".tools/gitleaks/$version/gitleaks"
[ "$("$binary" version)" = "$version" ] || fail 'Wrong installed version.'
git check-ignore -q "$binary" || fail 'Local executable is not ignored.'
pass 'Pinned scanner installed and hooks enabled, including paths with spaces'

# A synthetic, randomly generated GitHub-token-shaped value, never a real key.
secret="$(printf 'ghp_'; LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 36)"
printf 'token = "%s"\n' "$secret" > credential.txt
git add credential.txt
expect_failure "$sandbox/secret.log" git commit -qm 'Must be blocked on first commit'
if git rev-parse --verify HEAD >/dev/null 2>&1; then fail 'Secret was committed.'; fi
grep -q 'leaks found' "$sandbox/secret.log" || fail 'Scanner did not detect the fixture.'
if grep -Fq "$secret" "$sandbox/secret.log"; then fail 'Secret appeared in hook output.'; fi
pass 'Initial commit containing a synthetic secret is blocked and output is redacted'

git rm -q --cached credential.txt
printf 'public configuration\n' > credential.txt
git add .
git commit -qm 'Clean initial commit' > "$sandbox/clean.log" 2>&1
pass 'Clean initial commit succeeds'

# The staged version has a secret, but the working tree has been cleaned.
printf 'token = "%s"\n' "$secret" > credential.txt
git add credential.txt
printf 'public configuration\n' > credential.txt
expect_failure "$sandbox/partial.log" git commit -qm 'Must scan the index'
grep -q 'leaks found' "$sandbox/partial.log" || fail 'Staged secret was missed.'
if grep -Fq "$secret" "$sandbox/partial.log"; then fail 'Secret appeared in partial-stage output.'; fi
pass 'Partially staged secret is blocked even when the working file is clean'

# Conversely, an unstaged secret must not prevent a clean staged commit.
git add credential.txt
printf 'token = "%s"\n' "$secret" > credential.txt
printf 'safe staged change\n' > clean.txt
git add clean.txt
git commit -qm 'Only staged content is scanned' > "$sandbox/unstaged.log" 2>&1
pass 'Unstaged secret does not affect a clean staged commit'
printf 'public configuration\n' > credential.txt

printf 'another clean change\n' >> clean.txt
git add clean.txt
mv "$binary" "$binary.saved"
expect_failure "$sandbox/missing.log" git commit -qm 'Missing scanner must block'
grep -q 'Gitleaks is missing' "$sandbox/missing.log" || fail 'Missing-scanner instructions not shown.'
printf '#!/bin/sh\nexit 42\n' > "$binary"
chmod +x "$binary"
status=0
.githooks/pre-commit > "$sandbox/error.log" 2>&1 || status=$?
[ "$status" -eq 42 ] || fail 'Scanner error exit code was not propagated.'
mv "$binary.saved" "$binary"
pass 'Missing executable and scanner errors fail closed'

# A failed update must preserve the binary and leave hooks disabled if unset.
cp tools/gitleaks-release.txt "$sandbox/release.saved"
cp "$binary" "$sandbox/binary.saved"
awk 'NR > 1 { $1 = "0000000000000000000000000000000000000000000000000000000000000000" } { print }' \
  "$sandbox/release.saved" > tools/gitleaks-release.txt
git config --unset core.hooksPath
expect_failure "$sandbox/checksum.log" sh tools/setup-git-hooks.sh
grep -q 'Checksum mismatch' "$sandbox/checksum.log" || fail 'Invalid checksum was not rejected.'
cmp "$binary" "$sandbox/binary.saved" || fail 'Checksum failure replaced the binary.'
if git config --get core.hooksPath >/dev/null; then fail 'Checksum failure activated hooks.'; fi
cp "$sandbox/release.saved" tools/gitleaks-release.txt
pass 'Checksum failure preserves the previous executable and does not activate hooks'

# Repeat setup with the hook configuration already active.
git config core.hooksPath .githooks
sh tools/setup-git-hooks.sh > "$sandbox/repeat.log" 2>&1
[ "$(git config --get core.hooksPath)" = .githooks ] || fail 'Repeat setup did not enable hooks.'
cmp "$binary" "$sandbox/binary.saved" || fail 'Repeat setup changed the pinned executable.'
pass 'Repeated setup succeeds'

git config core.hooksPath existing-hook-manager
expect_failure "$sandbox/conflict.log" sh tools/setup-git-hooks.sh
[ "$(git config --get core.hooksPath)" = existing-hook-manager ] || fail 'Existing hook configuration was overwritten.'
git config --unset core.hooksPath
pass 'Conflicting hook configuration is preserved'

# Force a transport failure regardless of whether a fixture was supplied.
printf '#!/bin/sh\nexit 22\n' > "$sandbox/bin/curl"
chmod +x "$sandbox/bin/curl"
PATH="$sandbox/bin:$PATH"
export PATH
expect_failure "$sandbox/download.log" sh tools/setup-git-hooks.sh
cmp "$binary" "$sandbox/binary.saved" || fail 'Failed download replaced the binary.'
if git config --get core.hooksPath >/dev/null; then fail 'Failed download activated hooks.'; fi
if find .tools -name '.install.*' | grep -q .; then fail 'Installer staging directory was not cleaned.'; fi
pass 'Download failure preserves state and cleans up staging files'
printf 'All hook integration tests passed.\n'
