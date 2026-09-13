# ADR 0033: Engineering rehearsals and collector gas

Status: Accepted for autonomous development and testnet engineering rehearsals.

Issue: [#743](https://github.com/6529-Collections/6529Stream/issues/743).

## Decision

Continue functional implementation, integration and explicitly identified
engineering deployments on local chains and testnets while collector-gas
compliance is being resolved. These deployments use test assets and preserve
their exact source, configuration, transaction inputs and measured outcomes.
They are development evidence and cannot be designated a conforming release
candidate on the strength of this exception.

The numerical ceilings in [MPA-GAS-BUDGET](../mint-policy-and-accounting.md)
remain unchanged. A measured exceedance remains a failed gate. Passing them
still requires the specified all-cold measurements before a conforming
candidate or production deployment. Any proposal to change those ceilings
requires its own reviewed semantic amendment.

This is a narrow exception to the requirement to slim a path before any
deployment. It permits experiments needed to complete and measure the system;
it does not change contract authorization, accounting, reconstruction,
governance delays, or the full feature target. A live provider, archival quorum
or institutional compatibility claim requires evidence for that claim.

## Evidence and implementation direction

The independently reviewed clearing optimization at `1407caf3` reduces its
measured domain-fixture first purchase to 2,271,876 gas and repeat purchase to
1,672,429 gas. These are in-test spans, not all-cold transaction maxima. The
single-step ceiling remains 500,000 gas. The optimized actual-current composed
path must be measured separately.

The domain storage census identifies 35 new consumer words and 13 new official
recorder words. Those 48 production writes alone cost at least 960,000 gross
storage-write gas before other execution. Incremental consumer-only savings
cannot close this gap. The integrator owns a shared storage and execution
design covering the consumer, recorder, Manager and Core, with a measured
vertical experiment before adopting a replacement.

Historical keyed reads, exact credit accounting, independent replay and atomic
rollback remain required. An offchain receipt or claim witness would change
those interfaces and cannot be substituted as an unreported optimization.

## Rehearsal reporting

Each engineering rehearsal records the chain, exact source/build, configured
limits, wallet versions, state preparation, transaction gas and failures. A
runner's transaction allowance is reported separately from the normative gas
ceiling. Broader behavior cannot be inferred from a small fixed-profile example.

Preserve the published RC1 tag and evidence. Subsequent engineering deployments
receive distinct identifiers and cannot replace its historical results.
