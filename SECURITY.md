# Security Policy

6529Stream is pre-audit and not production-ready. The current repository is a
protocol draft with known P0 blockers tracked in [ops/ROADMAP.md](ops/ROADMAP.md).
Do not use these contracts for production drops, custody of valuable assets, or
public security claims until the launch gates are complete.

Operational incidents that do not contain public exploit details should follow
the no-secret procedure in [docs/incident-response.md](docs/incident-response.md)
after private vulnerability triage starts.

## Reporting Vulnerabilities

Please do not open public GitHub issues for exploitable vulnerabilities.

Preferred private reporting path:

1. Use GitHub private vulnerability reporting for this repository:
   <https://github.com/6529-Collections/6529Stream/security/advisories/new>
2. If private reporting is unavailable, contact an existing maintainer
   privately and avoid sharing exploit details in public channels.
3. If you cannot identify a private contact, open a public issue titled
   `Security contact needed` with no vulnerability details.

Include enough detail for maintainers to reproduce and triage the report:

- Affected contract, script, workflow, or documentation path.
- Impact and realistic attack preconditions.
- Minimal proof of concept or transaction sequence where safe.
- Commit SHA or release tag tested.
- Whether the issue is already listed in the roadmap.

Never include private keys, seed phrases, production secrets, or instructions
that would allow public exploitation before maintainers have triaged the issue.

## Scope

In scope:

- Solidity contracts under `smart-contracts/`.
- Foundry tests and deployment scripts under `test/` and `script/`.
- Tooling, CI, bootstrap, and release workflows that affect build integrity.
- Documentation that could cause unsafe deployment, unsafe signing, or incorrect
  security assumptions.
- Known roadmap blockers when the report adds new exploitability, impact,
  reproduction, or mitigation detail.

Out of scope:

- Social engineering, phishing, physical attacks, spam, denial-of-service
  against GitHub, or attacks against unrelated 6529 infrastructure.
- Publicly documented roadmap gaps with no new exploit detail.
- Issues that require compromised maintainer machines, leaked private keys, or
  malicious dependencies outside this repository unless the repository makes the
  compromise materially worse.

## Current Security Posture

The project currently has no bug bounty program and no guaranteed rewards. Good
faith reports are still welcome and will be credited if a public advisory or
release note is appropriate.

Expected response targets:

- Acknowledge private reports within 3 business days.
- Provide an initial severity assessment within 10 business days when enough
  information is available.
- Coordinate remediation, disclosure timing, and credit on a case-by-case basis.

These targets are not a service-level agreement. They exist to set expectations
while the repository matures.

## Safe Harbor

Good faith research is welcome when it avoids harm:

- Use local forks, Anvil, testnets, or synthetic fixtures.
- Do not access, modify, or exfiltrate assets or data that you do not own.
- Do not disrupt services, spam maintainers, or attempt social engineering.
- Stop testing and report privately if you encounter live funds, secrets, or
  non-public data.

## Security-Sensitive Areas

The current roadmap calls out these high-risk areas:

- Drop authorization and replay protection.
- `tx.origin` usage.
- ERC-1271 contract-signature support or explicit exclusion.
- Auction custody and settlement state.
- Push-payment refunds and withdrawal accounting.
- Admin selector and permission model.
- Randomizer request and callback validation.
- Static-analysis high/medium findings.
- Deployment rehearsal, verification, and release artifacts.
- Incident response, emergency pause, signer revocation, retry/recovery,
  withdrawal availability, and evidence retention.

Security reports should reference the relevant roadmap issue ID when possible.
