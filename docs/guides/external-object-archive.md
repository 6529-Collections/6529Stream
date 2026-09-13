# External whole-object archive evidence

`StreamExternalArtifactCoverage` is a separate bulk-object preservation backend.
It preserves the whole external object's Keccak256, SHA256, native Arweave data
root and uint64 byte size. The descriptor's bytes never stand in for those bytes.
Existing bounded ArchivalCoverage, ArweaveInclusion and ArtifactCoverage profiles
keep their existing meaning and implementation.

This backend implements the external-object allowance in LTA-CATALOGS rule 4
and the original-receipt and independent-fixity joins of LTA-FINALITY rule 11
and LTA-ARCHIVE rules 1–3. It is a prerequisite for reference-render publication;
it does not itself establish reference-render, finality or full preservation
program conformance.

## Original evidence

1. Anyone may retain an object declaration. Its schema, canonicalization and
   format/catalog values are unverified declarations at this stage. A consuming
   record profile must authenticate the complete registered definitions and
   selected format entry. Declaration alone creates no archival coverage.
2. The actual governed family admission pins taxonomy dimensions and the storing
   agent. Endowed rows require the named Arweave mainnet external-object quorum
   profile; institutional rows require the named HTTPS possession profile.
   Same-name rows are separately admitted immutable taxonomy versions. They do
   not imply a latest version and cannot count as distinct families.
3. Each original receipt is signed by its family's storing agent, through EOA,
   bounded ERC1271, or the actual direct caller. The exact locator and signature
   are retained. A direct Safe call identifies that Safe as the storing agent.
   The endowed locator is the exact 32-byte transaction ID. The institutional
   locator is a closed ASCII HTTPS/DNS-label form with a nonempty path; there is
   no DNS, availability, TLS or retrieval assertion from syntax validation.
4. `StreamArweaveObjectCheckpointVerifier` authenticates an observer quorum's
   transaction-ID/root association under its own configuration and EIP712 domain.
   Native annotated Merkle paths prove the declared transaction range, data root,
   object size, and first/last chunk endpoints. Full proof paths and the original
   observer certificate remain available. This is explicitly a named quorum
   trust model, not an Ethereum verification of native network consensus.
5. A separately authorized `ROLE_FIXITY_OPERATOR`, distinct from the receipt
   writer, signs exact expected **and** observed whole-file SHA256, Keccak256,
   native data root and byte size, plus the original receipt, object, family,
   locator, profile, report, predecessor and replay fields. Passing fixity
   requires all four observed values to equal the declared object. The operator
   is attesting to full retrieval and computation; Ethereum does not read the
   complete external file. Native endpoint paths alone do not establish either
   flat hash or validate omitted middle bytes.

Both receipt and fixity signatures use the new coverage contract's EIP712
domain. Checkpoint signatures use the new checkpoint contract's separate domain.
Original evidence and signatures survive role revocation. A new fixity requires
the current role. Receipt deadlines govern admission, not historical expiry.

## Current coverage and repair

Coverage needs exactly an endowed inclusion receipt and an institutional
possession receipt for the same full object. Family identity, network, protocol,
addressing, custodian, funding, retrieval and storing agent must be distinct;
jurisdiction may coincide. These are governed declarations, not an inference of
real-world organizational independence.

Both receipts must have latest passing fixity. A later failure invalidates old
coverage without deleting it. A subsequent pass requires an explicit repair
report and exact latest-fixity predecessor; recording a new coverage entry never
rewrites the old entry. Each current read rechecks pinned Core, Executor, roles,
checkpoint graph/configuration, active family status and both latest fixities.
This is not an annual/quarterly scheduler or a cadence gate. The preservation
program must separately enforce due dates and cycles.

The Core/module/Executor graph is fixed independently of caller-supplied object
metadata. Family admission/status changes require the actual class-1 current
governance action with its exact scope and old/new state hashes. Gas parameters
are separately governed for fixed-size reads and signature verification.


The additive `IStreamExternalArtifactCurrentPair.currentReceiptPair` returns
fourteen unsaved current facts for two explicitly supplied **original receipt
hashes**, expected artist and expected whole object. It reuses the exact same
context, independent-family, native-checkpoint and latest-passing-fixity checks.
It does not record coverage, choose another receipt or change `requireCoverage`:
even a later PASS still makes an old recorded coverage fail that original exact
head check. Current availability can recover after an authorized failure/repair
chain for the same receipts without rewriting a locked reference publication.

A reference consumer must retain the original coverage and both original
receipt/fixity identities in its immutable record. At every current read it must
compare this new pair's complete object, artist, profile, family, receipt and
checkpoint identities to those saved originals; only the latest fixity hashes
may differ. Those later observations are current evidence, never retroactively
part of the original publication hash. Family suspension and changed pinned
graph still fail immediately. Original signer role revocation does not erase
admission; a new fixity requires the current role. This read adds no elapsed-age
freshness rule or annual/quarterly cadence scheduler.

## Runnable fixture and limits

The public test fixture identifies a real locally packaged 253,440,410-byte
Windows browser/toolchain archive, not a reduced browser descriptor. Independent
upstream chunking reconstructs all 967 native chunks and the root used by the
contract tests. The archive's flat SHA256 is
`d2eabd7dffeed4f37632e9e8d5a861d7fe5df621d66e62cd43234ecb9a572417`.
Its native storage root is a distinct value. No raw-CID equality is inferred.

The archive has been restored from its complete ordered transport parts and run
from that fresh folder. The test's observer network checkpoint, institutional
receipt and fixity signers are explicit local fixtures. They demonstrate actual
contract execution with the real object's commitments; they are not public
Arweave upload, institutional acceptance, public delivery or independent human
verification. The native Windows environment has separately pinned OS/runtime
prerequisites and an undetermined proprietary-browser license basis; it is not
a self-contained operating-system image or a permission to redistribute Chrome.

The actual RoleRegistry composition follows the IR compiler route. The new
production contracts and isolated native proof tests compile in both profiles.
The current-read probe cools five named contracts and measures a 2M-gas callee
budget; it is not complete cold finality-provider capacity. Reference-render
source/sample/classification, complete registered schema/format interpretation,
sale-follows deadlines, archival cadence, actual public delivery and final
aggregate consumption remain separate admission work.
