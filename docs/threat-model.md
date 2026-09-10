# Threat Model

This models the implemented current stack, **pre-audit and not production-ready**.
It is not an audit or a security claim. Read it with the
[architecture](architecture.md), [status](status.md), [known blockers](known-blockers.md)
and [private reporting policy](../SECURITY.md). The
[previous baseline model](reference/legacy-stack/threat-model.md) remains historical
reference; target requirements live in the [specification index](spec-policy.md).

## Assets

Protect NFT ownership and permanent identity, lifetime supply, phase counters,
artist consent, sale proceeds, auction escrow/refunds, immutable split entitlements,
entropy request identity/final seed, metadata and governance commitments. Deployment
compiler provenance and manifest publications bind which code/configuration those
assumptions describe.

## Actors And Trust Boundaries

| Boundary | Authority and consequence |
| --- | --- |
| Core to satellites | Registry admission, code identity and bounded gas/return parameters constrain extension use; they do not prove admitted code benign |
| Buyer to sale | Exact payer/value/token hash plus platform and artist EIP-712 consent bind execution |
| Sale/auction to manager/Core | Phase policy and counters remain authoritative; receiver failures must roll back cross-domain effects |
| Artist registry | Nomination is insufficient; accepted attribution authorizes sale/auction consent |
| Bidder to receiver | Callbacks are untrusted, refunds are credits, and failed settlement preserves accounting |
| Split wallet to recipient/asset | Immutable shares and release accounting precede transfer; redirecting another account's entitlement is forbidden |
| Coordinator to provider | Provider/request identity and mint-time coordinator bind output; configured Chainlink coordinator/subscription are external dependencies |
| Governance actors to Executor | Role checks, exact commitments, action classes and delays constrain mutations |
| Browser to artwork | Artwork is untrusted executable content; isolate it from application/wallet privileges |

## Threat Categories

Authorization and replay threats include wrong chain/domain, altered policy or
recipient, cancelled/consumed nonce, signer rotation, contract-signature misuse and
scope/token identity collision. Scope requests require registered scope identity,
so approved scope callers cannot reuse a token subject.

Value threats include reentrancy, rejecting receivers, settlement failure, stale
withdrawal displays, malformed assets and rounding assumptions. Native payment and
minting are atomic. Auction bid/refund obligations stay separate; failed settlement
or withdrawal preserves state. Forced deposits are not automatically official
revenue or an arbitrary caller's entitlement.

Entropy threats include unavailable/underfunded providers, mismatched or duplicate
callbacks, retained output delivery and attempted rerolls after stale/failed
tracking. Pointer replacement must not change existing tokens' seed source.
Metadata threats include oversized/gas-heavy responses, JSON escaping, unsafe
artwork execution and mistaking fallback output for complete content.

Governance threats include compromised signers, overbroad catalog entries, stale
commitments and incorrect genesis binding. The initializer commits the full plan,
separates preparation from atomic setup/seal, and closes permanently. Post-seal
operations retain ordinary delays and veto/role boundaries. Append-only catalog
extension admits exact targets/selectors/code hashes through root class-3 execution
and a matching manifest update; it is not wildcard authority.

## Assumptions And Non-Goals

Deployment selects module code, controllers, gas/time policy, platform signer and
VRF configuration. Development governance actors and controller-fed local entropy
are test tooling, not production signer/randomness designs. Cryptographic primitives,
chain consensus and the configured external VRF service remain assumptions.
Registry eligibility and tests do not imply external audit. This model does not
attest operational custody, provider funding or all target-specification behavior.

## Existing Controls

The [current suites](../test/current/) exercise real wiring, payment/custody
rollback, signatures, entropy, metadata and governance replacement.
[Domain tests](../test/README.md) cover isolated regressions. Production Slither
findings and scoped dispositions remain in [the baseline](../ops/SLITHER_BASELINE.md).
A false-positive disposition addresses that detector claim, not every possible
bug in the function. [Tooling](tooling.md) explains profile/provenance limits.

## Residual Risks And Open Blockers

External audit, reviewed custody/ceremony evidence, broader Artist V2/finality scope
and production operating evidence remain separate requirements. Use
[release readiness](release-readiness.md) and [the audit package](audit-package.md)
for exact current status. Do not infer parent-issue completion from a single flow
or historical deployment. Update this model when authority, payment, entropy or
callback boundaries change. Report exploitable defects privately under
[SECURITY.md](../SECURITY.md).
