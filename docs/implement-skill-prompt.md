# Prompt: Create the `/implement` Skill

```text
Create `.agents/skills/implement/SKILL.md` with frontmatter (`name: implement`, `argument-hint: 'TICKET_ID (e.g. PPO-12)'`, `disable-model-invocation: true`, and a short description).

Define a workflow to implement one backlog ticket without writing tests or pushing:
1. Fetch ticket: call `backlogAssistant_fetchTicketFromRemote` (`ticketKey: <TICKET_ID>`) and read only the returned `filePath` (no folder search). Stop on error and ask the user to check the key/connection.
2. Read ticket: extract acceptance criteria (AC01...), out-of-scope items, technical notes, and follow any chat ADRs or verification plans.
3. Before implementation: use the `grilling` skill to resolve technical decisions. Ask one question at a time, include your recommended answer, and wait for the user's response before asking the next. Find facts in the codebase or docs instead of asking. Once the user confirms shared understanding, save the implementation plan to `specs/<TICKET_ID>/plan.md` before writing code.
4. Implement: satisfy only the ACs using existing repo conventions. Skip out-of-scope items and tests. If you hit an unaddressed low-level technical or business decision during coding, stop and ask the user (one question with a recommended answer) instead of guessing.
5. Check: run existing build/start commands from `README.md`/`package.json` and verify each AC once. Fix failures or stop if blocked; do not invent a check if none exists.
6. Stop and wait: report changed files (1 line each), AC status (passed/failed/not checked), and unchecked items. Ask: "Accept this change? Reply `commit` to commit it, or tell me what to change."
7. Commit (only after approval): verify the Gitleaks setup described in `README.md` is complete (`core.hooksPath` is `.githooks` and the pinned repository-local executable exists); if setup is missing, follow those instructions before committing. Branch off `main` as lowercase `<ticket-id>-<short-slug>`, stage only changed files, and commit as `<TICKET_ID>: <ticket title>`. Resolve Gitleaks pre-commit failures without `--no-verify`, and do not push.
```
