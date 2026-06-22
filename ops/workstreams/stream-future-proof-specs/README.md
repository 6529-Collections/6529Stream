# Stream Future-Proof Specs Workstream

## Charter

Produce future-proof proposed specifications for the long-lived 6529Stream
contract architecture, with emphasis on maximum on-chain optionality,
maintainability over 50+ years, and review-backed design quality.

## Scope

- Primary-sale payments and split accounting.
- Secondary royalty disclosure and royalty receiver architecture.
- Metadata router, renderer, script assembly, and long-lived on-chain metadata
  options.
- Entropy coordinator and provider adapter architecture.
- Cross-cutting lifecycle, upgrade, freeze, registry, evidence, and incident
  response considerations.
- External review through OpenRouter-backed GPT 5.5 Pro, Opus 4.8, and GLM 5.2.

## Source Baseline

- Remote source of truth: `origin/main`.
- Current branch may contain unrelated local changes; only this workstream's
  reviewed specs should be staged for the PR.

## Evidence Standard

- Tie claims to current contracts, existing specs, external review notes, or
  validation output.
- Keep future-state docs explicitly proposed until accepted by normal repo
  governance.
- Do not record API keys, secrets, private local credential values, or hidden
  prompts in durable files.

## Validation

- Run docs/link/sanity checks where practical.
- Run `codex-diff-check` on touched files before commit.
- Before PR publication, review the staged diff for unrelated churn.
