# Git hooks maintenance

The pre-commit hook runs a repository-local Gitleaks binary against staged changes,
using its built-in rules. It blocks commits on findings, scanner errors, or a
missing executable. Findings are redacted. No reports or secrets are uploaded.
This replaces the root npm tooling; Playwright and its Node.js dependencies in
`test/` are unchanged.

## Setup and troubleshooting

Follow the platform-specific setup commands in [README.md](../README.md#pre-commit-hook).
Setup writes only `.tools/gitleaks/` and the repository-local `core.hooksPath` Git
setting. It does not install global packages, change PATH, or require administrator
privileges. Allow approximately 50 MB of free space for downloads and staging.
The binary lives in `.tools/gitleaks/<pinned-version>/`; Git ignores this directory.

- Run setup again after cloning, switching to a new worktree, changing platforms,
  or pulling a version-pin update. Each checkout needs its own binary; linked
  worktrees normally share the repository-local Git configuration.
- Setup downloads and verifies the archive on every run. Failed downloads and
  checksum checks leave the existing binary and hook configuration unchanged.
- If another `core.hooksPath` is configured, setup stops. Before first activation,
  setup also stops for non-sample executable files in Git's default hooks directory
  (on Windows, any non-sample file). This preserves existing checks, including
  `commit-msg` and `pre-push`, even when no hook manager is configured. Record the
  current configuration and reconcile those hooks before switching to `.githooks`.
  Setup does not chain or replace existing hooks automatically.
- On Windows, run setup from PowerShell and commit with Git for Windows, whose
  bundled shell executes the hook. If organizational execution policy blocks
  scripts, use your approved signing/policy process; do not disable machine policy.
- A Gitleaks finding requires removing the secret from the staged content and
  staging the corrected file again. If a real credential was exposed, revoke or
  rotate it; deleting it from the next commit does not undo exposure.

The hook scans the index, not unstaged files or all previous commits. Local hooks
can be bypassed or remain unconfigured in a fresh clone. CI enforcement and a
historical repository scan are separate follow-up tasks.

## Verification

On macOS/Linux, run:

```sh
sh tools/test-git-hooks.sh
```

This downloads the pinned release and tests it in a temporary Git repository,
including clean and secret-bearing first commits, partially staged files,
redaction, missing binaries, scanner errors, repeat setup, conflicting hook
configuration, default-directory hooks, symlinked checkout paths, bad checksums,
and download failures. The fixture uses a separate Git directory to test hook-path
resolution. Tests do not alter this checkout's Git configuration. To reuse a
previously downloaded official archive:

```sh
sh tools/test-git-hooks.sh /path/to/gitleaks_<version>_<os>_<arch>.tar.gz
```

The archive is still checked against the committed checksum. The test removes its
temporary repository on exit. Native Windows setup and hook execution must also
be tested on Windows before claiming Windows runtime verification.

## Pinning and updates

Repository maintainers own updates; there is no auto-updater. The manually managed
binary is discoverable through `tools/gitleaks-release.txt` and these setup scripts,
not through npm or an OS package manager.

`tools/gitleaks-release.txt` contains the version on its first line and the official
SHA-256 hashes for the supported platform archives below it. Both setup scripts
read this file. The hook resolves the executable from its version, so pulling a
new pin requires running setup again before committing.

To update:

1. Review the [official releases](https://github.com/gitleaks/gitleaks/releases)
   and [security advisories](https://github.com/gitleaks/gitleaks/security/advisories).
   Review relevant dependency advisories and any available release provenance.
2. Select an exact release. Replace the first line and all six supported archive
   hashes using that release's official checksum file. Check them against the
   release API's SHA-256 asset digests where available.
3. Run setup and the integration tests. Test Windows separately, and test the other
   advertised OS/architecture combinations before declaring them verified.
4. Review and commit the manifest change. Tell developers to rerun setup.

The initial pin is **8.30.1**, from
[the official release](https://github.com/gitleaks/gitleaks/releases/tag/v8.30.1).
Its six hashes were compared with the official checksum file and GitHub release
asset digests. The upstream public security advisory list and the OSV query for
`github.com/zricethezav/gitleaks/v8` at `v8.30.1` returned no findings on
2026-11-11. This is not a full transitive dependency audit or independent
signature verification; checksums establish consistency with the trusted release
source, not freedom from vulnerabilities.

## Rollback and removal

Before setup, record `git config --show-origin --get-all core.hooksPath` if it
returns a value. To undo activation, restore that previous repository-local value,
or, if there was none, run:

```sh
git config --local --unset core.hooksPath
```

Only unset the value if it still belongs to this setup (`.githooks`); preserve any
subsequent configuration changes. Remove `.tools/gitleaks/` to remove the downloaded
binaries; no global installation needs uninstalling. To roll back a release, restore
the previous manifest from Git and rerun setup. Older version directories are kept
until explicitly removed, so a failed update does not delete the previous version.
