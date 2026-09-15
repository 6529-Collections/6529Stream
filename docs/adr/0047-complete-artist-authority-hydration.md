# ADR 0047: Complete typed Artist authority hydration

- Status: Accepted integrator decision for the developing full-v1 implementation.
- Date: 2026-09-15.
- Validation: authored source scenarios and ABI checks; native behavior, sizes,
  current-stack governance and release acceptance remain pending.

## Decision

Adopt permissionless operation **60**, `hydrateArtistAuthority`, as a distinct
recipe with seven-owner read, snapshot and write masks **0x7f**. The original
operations 1–57, dismissal 58 and steward grant 59 retain their original scope,
domains and recipes. In particular, operation 56 remains a lane-tip proof and
does not grant authority. The [operation matrix extension](../architecture/artist-operation60-authority-hydration.json)
defines the new typed transport and atomic Archive evidence.

The caller supplies verifiable selectors and expected source headers, not a
signature or an authority assertion. The fixed Coordinator reads the actual
governed predecessor, its pinned runtime and reciprocal configured suite. The
predecessor must have completed operation 57 naming this successor. Both the
Artist and collection lanes must already be permanently verified under the
operation-55 binding and operation-56 proofs. Every fixed source owner must
advertise the actual producer checkpoint schema. Every current replay cell and
every typed nonce prefix must be accounted for; omitted keys or stale headers
reject the whole operation. Current cells do not independently reconstruct the
producer's rolling update roots: those roots are authenticated through the
actual fixed owner and checked again after destination writes.

The initial complete profile is one original, class-1/status-1 living Artist and
one accepted generation-1 collection with no collaborators. The complete native
receipt journals must consist only of original registration/proposal (1),
acceptance (2), policy consents (14), and authorization revocations (54). Exact
per-owner revision counts also reject unrelated operations without native
records. Changed Identity timing parameters and prior imports are excluded.
All selected non-Artist dependencies remain identical between the two suites.
Original identity/document, binding terms, acceptance, attribution, policy
heads, signatures, liveness counters, nonce words and complete replay guards
are carried together. There is no guessed empty advanced history.

Historical record IDs and signatures retain their original domains and bytes.
Logical guard surface/scope preimages are independently matched to every
inventoried source key, then rekeyed using the successor's original owner
domain. A consumed or revoked nonce and a used policy scope therefore remain
unavailable. Exact digest revocations retain their digest identity; a different,
fresh successor-domain authorization is a new signature, not execution of an
old signature. All original cells remain available by their original source
keys. The predecessor's instance-local operation-57 latch is historical only:
copying it into the successor's active latch would incorrectly pre-consume the
successor's own later cutover. No other baseline guard is exempted.

Only after the complete profile is collected does the Coordinator call the
seven owners. Each uses its original caller/operation/snapshot guard and state
commit recipe; hydration has its own one-use commitment. The Identity lane
activation, all owner writes, Archive evidence and stored-payload catalog sync
share one EVM transaction. A late failure restores all of them. There is no
public raw-storage copier, new signer typehash, or partial readiness flag.

Subsequent native records use the original lane accumulator and sequence after
the immutable imported prefix. Historical index reads continue through the
pinned predecessor; native suffix reads use successor storage. Hydration
itself is an operation receipt, not a duplicate original semantic record.

## Continuing full-v1 obligations

Additional identities/collections, repeated imports, collaborator dependencies,
payout/economics/content records, attestations, grants, guardians, rotations,
estate/dormancy/recovery histories and their complete conditional dependencies
need explicit typed profiles. They remain full-v1 work. This baseline neither
authorizes unsupported histories nor changes any recovery or freeze eligibility.
