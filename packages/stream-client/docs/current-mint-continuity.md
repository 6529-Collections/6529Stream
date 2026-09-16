# Current mint counter profiles and continuity

`current-mint-continuity.ts` prepares the current counter-definition and bounded
Manager/Ledger import calls. It never retires a writer, activates a Core pointer,
sends a transaction, signs, or claims a Safe threshold accepted a call.

## Authority and order

1. Independently verify and permanently retire the predecessor Manager writer.
2. Snapshot after retirement and review a complete inventory of normalized
   counter leaves, pinned profile selections, and raw gate nullifiers.
3. Build and durably publish the client manifest artifact. The client canonical
   profile is `STREAM_CLIENT_MINT_CONTINUITY_MANIFEST_V1`; it is an external
   document format, not a protocol-standard claim that the inventory is exhaustive.
4. Execute the returned class-1 governed transition. `prepareMintImportCommit`
   returns the exact scope, zero old hash, new hash, and target call. The target
   call is valid only inside the Ledger owner's authenticated `currentAction`.
5. Permissionlessly copy definitions and the predecessor's older Manager ancestry
   in separate `1..32` chunks. The commitment already records the immediate
   predecessor, so a first-generation replacement reports ancestry progress `0/0`.
6. The successor Manager owner imports explicitly selected batches of at most 32
   counter plus nullifier leaves. Reconcile receipts/events by leaf hash. Aggregate
   counts do not reveal which leaves were already used, especially on one Ledger.
7. Complete with the exact counts and descriptor proof after both copy cursors
   finish, then inspect the exact
   predecessor-Ledger/Manager and successor-Manager readiness tuple before a
   separately governed Core transition.
8. After the actual Core cutover, configure successor phases and executors.
   Successor-bound policy consent is fresh consent under the original Artist
   signature domain; continuity does not create or carry that consent.

The predecessor and successor Managers must differ. Their Ledgers may be the
same. Counter namespaces and raw nullifiers are retained exactly. Address subject
bases use canonical zero-padded addresses; CONSTANT uses zero and CONTEXT uses a
nonzero context hash. First use permanently selects registered or legacy profile
interpretation, so inspect `counterDefinitionForManager`, not only the global read.
Its `exists=true` result is the effective defined interpretation and may still be
an unseen globally registered definition; it does not prove a prior first-use pin.

## Evidence boundary

The artifact JSON parser reconstructs every manifest byte, leaf, proof, descriptor,
and root. The supported durable format is bounded to 4,096 combined inventory
rows and 16 MiB of canonical JSON. This supports restart after receipt
reconciliation. It does not
discover historical counters/nullifiers or prove the supplied inventory complete.
Pinned reads require a concrete block number and report that they do not protect
against a later reorg. Runtime governance, owner authority, code identity, receipt
history, fresh successor policy consent, and the final Core activation remain
separate checks.
