# Artist native lanes and successor history admission

This source implements the original AA-RECORDS accumulator and operations
55–57 of [AA-IMPORT](../stream-artist-authority.md). It does **not** complete
successor authority hydration or the full AA-IMPORT conformance round-trip.
The authored tests have been typechecked; native execution, linked deployment
sizes, transaction capacity and current-graph governance remain pending.

## Native records

`IStreamArtistHistory` is additive. Existing interface IDs, signatures, owner
snapshots, record hashes and Archive payload domains remain unchanged. Each of
the seven fixed owners exposes an append-only typed journal of records it
actually creates. Referencing an existing acceptance or executing an already
recorded rotation/estate request does not create a second record. Recovery's
two original records remain two entries, including a repeated empty
supersession-set hash in a later valid recovery. Dormancy cancellation records
created by authenticated liveness are included even when the surrounding
operation creates another record.

At the end of each atomic Coordinator operation, fixed owner-index order and
each owner's local receipt order define the canonical append order. This is
the lane ordering rule; it does not infer an ordering from legacy log positions.
Records carrying an Artist key append to that Artist lane. Collection records
append to the collection lane as well; collection-only platform and claim
records have no invented Artist key. The old global per-owner record tip is a
separate domain and is never substituted for either canonical lane.

The accumulator is exactly
`keccak256(abi.encode(RECORD_CHAIN_DOMAIN, previous, recordHash))`, with
`RECORD_CHAIN_DOMAIN = 0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e`.
`artistRecordChainHash`, `collectionRecordChainHash`, `artistHistoryLane` and
zero-based `artistHistoryRecordAt` expose the resulting lanes. A schema-1
`ArtistRecordChainAdvanced` event carries every link from the actual Identity
owner. The separate `artistHistoryContinuityCommitment` commits receipt
composition and import/cutover state. This namespace adds no mutable state to
Coordinator or Archive and does not alter the original seven owner-root recipes.

The journal and lanes begin at this implementation's deployment. They do not
retroactively recover missing native receipts from an older deployed binary.
The fixed owner cohort emits at most 128 newly queued receipts per operation;
exceeding that bound reverts the entire operation. No permissionless caller can
submit a native receipt to the Identity owner.

## Commit, replace, verify

1. Export every predecessor lane and running chain value at `snapshotBlock`.
   Build the original double-hashed AA-IMPORT leaves and sorted-pair Keccak
   tree. The manifest commits that dataset and identity table; this transaction
   stores its hash, not the manifest bytes or an assertion of completeness.
2. Read `artistHistoryImportContext(predecessor, block, root, manifest)` from
   the successor. Stage the exact class-1 governance context and use the
   manifest hash as the action's reason/evidence commitment. Execute
   `commitArtistHistoryImportRoot` through the original Executor. Operation 55
   checks the executing per-call context, full action header, exact
   predecessor/Core/capability/runtime, next binding index and original replay
   surfaces. Bindings are append-only. Follow-up roots may reference the same
   direct predecessor; this implementation does not merge unrelated registry
   lineages into one successor.
3. Core's Artist replacement path rechecks the successor's exact committed
   predecessor and runtime hash. Initial installation and same-target no-op
   handling are unchanged. The check is admission, not proof that all imported
   authority is ready. Do not operationally replace a live registry until the
   missing consumers below are implemented and validated.
4. After the pointer changes, permissionlessly call `verifyImportedLaneTip`
   using a root containing the final tip. A stale snapshot fails if the
   predecessor accepted another record before cutover; commit a follow-up
   root including it. Operation 56 compares the actual predecessor tip, count
   and terminal record against the proof. Root membership alone cannot install
   a forged terminal record. The verified latch is permanent and never
   re-evaluated. Historical index reads use the pinned predecessor's exact
   record reader after that latch, retaining original IDs and chain values.
5. Anyone can call `observeRegistryCutover` on a predecessor that demonstrably
   served while selected (native receipt composition, verified imported lane,
   or an import commitment made while current). A never-served candidate cannot
   be permanently disabled by a premature permissionless call. An empty line
   with no such observation cannot latch; deployment alone is not proof that
   Core once selected it. Operation 57
   permanently records the successor and observed block. Ordinary Coordinator
   writes already check the live Core pointer on every invocation; the latch
   continues to reject them if the pointer is later returned. Historical lane
   reads remain available.

Operations 55–57 use the original Identity-only semantic owner mask and named
replay surfaces. Their operation evidence appends atomically to the fixed
Archive. Failure in the final evidence/payload step rolls back state, journals,
lanes and replay together. New receipt bookkeeping on operations 20/21 observes
only their existing successful records and changes no freeze authority rule.

## Authority hydration still required

A Merkle member or verified tip is historical evidence, not an authority
installation. This batch deliberately rejects native writes into any existing
predecessor lane, including a verified lane, with
`ArtistHistoryImportedAuthorityUnavailable`. It does not silently start a new
chain over the predecessor or invent a new identity for an imported lane.

The remaining typed consumer bridge must implement and test all of these:

- Preserve the exact predecessor identity table, current principal/class/status,
  nonce/replay state, delegations, rotation/dormancy/estate/recovery history,
  guardian prefixes/exclusions and provisional/closure eligibility.
- Hydrate binding generations, accepted collaborators, attribution/dispute and
  platform correction histories, payout designations and their associations.
- Reconstruct and admit original consent, attestation, sanction, recovery
  approval and finality records from complete retained preimages. A root member
  needs an authenticated position in the verified lane, not merely a matching
  hash elsewhere in the tree. Bytes never retained cannot be claimed as loaded.
- Route current consent/finality/verification consumers to that typed state
  under their existing current-binding and authority checks, preserve old
  record domains, and extend the verified imported accumulator on new writes.
- Exercise lazy and bulk imports, multiple generations, complete payload
  reconstruction and real current-graph governance before claiming AA-GATES 14.

The present historical index reader serves pinned predecessor data; it does
not copy record preimages into the new Archive, populate current owner state,
or grant mint/royalty/metadata authority. The authority hydration list is a
remaining implementation obligation, not an optional audit step.

## Authored validation

`StreamArtistHistoryImport.t.sol` uses actual two-registry Artist owners,
threshold Safe and Archive. Core selection and governance execution remain
explicit typed unit boundaries. It covers native prefix folding, late Archive
rollback and byte-identical Safe retry, pre-cutover refusal, stale snapshot
repair, forged terminal denial, permanent cutover and blocked unhydrated writes.
`StreamCoreArtistHistoryAdmission.t.sol` separately calls the actual Core
replacement entrypoint, with typed module/governance/Artist-read boundaries,
covering initial installation, missing/foreign/malformed admission and saved
action retry. These two scopes do not imply a joined actual-Core succession.

For the Artist aggregate harness, the repository wrapper command is:

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistHistoryImport.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824 -vvv
```

The large limits permit the aggregate fixture's CREATEs and multiple operations;
they are not transaction-capacity evidence. No native run is claimed for this
source batch.
