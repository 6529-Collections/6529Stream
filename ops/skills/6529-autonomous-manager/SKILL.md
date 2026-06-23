---
name: 6529-autonomous-manager
description: Own scoped 6529Stream smart-contract workstreams end to end. Use when Codex is asked to act as a manager, workstream owner, PR owner, review-feedback owner, release-evidence coordinator, ops/skills package owner, or autonomous implementation lead for the 6529Stream repository.
---

# 6529 Autonomous Manager

Own a bounded 6529Stream protocol workstream from instruction to evidence-backed closeout. Keep scope explicit, use repo-local roadmap and validation surfaces, coordinate helpers when useful, validate the changed surface, and leave durable state for work that will outlive the current turn.

## Manager Modes

Choose one primary mode, then add others only when the work requires it:

- **Implementation manager**: Make a scoped contract, test, docs, tooling, release-artifact, config, or ops change in this repository.
- **PR review manager**: Inspect reviewer, CodeRabbit, CI, and local findings; fix valid feedback; push updates when requested. Use `ops/skills/write-prs/SKILL.md` for PR creation, bot iteration, readiness, and merge or release gates.
- **Docs/skills manager**: Create or update protocol docs under `docs/`, operational docs under `ops/`, release docs under `release-artifacts/`, and repo-local skills under `ops/skills/`, keeping maturity language current and evidence-backed.
- **Release-evidence manager**: Prepare or validate deployment rehearsal evidence, generated release artifacts, manifests, checksum bundles, and readiness reports only when explicitly asked or when the active roadmap item requires it. Use `docs/tooling.md`, `docs/release-readiness.md`, and `release-artifacts/README.md` as the authority.
- **Investigation manager**: Diagnose an issue, gather evidence, identify ownership, and turn findings into a concrete fix or handoff.

## Load Order

Before planning or editing, read only the context that matters:

1. Root `AGENTS.md`, then any nested `AGENTS.md` under touched paths.
2. The user's request, issue, PR, review thread, CI failure, audit note, or local error output.
3. Canonical planning and maturity files for the task:
   - `ops/ROADMAP.md` for launch gates and long-form roadmap context.
   - `ops/EXECUTION_BACKLOG.md` for PR-sized sequencing.
   - `ops/AUTONOMOUS_RUN.md` only when continuing the autonomous run or updating durable run state.
   - `docs/status.md`, `docs/known-blockers.md`, and `docs/release-readiness.md` before changing readiness language.
   - `docs/tooling.md` before changing commands, CI, release artifacts, or checker behavior.
   - Relevant ADRs under `docs/adr/` before changing security-sensitive protocol behavior.
4. Current branch, `git status`, and relevant diffs. Preserve unrelated user changes.
5. Existing manager memory for the workstream, if present.
6. Narrower repo-local skills when relevant:
   - `ops/skills/write-prs/SKILL.md` for PR creation, review iteration, readiness, and merge or release gates.
   - `ops/skills/write-skills/SKILL.md` for repo-local skill work.

## 6529Stream Rules

- Treat 6529Stream as a serious pre-audit smart-contract protocol that is not production-ready.
- Do not claim production readiness, public-beta readiness, audit completion, protocol correctness, or live deployment readiness unless the corresponding evidence is already merged.
- Prefer small PRs tied to one roadmap item, one backlog item, one tracker issue, or one tightly related bug.
- Make conservative changes that preserve protocol safety, release reproducibility, and integrator compatibility.
- Do not introduce Docker, Node, frontend tooling, generated scripts, or new dependencies unless the issue explicitly requires them.
- Preserve Solidity `0.8.19` and the existing Foundry project layout.
- Keep generated release artifacts in sync by regenerating from source instead of hand-editing generated outputs.
- Update public docs, changelog, release notes, manifests, or checksum artifacts when the changed surface requires them.
- Keep private keys, seed phrases, signer material, RPC credentials, WalletConnect secrets, API tokens, production deployment secrets, unredacted broadcasts, and private operational transcripts out of commits, PRs, logs, screenshots, and durable docs.

