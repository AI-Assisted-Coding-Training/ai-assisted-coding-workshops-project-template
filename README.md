# AI-Assisted Coding Workshops — Project Template

Starting point for the hands-on project in the **AI Augmented Delivery Training**. Your team builds a **Planning Poker** app (private voting, reveal together, agree an estimate) with the help of GitHub Copilot.

You define the scope. Tasks and backlog are created by your team during Backlog Preparation, and every change produced by the AI agent is reviewed by you.

## Prerequisites

- Access to the `KainosSoftwareLtd` GitHub organisation and the [GitHub CLI](https://cli.github.com/)
- Latest [VS Code](https://code.visualstudio.com/)
- GitHub Copilot licence and the GitHub Copilot Chat extension installed in VS Code
- Any modern web browser

Preflight check:

```shell
gh auth status
gh repo list KainosSoftwareLtd --limit 1
```

Both commands must succeed, and Copilot Chat must reply to `Hello`.

## GitHub Project Setup

This repository is configured to use the GitHub Project at <https://github.com/orgs/KainosSoftwareLtd/projects/101>.

It is also set up to use the **Kainos Backlog Assistant** VS Code extension, which allows to read and create epics and stories in the GitHub project. To use it you need repository write access, the extension installed from a `.vsix` file, and a Personal Access Token (PAT).

1. **Create a PAT**: on GitHub, go to your profile icon → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)** → **Generate new token (classic)**.
   - Use any token name.
   - Tick the **repo** and **project** scopes.
2. **Authorise SSO**: next to the token, choose **Configure SSO** and authorise it for `KainosSoftwareLtd`.
3. **Install the extension**: the file [backlog-assistant-0.6.0.vsix](tools/backlog-assistant-0.6.0.vsix) is in the [tools](tools) folder. In VS Code open **Extensions** → **...** menu → **Install from VSIX...** and select it.
4. **Set the PAT**: open the **Backlog Assistant** tree view panel, click the **key** icon to set the extension's credentials, and paste in the PAT.
5. **Restart VS Code**: it must be restarted after setting the PAT, or the extension will not pick it up.

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

The [backend API contract](docs/api-contract.md) defines the Planning Poker WebSocket protocol, room and voting behavior, and the `/health` route. Use it as the shared interface when planning and implementing the frontend and backend.

## Test framework

The [Playwright test framework](test/README.md) lives in `test/`. Run its npm
commands from that directory, not the repository root. The existing scenarios
target Sauce Demo as examples; they do not yet test Planning Poker.

## How we work

- Slice work into small, testable, vertical slices delivered end to end.
- Work on a branch per task and review every AI-generated change before merging.
- The final scope and tech stack are decided by your team during planning.
