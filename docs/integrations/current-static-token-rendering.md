# Current STATIC token lifecycle

This authored family starts from integration
`6cce620ac27e4fc202b4cb72501fccf926e4d2ad`. It connects actual minted tokens to
the original STATIC renderer. Native execution remains pending; an ABI check
establishes source compatibility, not a runtime pass or STATIC conformance.

## Original graph and authority

The [fixture](../../test/helpers/CurrentStaticTokenRenderingFixture.sol) inherits
the original [current stack](../../test/helpers/StreamCurrentStackFixture.sol)
and [official Safe fixture](../../test/helpers/OfficialSafeFixture.sol).
Core, Manager, Ledger, Fixed Price Sale, Artist Registry and owners, Governance
Executor, ModuleRegistry, Metadata, Renderer Registry, Renderer and Entropy
Coordinator are original products. The inherited upstream entropy provider is
an explicit test double. A separate buyer-selected receiver naturally rejects
the ERC-721 callback until its controller repairs it.

Four distinct Safe 1.4.1 accounts use threshold two: governor, Artist, buyer and
an unauthorized control. They share test signing keys but retain separate
addresses, signature domains and transaction nonces. The governor replaces the
fixture's initial governance root through the original delayed action. It then
schedules actual catalog/module admission and collection configuration.

The inherited collection 1 already has first-release ratification. This family
creates collection 2 with maximum supply five, captures the exact global STATIC
default before ratification or minting, and onboards a fresh Safe Artist through
the original Registry. Its distinct immutable split PROFILE pays 90% to that
Artist and 10% to the protocol. Actual Artist transactions record payout,
economics, deployment, personhood-waiver, content and phase-policy evidence.
The original Fixed Price Sale receives platform and Safe Artist signatures;
the buyer Safe pays exactly 1,000 wei for token 1 / collection serial 1.

The renderer retains original deployment size guards and source pins. The
fixture's renderer dependency read budget is 2 million gas, optional attribution
budget 8 million and Registry golden budget 20 million. Original delayed gas
governance raises the Router renderer frame from 8 to 16 million and Core's
Router frame from 12 to 24 million, each by one permitted doubling. These are
explicit fixture settings to make room for nested calls, not accepted launch
defaults or measured capacity. Native execution must determine sufficiency.

## Five authored cases

The [host](../../test/current/StreamCurrentStaticTokenRendering.t.sol) covers:

1. **Pending to finalized.** An actual paid mint produces pending marketplace
   JSON with exact opaque token bytes and no invented seed/hash. Full HTML and
   JSON refuse unfinalized entropy. Router and Renderer reject a different Core.
   An actual buyer Safe request and upstream callback finalize the original
   Coordinator; the final output uses independently reconstructed seed and HTML.
2. **Captured default continuity.** Changing the global default preserves the
   minted token's original selected record and output. A newly created,
   unminted collection 3 activates against the new default revision.
3. **Artist consent and exact retry.** The Artist Safe records original op17
   consent for a HYBRID token override. A different Safe, a genuine module of
   the wrong kind, and changed unsigned input all fail without consuming consent
   or changing config history. The saved governor Safe transaction succeeds
   unchanged, records the exact selection and override commitment, and renders
   the literal offchain URI. Repeating the same write fails.
4. **Burned identity.** The actual owner Safe burns token 1. Exact Transfer and
   StreamTokenBurned receipts preserve collection/serial evidence. Lifetime
   mint count and next serial remain unchanged. ERC-721 tokenURI refuses the
   burned token, while full STATIC output retains its original data, seed,
   Artist and burned disclosure. Payment remains settled.
5. **Receiver rollback.** The real receiver callback rejects after mint
   preparation. Core identity/data/preparation, Manager nonce, Ledger counter
   and authorization, sale consumption, payment and entropy state return to
   their expected initial values. Repairing only the receiver allows the
   byte-identical buyer Safe transaction to succeed once, after which the
   original token completes reveal and rendering.

## Independent oracles

Expected values come from literal fixture inputs and explicit transition counts.
The tests reconstruct the Ledger subject/value keys and sale authorization ID,
provider request key, full entropy seed preimage, Registry read-set and
registration commitments, config record hash and override history head. They
check original receipt topics and ABI data, authorization grant provenance,
token IDs/serials, selected source runtimes and Safe nonce rollback.

The entire expected HTML document and STREAM_CONTEXT_V1 JSON are written from
literal inputs. Full and marketplace JSON must contain exact expected fields,
including the actual Safe Artist, accepted attribution, data bytes and HYBRID
URI. Core tokenURI is also checked against the Router JSON envelope; that check
is surface consistency, not a separate independent serializer oracle. Production
previews supply signing inputs only. The helper restores the record hash after
checking its zeroed-field commitment, preserving the caller's in-memory record.

## Admission caveat and remaining acceptance

The copied genesis admission recipe intentionally retains a **synthetic partial
direct-read analysis document and a self-derived empty golden vector**. They
exercise the original governance/Registry join only. They are not a complete
transitive read inventory, independent conformance report, accepted golden
corpus or institutional evidence. Existing genesis fixture sources are
unchanged. See [STATIC routing](static-metadata-routing.md),
[renderer versions](static-renderer-versions.md) and
[Artist display](artist-static-display.md) for the relevant source contracts.

A coordinated native capture must include this exact five-case host through
the existing [acceptance wrapper](../../tools/development/run_current_acceptance.py),
use the final joined production sources and preserve original EIP-170/EIP-3860
and gas guards. This family does not establish cold-gas capacity, large script
or dependency support, provisional identity maturity/rotation, C2PA adoption,
SCOPED/finality acceptance, other Safe versions, complete release inventory,
audit readiness or testnet readiness. Production, shared runner/catalog files,
earlier fixtures and immutable RC1 evidence remain unchanged.
