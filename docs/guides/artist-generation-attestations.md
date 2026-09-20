# Pending generations with recovered attestation history

This extends the existing operation-60 recovered profile in
[ADR 0047](../adr/0047-complete-artist-authority-hydration.md) and the
[recovered authority guide](artist-recovered-authority-hydration.md).
It combines two existing capabilities; it adds no operation, signing domain,
Registry/Coordinator selector, owner storage field, or request codec.

## Supported graph

One original class 1 or class 3 recovered Artist and one PRIMARY_ONLY mode 1
collection may have two to 128 original pending generations. Every earlier
proposal ends in original refusal 3 or withdrawal 4; only the final generation
is accepted. Its complete original operation 24 history now travels with the
complete pending-generation history, direct operation 14 policy history, and
existing supported Identity/Payout recovery history. Repeated imports keep
original environments and original native coordinates.

This covers the existing operation 24 subjects, including readiness, deployment,
publication kinds 7/8, personhood evidence or waiver, and ordered C2PA credentials.
It does not replace an accepted binding, fabricate a correction 53, or broaden
class 4, collaborators, grants, mode 2, economics 15, sale 16 or content 17/20/21 in
this combined generation profile. Those combinations remain separate work;
unknown or unsupported source journals fail before import.

## Exact source proof and encoding

Use the original `StreamArtistRecoveredHydrationTypes.Request` and
`hydrateRecoveredArtistAuthority` entry. Every source/destination owner must
advertise both `ATTESTATIONS` (128) and `BINDING_GENERATIONS` (512), along with
all other features required by the source history. The original seven-owner
capability/header checks still apply. An owner 4 import for generation above one
also explicitly requires bit 512 before any map, payload or derived-head write.

The complete source journals determine the witness count. With operation 24,
there must be exactly one collection witness, containing exactly every original
attestation's terms and nonce in native order. Missing, duplicate, extra,
foreign-subject or reordered witnesses cannot select a subset of history.
No economics witness or royalty-freeze terms are admitted by this graph.

Owner0's original generation bundle still proves every original proposal,
terminal, document and final acceptance. Its full validator and cross-owner
Identity signature/nonce join run before attestation collection. Its current
generation must equal the actual original Attribution owner's accepted state.
The attestation bundle is then independently collected from that same source;
its full rows, complete source heads, schema and original hashes are validated.
The final join revalidates this complete bundle and passes its exact generation
and all rows to the original Identity signature, nonce and observation checks.
No caller supplies a stand-alone generation, partial receipt set or new signer.

For owner 4's first era, N pending generations contribute exactly 2N revisions:
proposal/termination updates and final acceptance. Each original24 occurrence
then contributes one revision. Every later imported era retains its original
lower revision 1 and contributes only its own exact native occurrences. These
are separate per-owner clocks, not an invented cross-owner revision ordering.

Every stored attestation, association, deployment preimage, publication evidence,
personhood summary and C2PA head uses the exact final accepted generation.
Historical record hashes still use their original Registry environment;
publication evidence and documentary summaries retain their original domains.
Neither import nor the source proof reruns historical signatures or promotes a
past authority into permission to write now. Old personhood staleness and
waiver semantics are unchanged.

The original Bundle/PersonhoodRow types, semantic schema/version, request and
page/header encodings remain. Generation-one rows still take the original
`Joins.attestations` path. Original complete owner guards, native/replay imports,
post-apply roots, final source reread, seven-owner commitment and atomic Archive
append are unchanged.

## Validation scope

Ten new cases are authored: five actual Artist/Registry/Coordinator/Archive/Safe
recipes, four pure original-row join vectors (including bounded-generation fuzz),
and one typed preparation-stage witness test. The actual recipes cover original
refusal/withdrawal before final acceptance, direct readiness/deployment/waiver and
C2PA rows, a second import with a fresh successor credential, missing witnesses,
nonce/capability/source mismatch, wrong row/association/current generation, and
late Archive rollback with an exact Safe retry. The rollback oracle counts two
calls to the same independently derived first evidence page, so retry alone
cannot satisfy a premature-failure test.

The actual recipes retain typed Core/governance/subject boundaries from their
existing fixture. Pure vectors and the stage test are explicitly component
proofs. Canonical resolved-personhood and publication transport rely additionally
on the retained original owner-codec cases; the new actual recipe does not claim
new full documentary/notarization or Metadata publication execution.

These new tests have been typechecked, not run. The frozen final ABI capture has 1,163 sources and no errors; all 26 original ABI
entries and 14 original nominal method selectors across the eight changed fixed
workers remain. None owns storage; the actual owners and their layouts are unchanged.
The final eight-product capture uses Solidity 0.8.19, viaIR, 200 optimizer runs, Paris and no CBOR,
and every selected product fits. Runtime bytes are Preparation 24,418, generation
stage 16,437, attestation host 23,521, validator 16,054, collector 14,107, facts 5,188,
row join 16,553 and generation facts 7,611. Each is a fixed library with no
constructor arguments; all creation images also fit. Selected deployment sizes
are recorded with exact input/output source hashes in the handoff; the first new Preparation image exceeded the limit by
45 bytes and that failed capture is preserved. This does not establish full
current-stack runtime, maximum carrier, cold-gas, transaction-cap or launch
acceptance. Protocol size/gas limits and held feature proposals are unchanged.
