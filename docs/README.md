# Documentation

This directory contains protocol specifications, architecture and security
material, integration guides, operator runbooks, and release policy for
6529Stream.

This page is a navigation aid, not a status or specification source. Do not
copy changing measurements, blocker counts, or readiness claims into this
index. Use the linked canonical surfaces instead.

## Start By Role

| Reader | Start here |
| --- | --- |
| New contributor | [`first-30-minutes.md`](first-30-minutes.md), [`../CONTRIBUTING.md`](../CONTRIBUTING.md), and [`tooling.md`](tooling.md) |
| Protocol implementer | [`solidity-source-map.md`](solidity-source-map.md), [`spec-policy.md`](spec-policy.md), [`launch-v1-target-architecture.md`](launch-v1-target-architecture.md), [`launch-conformance-matrix.md`](launch-conformance-matrix.md), and [`adr/README.md`](adr/README.md) |
| Auditor or security reviewer | [`audit-package.md`](audit-package.md), [`architecture.md`](architecture.md), [`threat-model.md`](threat-model.md), [`known-blockers.md`](known-blockers.md), and [`../SECURITY.md`](../SECURITY.md) |
| Integrator or indexer | [`integrations/README.md`](integrations/README.md), [`protocol-surface.md`](protocol-surface.md), and [`custom-errors.md`](custom-errors.md) |
| Operator or deployer | [`deployment.md`](deployment.md), [`randomizer-operations.md`](randomizer-operations.md), [`monitoring.md`](monitoring.md), and [`incident-response.md`](incident-response.md) |
| Release reviewer | [`release-readiness.md`](release-readiness.md), [`release-policy.md`](release-policy.md), [`public-beta-evidence.md`](public-beta-evidence.md), and [`../release-artifacts/README.md`](../release-artifacts/README.md) |

## Source-Of-Truth Boundaries

| Question | Canonical source |
| --- | --- |
| What must the permanent protocol do? | The specification inventory and precedence rules in [`spec-policy.md`](spec-policy.md) |
| Why was a protocol decision made? | Accepted decisions in [`adr/README.md`](adr/README.md) |
| How is the flat Solidity source tree organized? | [`solidity-source-map.md`](solidity-source-map.md) and its generated authoritative inventories |
| What does the current implementation and local evidence prove? | [`status.md`](status.md), [`architecture.md`](architecture.md), and [`audit-package.md`](audit-package.md) |
| What is still blocked? | [`known-blockers.md`](known-blockers.md), [`release-readiness.md`](release-readiness.md), and generated blocker reports under [`../release-artifacts/latest/`](../release-artifacts/latest/) |
| What work is ordered next? | [`../ops/ROADMAP.md`](../ops/ROADMAP.md) and [`../ops/EXECUTION_BACKLOG.md`](../ops/EXECUTION_BACKLOG.md) |
| What should integrations consume? | [`integrations/README.md`](integrations/README.md) and the generated release artifacts it identifies |
| How are releases checked? | [`release-policy.md`](release-policy.md), [`tooling.md`](tooling.md), and [`../release-artifacts/README.md`](../release-artifacts/README.md) |

If two normative documents appear to conflict, follow the ownership and
precedence rules in [`spec-policy.md`](spec-policy.md). Baseline, readiness,
and operations documents describe current evidence; they do not amend a
protocol specification.

## Document Families

- **Permanent protocol specifications:** start with
  [`spec-policy.md`](spec-policy.md), then use its specification inventory and
  the [`launch-conformance-matrix.md`](launch-conformance-matrix.md).
- **Solidity implementation:** use
  [`solidity-source-map.md`](solidity-source-map.md) to navigate the flat source
  tree and locate the generated contract and protocol-surface inventories.
- **Architecture and security:** [`architecture.md`](architecture.md),
  [`threat-model.md`](threat-model.md), [`audit-package.md`](audit-package.md),
  [`slither.md`](slither.md), and [`warning-dispositions.md`](warning-dispositions.md).
- **Integration:** the curated entrypoint is
  [`integrations/README.md`](integrations/README.md); examples and consumer
  guidance live below that directory.
- **Deployment and operations:** [`deployment.md`](deployment.md),
  [`dependency-operations.md`](dependency-operations.md),
  [`randomizer-operations.md`](randomizer-operations.md),
  [`monitoring.md`](monitoring.md), and [`incident-response.md`](incident-response.md).
- **Release and evidence:** [`release-policy.md`](release-policy.md),
  [`release-readiness.md`](release-readiness.md),
  [`release-signatures.md`](release-signatures.md), and
  [`non-local-release-evidence.md`](non-local-release-evidence.md).
- **Research and historical context:** documents labeled as research,
  baseline, or operational state are informative unless a specification names
  them as a normative home.

## Maintenance

- Keep this page short and organized around reader questions.
- Link to canonical facts instead of repeating measurements or readiness state.
- Add a document here only when it is an entrypoint or source of truth; the
  repository Markdown link checker discovers the complete Markdown corpus.
- When moving or renaming documentation, update local links and run:

```bash
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
```
