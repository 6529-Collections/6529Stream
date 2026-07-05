# Architecture Decision Records

ADRs are required before unsafe P0 implementation work.

ADRs are also the amendment mechanism for the Stream specification set, as
defined in [`docs/spec-policy.md`](../spec-policy.md): an accepted ADR is the
only way to change the normative content of a spec at `Review` or `Final`
status, and a spec cannot reach `Final` while it depends on a `Proposed`
ADR. After the genesis deployment, specs for Permanent surfaces change only
through errata or successor-line documents; an ADR that would alter deployed
Permanent semantics is invalid by construction.

Expected ADRs are tracked in `ops/ROADMAP.md`:

| ADR | Status | Issue |
| --- | --- | --- |
| [`0001-drop-authorization.md`](0001-drop-authorization.md) | Accepted | [#17](https://github.com/6529-Collections/6529Stream/issues/17) |
| [`0002-auction-custody.md`](0002-auction-custody.md) | Accepted | [#21](https://github.com/6529-Collections/6529Stream/issues/21) |
| [`0003-payment-accounting.md`](0003-payment-accounting.md) | Accepted | [#24](https://github.com/6529-Collections/6529Stream/issues/24) |
| [`0004-admin-governance.md`](0004-admin-governance.md) | Accepted | [#33](https://github.com/6529-Collections/6529Stream/issues/33) |
| [`0005-randomness.md`](0005-randomness.md) | Accepted | [#14](https://github.com/6529-Collections/6529Stream/issues/14) |
| [`0006-metadata-freeze.md`](0006-metadata-freeze.md) | Accepted | [#45](https://github.com/6529-Collections/6529Stream/issues/45) |
| [`0007-upgrade-redeployment.md`](0007-upgrade-redeployment.md) | Accepted | [#53](https://github.com/6529-Collections/6529Stream/issues/53) |
| [`0008-revenue-splits-and-royalty-resolver.md`](0008-revenue-splits-and-royalty-resolver.md) | Accepted | Protocol design request |
| [`0009-protocol-v1-open-question-resolutions.md`](0009-protocol-v1-open-question-resolutions.md) | Accepted | Protocol v1 open-question resolutions |
| [`0010-world-class-spec-pass.md`](0010-world-class-spec-pass.md) | Accepted | Nine-lens review resolutions |
| [`0011-world-class-pass-round-2.md`](0011-world-class-pass-round-2.md) | Accepted | Nine-lens round-2 resolutions |
| [`0012-world-class-pass-round-3.md`](0012-world-class-pass-round-3.md) | Accepted | Nine-lens round-3 resolutions |
| [`0013-world-class-pass-round-4.md`](0013-world-class-pass-round-4.md) | Accepted | Nine-lens round-4 resolutions |
| [`0014-world-class-pass-round-5.md`](0014-world-class-pass-round-5.md) | Accepted | Nine-lens round-5 resolutions |

Each ADR should include problem, current behavior, intended behavior,
alternatives, security impact, release impact, test plan, rollout plan,
non-goals, and accepted risks.
