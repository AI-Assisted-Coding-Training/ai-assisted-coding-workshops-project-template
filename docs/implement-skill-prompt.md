# Prompt: Create the `/implement` Skill

```text
Create `.agents/skills/implement/SKILL.md` with frontmatter (`name: implement`, `argument-hint: 'TICKET_ID (e.g. PPO-12)'`, `disable-model-invocation: true`, and a short description).

Define a 6-step workflow to implement one backlog ticket without writing tests or pushing:
1. Fetch ticket: call `backlogAssistant_fetchTicketFromRemote` (`ticketKey: <TICKET_ID>`) and read only the returned `filePath` (no folder search). Stop on error and ask the user to check the key/connection.
2. Read ticket: extract acceptance criteria (AC01...), out-of-scope items, technical notes, and follow any chat ADRs or verification plans.
3. Implement: satisfy only the ACs using existing repo conventions. Skip out-of-scope items and tests.
4. Check: run existing build/start commands from `README.md`/`package.json` and verify each AC once. Fix failures or stop if blocked; do not invent checks if none exist.
5. Stop and wait: report changed files (1 line each), AC status (passed/failed/not checked), and unchecked items. Ask: "Accept this change? Reply `commit` to commit it, or tell me what to change."
6. Commit (only after approval): ensure `core.hooksPath` is `.githooks` and `node_modules/.bin/knip` exists (run `npm install` if missing), branch off `main` as lowercase `<ticket-id>-<short-slug>`, stage only changed files, and commit as `<TICKET_ID>: <ticket title>`. Fix any `knip` pre-commit failures without `--no-verify`, and do not push.
```
