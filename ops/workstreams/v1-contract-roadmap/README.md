# V1 Contract Roadmap Workstream

## Charter

Autonomously work through the v1 6529Stream contract roadmap one topic at a
time, with a local plan, focused implementation, external model review, PR
review iteration, merge, and then the next roadmap item.

## Current Operating Mode

- Use `ops/skills/6529-autonomous-manager` as the manager workflow.
- Use heavy subagents for independent audits, sequencing, implementation slices,
  and verification where they materially reduce risk.
- Proceed without asking the user for permission. The user explicitly authorized
  autonomous action for this run.
- Keep one PR-sized topic in focus at a time.
- Keep `StreamCore` bytecode spend scarce; prefer satellites, adapters, and
  release artifacts unless a topic explicitly needs Core hooks.

## External Review Standard

For each substantive local draft, request parallel OpenRouter review from:

- GPT-5.5 Pro: `openai/gpt-5.5-pro`
- Claude Opus 4.8: `anthropic/claude-opus-4.8`
- GLM 5.2: `z-ai/glm-5.2`

Use the local `OPENROUTER_API_KEY` credential target only inside request
processes. Do not print, persist, summarize, or commit the key.

## Owned Paths

- `contracts/`
- `test/`
- `script/`
- `docs/`
- `docs/adr/`
- `ops/ROADMAP.md`
- `ops/EXECUTION_BACKLOG.md`
- `ops/AUTONOMOUS_RUN.md`
- `ops/workstreams/v1-contract-roadmap/`
- `release-artifacts/latest/`

## Evidence Standard

- Record plans, subagent findings, external review summaries, validation, PRs,
  and merge decisions in `run-log.md`.
- Keep maturity language consistent with `docs/status.md`,
  `docs/known-blockers.md`, and `docs/release-readiness.md`.
- Regenerate release artifacts whenever release-impacting docs, manifests, or
  evidence inputs change.
- Do not record secrets, hidden prompts, local credential values, or private
  operational transcripts.