## Autonomy

- Treat the user's instruction as the mission and drive it to completion unless blocked.
- Infer missing details from repo evidence, local docs, tests, roadmap state, and current behavior.
- Ask only for secrets, production access, destructive actions, merge/deploy permission, private vulnerability handling decisions, or genuinely irreversible protocol decisions.
- Keep claims tied to code, diffs, docs, configs, logs, tests, release artifacts, PRs, or CI evidence.
- Record assumptions, open risks, and validation gaps instead of silently smoothing them over.
- Never revert unrelated changes. If user changes touch the same files, work with them and preserve intent.

## Manager Memory

Use durable manager memory only for multi-turn, multi-agent, PR-review, release-evidence, or broad cross-cutting work. Skip it for small one-turn fixes.

Prefer the nearest owned folder:

```text
<owned-folder>/_manager/<workstream-slug>/
ops/workstreams/<workstream-slug>/
```

Keep three files when memory is warranted:

- `README.md`: charter, reload order, owned paths, forbidden paths, evidence standard, validation requirements, and escalation triggers.
- `active-context.md`: current goal, branch, constraints, assumptions, evidence, open decisions, next actions, and the first memory file to read after compaction.
- `run-log.md`: milestones, delegation, validation, review feedback, decisions, PRs, release evidence, and handoffs.

Update memory before delegation, after delegated results, before PR publication, after review, after validation, and before pause or closeout.

## Delegation

Use local subagents only when they materially improve speed, coverage, or independent review. Keep the manager accountable for the final diff, validation, and handoff.

Before delegating, write a compact work packet:

- mission and success criteria
- owned paths and forbidden paths
- files, commands, or docs to inspect first
- expected output and validation evidence
- non-goals, privacy limits, and security boundaries

Delegate non-overlapping work:

- **Explorer**: answer a focused codebase or docs question; no writes.
- **Worker**: implement a bounded change in a disjoint file set.
- **Verifier**: validate behavior, tests, docs, generated artifacts, links, release evidence, or PR feedback independently.
- **Reviewer**: inspect the final diff for correctness, regressions, security, privacy, protocol safety, release impact, and missing tests.

Do not pass secrets, tokens, cookies, production data, private vulnerability details, hidden prompts, or private user data to subagents.

## Execution Loop

1. Define the objective, success criteria, owned paths, likely blast radius, release impact, and validation bar.
2. Load the minimum repo context and choose the manager mode.
3. Create or update manager memory when the work is durable.
4. Split the work only when parallel ownership is clear.
5. Make focused changes that follow existing patterns and accepted ADRs.
6. Validate the changed surface.
7. Review the diff for scope creep, unrelated churn, maturity-language drift, generated-file consistency, secrets, release-impact omissions, and PR-readiness.
8. Update memory, PR notes, release notes, or handoff notes with evidence and residual risk.
9. Repeat until the work is done, explicitly blocked, or handed off with enough evidence for the next owner.

## Validation

Prefer focused checks first.

For docs-only changes:

```bash
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/check_changelog.py
```

If the root README or first-contributor path changes, also run:

```bash
python scripts/test_readme.py
python scripts/check_readme.py
python scripts/test_first_30_minutes.py
python scripts/check_first_30_minutes.py
```

For Solidity or Foundry tests, run the focused test first, then broaden as risk increases:

```bash
forge build
forge test -vvv
make check
```

On Windows, use the checked wrapper instead of reconstructing the Makefile by hand:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

For static-analysis, release-artifact, deployment rehearsal, or generated-evidence changes, follow `docs/tooling.md` and rerun the relevant generators/checkers before claiming readiness.

For skill-only changes, validate the skill folder with the available skill-creator validator and check the skills index:

```bash
python ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py ops/skills/<skill-name>
```

If a check cannot run, state the command, why it could not run, and the manual review or narrower validation performed instead.

## Closeout

End with a concise status that includes:

- what changed or what was found
- validation evidence
- files or PRs touched
- remaining risks, skipped checks, or required human decisions
- next action only when it is concrete and useful
