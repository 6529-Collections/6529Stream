# Original living delegation history hydration

`IStreamArtistDelegationAuthorityHydration.hydrateArtistAuthorityWithDelegations`
takes the unchanged `StreamArtistAuthorityHydrationTypes.Request` and selects
`6529STREAM_ARTIST_LIVING_DELEGATION_HYDRATION_V1`. It is an additive permissionless
operation-60 profile with the original seven-owner mask `0x7f`, one completion
per owner and one atomic Archive append. No new signed domain or Artist write
authority is introduced. The baseline and multiplicity selectors stay strict.

## Complete supported source

The source must contain exactly one original living class-1 Artist and one
accepted generation-one collection, with `PRIMARY_ONLY` collaborator policy and
consent mode 1 (signed) or 2 (delegated). Its actual registration allocator must
still be one. The complete admitted native journals are registration/proposal
1, acceptance 2, policy consent 14, sale consent 16, nonprovisional living
identity revisions 25, delegation grants 26, explicit revocations 27 and
authorization revocation 54. Per-owner revision equations also reject extra
operations that do not append a native receipt.

The original predecessor runtime, reciprocal source binding and complete op57
seal must name the successor. Both original final lanes must already be latched.
All seven source checkpoints, all native receipts and all source replay cells
are read from fixed owners and checked again after application. The original
eight non-Artist suite dependencies remain equal. Unsupported history refuses
before any destination owner writes; a receipt or caller list alone cannot
establish imported authority.

The caller supplies the original policy phase/hash pairs in actual Consent
receipt order and each replay surface/scope in actual checkpoint order. Revision,
grant, revocation and sale selectors come from the source's own complete native
journals. They are not caller-selected subsets. The new fixed-owner getter
`authorityDelegationHydrationState(Query)` is implemented by Binding, Identity
and Consent. Its three closed `abi.encode(tag, state)` envelopes are specified
by `IStreamArtistDelegationAuthorityHydration.sol`.

## Historical authority and fresh writes

Identity carries the original registration document, every supported revision
and document, all retained signature bundles, original activity values, every
grant version, exact current grant heads, use counts and revocation hashes.
Grant and revision hashes are independently reconstructed in the predecessor
Registry domain. Only original living delegation epoch zero is supported.

Both principal nonce kind 1 and delegate nonce kind 2 inventories are complete.
Every sparse prefix, all 32 ancestor words, exhaustion value and exact next-nonce
hint are retained. Replacement grants for the same delegate share that
delegate's original nonce lane. Replacing or importing a grant cannot resurrect
a consumed nonce or an explicit signature revocation.

Every policy or sale record retains its exact historical grant association;
the current replacement grant never substitutes for the recorded grant.
Complete delegated record counts must equal every grant's actual use count.
Sale records retain original terms, class, signer, nonce, binding association,
record hash and latest lookup head. Direct records retain class-1 authority;
delegated records retain class 2. No liveness check of today's grant rewrites
historical consent. In particular, expiration, exhaustion or later revocation
does not erase an already recorded policy/sale consent. Fresh successor writes
still run the original live grant, mode, scope, capability, deadline, revocation
and nonce checks and require the actual successor signing domain or an
authenticated direct Safe call.

The ordinary `applyArtistAuthorityHydration` guard, replay import, typed state
write, owner commit and end-of-operation history/payload synchronization remain
in their original order. Fixed hydration transports use compiler-declared
typed storage roots and original calldata. They introduce no storage aliases,
caller-selected delegate targets or new authority checks. A late Archive failure
reverts all seven owners, grants, nonce cells, lane activation and Safe nonce.

## Bounds and validation scope

The profile retains 128 native receipts per owner, 512 replay cells per owner,
128 nonce indexes and at most 256 total nonce prefixes. The complete evidence
must fit the unchanged 24,575-byte Archive carrier. These bounds do not promise
that all maximal combinations fit the carrier or one transaction. Long identity
documents, many signatures or many sparse nonce prefixes can require a later
larger-evidence profile.

The ten authored cases in `StreamArtistDelegationAuthorityHydration.t.sol` use
actual original and successor Registries, seven owners, Archive and threshold
Safes. They cover exact tagged evidence and original record parity, revoked,
expired, exhausted and replacement grants, successor-domain signatures, carried
principal/delegate nonce guards, durable sale consent, signed mode, omissions,
forged exports, guardian-history refusal and late Archive rollback with identical
retry. Core/governance and the explicitly named sale facts/catalog admission
are typed boundaries. No sale/payment or full current-Core execution is claimed.
ABI/source review, selected production sizes and native behavioral acceptance
are separate evidence; authored tests are not runtime passes.

## Remaining required combinations

This first ART35 slice does not complete migration. Multiple Artists/collections
with delegation, corrected/pending bindings, revisions made before the original
binding, collaborator policies, other delegated capabilities and their records,
nonzero epochs, guardian/rotation/recovery/estate/dormancy authority histories,
timing changes, payout/economics/readiness/publication/finding combinations,
prior imported generations and larger/paged evidence remain distinct required
profiles. Existing advanced single-identity profiles remain available separately;
this profile never silently discards their additional state.
