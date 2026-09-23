# Royalty Resolver economic continuity

This profile implements exact replacement of existing frozen royalty routes and
mint snapshots under [RSR Resolver Replacement And Frozen Economic
Continuity](../revenue-splits-and-royalties.md#resolver-replacement-and-frozen-economic-continuity).
It adds no new freeze power. Primary Resolver replacement, new inherited/global
freeze behavior, changing the fixed maximum royalty, and an economics-changing
recovery remain separate work. A successor Artist registry is a different
authority transition and does not itself replace either economic Resolver.

## Protected state and original ledgers

The Royalty Resolver records an append-only inventory whenever its original
default, collection or token freeze succeeds, whenever a new token snapshot is
written, and whenever an immutable collection royalty mode is elected. An exact
already-written snapshot replay remains silent and adds no row. Each route
retains scope, real collection/token identity, original Resolver hash origin,
complete configuration/revision, original assignment/policy hashes and the
complete original snapshot. Explicit configured zero is a protected assignment.

These records are continuity witnesses. The existing default/collection/token
configuration and snapshot mappings remain the authoritative disclosure ledgers;
the export verifies the witness against those actual mappings. There is no
caller-supplied route list or replacement payment ledger. Clearing mutable
configuration does not remove historical frozen keys, and a burned token retains
its actual permanent Core collection identity.

The header commits to the chain, Core, common Factory, fixed maximum royalty,
complete route count/rolling root and complete election count/rolling root. An
explicit mode election is protected before its first snapshot. With neither a
freeze/snapshot nor an explicit election, the protected root is zero. Mutable
unfrozen configuration is not copied by this profile; configuring a successor's
future terms is a separate original authorized operation.

Assignment and policy domains originally include the Resolver address. Imported
routes therefore retain the original address in those exact preimages; their
public fact still identifies the actual serving Resolver. Multi-hop imports keep
each route's first origin. A newly created frozen route uses the Resolver that
actually creates it. Copied elections keep their original election and mode
wrapper domains. No synthetic Artist signature or approval is created. Future
live mutations and mint policy/Artist consent continue to use their original
authority checks.

## Saved transition

1. Deploy an unselected, pristine Royalty Resolver with the original constructor
   arguments, the same Core, Factory, maximum royalty and current owner. A target
   that has already made any economic mutation cannot begin an import.
2. Read `continuityHeader()` from the actual Core-selected source, retain its
   runtime hash, and enumerate `economicElectionAt` and
   `protectedEconomicRouteAt`. Validate every complete row and reconstruct the
   original rolling roots. The source export rereads its original ledgers.
3. Construct the canonical manifest, retain its actual ABI bytes and reference,
   then call `previewEconomicContinuity`. Its exact class-1 scope and old/new
   commitments must be scheduled through the canonical executing governance
   authority. `beginEconomicContinuity` verifies the current action, complete
   source header, current Core pointer/runtime, source capability/owner/Core
   binding and exact manifest. The current owner must still be the immutable
   constructor governance authority, with its captured runtime and canonical
   authority marker. Transferring ordinary Ownable ownership does not grant the
   replacement owner this continuity authority. The event emits bytes that hash
   to the saved manifest commitment.
4. Any caller, including a Safe with operation `CALL` and zero value, may call
   `importEconomicContinuity(maxRoutes,maxElections)`. One call admits at most
   16 routes and 64 elections; elections are copied first. Every chunk copies the
   next original producer rows into the original destination mappings, checks
   the source before and after, and preserves exact cursor/ledger rollback.
5. `completeEconomicContinuity` requires every count, rolling root and header to
   equal the saved source. Before completion, `economicContinuityReady()` is
   false and original economic mutations are blocked. A source tip change leaves
   that pending import unusable; there is no reset or retarget entry. Prepare a
   new pristine candidate and a new visible manifest when the protected source
   changes. Do not relabel an old plan as current.
6. Register the completed candidate through normal module admission, then use
   the separately implemented Core pointer guard and original class-3 pointer
   action plus its required SystemManifest tail. Core must reject a partial
   candidate even when the old root is zero. For a nonzero protected root, it
   must verify the same root, exact old source, saved manifest and
   `supportsEconomicContinuity(old,root,manifest)` before replacing the pointer.

The first five steps do not themselves change Core. The Core guard now rejects incomplete or mismatched replacements through
its existing linked read worker; the complete actual import-and-cutover workflow
still needs runtime acceptance. Deployment/copying alone
does not constitute a completed or approved cutover.

The manifest is `abi.encode` of the
`6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1` domain, chain ID, source address and
runtime hash, destination address, Core, Factory, complete Header, URI, URI hash,
`STREAM_ROYALTY_CONTINUITY_MANIFEST_V1` schema and
`STREAM_ROYALTY_CONTINUITY_ABI_V1` canonicalization ID. The fixed royalty-class
route domain commits `ROYALTY_ERC2981`, exact scope/identity, original hash
origin, full config, assignment/policy, freeze mode 1 and complete snapshot.
The ABI enum/tuple field order is the compiler-selected interface, not an
independently maintained JSON schema.

Preserve the saved manifest, governance action, full Safe transaction and nonce
separately. A failed zero-refund Safe call can retry byte-identically after a
temporary dependency is restored; it must not be re-signed under changed fields
and reported as the original retry. Completion is an immutable historical fact;
the live `supportsEconomicContinuity` read also checks the present source/root,
so later protected writes can make that old live comparison false without
rewriting the historical import record.

## Gas and evidence

The unchanged constructor registers one dedicated namespaced
`ROYALTY_CONTINUITY_READ_GAS` parameter with initial value/floor 500,000. It uses
the existing GGP V2 scope/state hashes, exact canonical authority/runtime/context,
class-1 monotonic raise capped at twice the current value, and action replay
guard. No provider gas parameter is borrowed. Reads copy only fixed expected
return sizes and clip their forwarded gas to the available frame budget while
reserving decoding/error gas. The original ordinary storage prefix is unchanged.

All eleven focused unit/Safe cases pass in the retained
`royalty-continuity-native2-20260916` capture (77 sources, 63.828 seconds).
They execute actual Resolver/Factory/Wallet and threshold Safe code; Core,
Artist and governance-context doubles remain explicitly scoped. The first
immutable-source capture passed two and failed nine before continuity execution:
the fixture registered a split profile without deploying its wallet. The fixture
now calls the original Factory deployment and verifies its predicted address and
existence. That failed capture is retained; no production rule was relaxed.

Two separate actual-current Artist/Core/Manager/Executor/Safe cases remain
unexecuted here. They start with genuine op15 terms, paid dynamic primary mint,
configured-zero or positive default-source snapshot, and real catalog/manifest
governance; the positive case continues to same-NFT private custody resale.

The 1,032-source ABI/storage check passes. All 70 original ABI entries and all
five original recursive Royalty Resolver storage roots remain exact. The
initial selected production capture found all six products within limits. The
canonical-authority correction was independently source-reviewed and recompiled
for its two changed products: Resolver 24,281 runtime bytes / 25,900 creation
bytes, and Parameters 1,826 runtime bytes. Unchanged products retain their
recorded measurements: Import 13,815; State 5,450; AssignmentHash 2,334; Snapshot
11,504 runtime bytes. The host has 295 bytes of runtime headroom; combined
build sizing and cold read gas remain acceptance work. The focused native run
also measures all 21 production products within limits and reproduces those six
measurements. These are scoped unit results, not actual-current cutover,
deployment, release acceptance or a general protocol audit.

### Core replacement regression evidence

`StreamCoreRoyaltyContinuityAdmissionTest` executes seven actual-Core cases:
partial import even with an empty old root; root/source/manifest/proof mismatches;
reverted, short, oversized and noncanonical responses; source runtime drift;
protected source changes; and a foreign Core or dirty address word. Failed
updates retain pointer/revision and the same saved class-3 action retries after
the boundary is repaired. The two existing Artist-history pointer cases and
twelve permanent-target cases also pass in the same 21-case capture.

Royalty producers, module admission and governance in this focused capture are
typed boundaries. It does not establish a completed actual Resolver import or
full current-governance cutover. First installation and same-address catalog
refresh keep their original behavior. Marketplace royalty reads are unchanged.
