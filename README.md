# Planning Poker

A web application for agile estimation. Team members join a shared room, vote privately on a work item, reveal the votes together and agree on an estimate.

## Overview

- **Frontend** — this repository. A static web application, deployed to GitHub Pages.
- **Backend** — an existing service, maintained separately. The frontend talks to it over WebSocket as described in the [API contract](docs/api-contract.md).
- **Scope** — features, UI and behaviour are defined in the project backlog. Epics, stories and acceptance criteria are the source of truth for what the application does.

## Prerequisites

- Access to the `KainosSoftwareLtd` GitHub organisation and the [GitHub CLI](https://cli.github.com/)
- Latest [VS Code](https://code.visualstudio.com/)
- GitHub Copilot licence and the GitHub Copilot Chat extension installed in VS Code
- Any modern web browser
- *(Optional)* Node.js and npm, needed only for the Playwright tests and any Node-based frontend tooling

Preflight check:

```shell
gh auth status
gh repo list KainosSoftwareLtd --limit 1
```

Both commands must succeed, and Copilot Chat must reply to `Hello`.

## Getting started

1. Clone the repository.
2. Set up the [pre-commit hook](#pre-commit-hook).

## Project structure

| Path | Contents |
|---|---|
| `docs/` | Project documentation, including the [API contract](docs/api-contract.md) |
| `test/` | Playwright end-to-end test framework |
| `tools/` | Developer tooling, including the Git hook setup scripts |

## Pre-commit hook

Gitleaks blocks commits containing secrets in staged changes. Set it up once per clone:

**macOS/Linux (x64 or ARM64):**

```sh
sh tools/setup-git-hooks.sh
```

**Windows (x64 or ARM64), from PowerShell:**

```powershell
./tools/setup-git-hooks.ps1
```

Setup downloads a pinned official binary, verifies its SHA-256 checksum, and enables
`.githooks/` for this repository. It requires neither Node.js nor Python. Git must
be installed; macOS/Linux also need `curl`, `tar`, and `sha256sum` or `shasum`.
Windows needs Git for Windows and Windows PowerShell 5.1 or later. Internet access
to GitHub is required during setup, not during commits.

See [Git hooks maintenance](docs/git-hooks.md) for troubleshooting, updates,
verification, and rollback. Playwright tooling in `test/` still requires Node.js.

## API contract

The [API contract](docs/api-contract.md) describes the WebSocket protocol, room and voting behaviour, and the `/health` route. It is the fixed interface between the frontend and the backend; the frontend integrates with it and does not change it.

## Testing

End-to-end tests use [Playwright](test/README.md) and live in `test/`. Run the test npm commands from that directory, not from the repository root.

## Deployment

The application is built as a static site and deployed to GitHub Pages.

## How we work

- Any frontend tech stack can be used, as long as it builds to a static site deployable to GitHub Pages.
