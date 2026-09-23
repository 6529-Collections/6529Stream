# Current C2PA token lifecycle

This authored family extends the immutable
[current STATIC token fixture](../../test/helpers/CurrentStaticTokenRenderingFixture.sol)
at `cb771c8ae043e376a9f5dedb7720d982ee3179d8`. It connects actual Artist
credentials, selected-verifier records, report adoption and standing-conflict
disposition to a paid, revealed current Core token. **Native execution is
pending.** ABI compatibility does not establish a runtime or capacity pass.

The current-source [citation follow-up](current-citation-recipe-join.md) adds
explicit admission for this family's own C2PA Renderer/Registry after mint and
reveal. Its three new paid-token output vectors remain separate from the original
empty golden and from the immutable source capture above.

## Actual producers and explicit evidence limits

The [new fixture](../../test/helpers/CurrentC2PATokenLifecycleFixture.sol) keeps
the inherited original Core, Manager, Ledger, sale, Artist owners/Coordinator/
Registry/Archive, Metadata, Store, Schema Registry, RoleRegistry and Governance
Executor. Its governor, Artist, buyer, unauthorized control and selected verifier
are separate threshold-two Safe 1.4.1 accounts. Shared test signing keys do not
merge their addresses, transaction nonces or signature domains.

Original C2PA products pin this graph: reconciliation, optional attribution
wrapper, original attribution companion and Renderer. An actual governed
Renderer Registry admits that renderer. Original Artist op17 consent selects
the collection override and the Router's real media-manifest method stores and
selects the image commitment. The inherited paid mint creates token 1 in
collection 2; its original Coordinator then finalizes entropy. No Core, Router,
Artist, governance-action or verifier-receipt read is mocked.

The upstream entropy service remains the inherited test double. The selected
verifier explicitly signs **synthetic observations**; the identity-document
interpretation, C2PA claim/signature, key history and trust anchor are not real
cryptographic validation. Both observation and anchor bytes are retained in the
original Store. SHA-256 SPKI fingerprints are test inputs, not external identity
proof. A VALID/CONSISTENT result means this selected report passes the modeled
protocol reconciliation rules.

Registry admission retains synthetic partial direct-read analysis and a
self-derived empty golden vector. Neither establishes a complete transitive
STATIC profile or an accepted independent golden corpus. The original STATIC
fixture and prior C2PA composition/unit tests remain unchanged.

## Six authored cases

The [host](../../test/current/StreamCurrentC2PATokenLifecycle.t.sol) covers:

1. **Positive credential to output.** The actual Artist Safe records original
   op24 credential evidence. Its separate personhood record survives. The
   selected verifier Safe publishes a genuine class-6 Metadata receipt; the
   buyer Safe permissionlessly adopts it. Original Artist owner snapshots do
   not change. Literal full HTML and C2PA JSON fields match the selected report,
   and repeated adoption refuses the already-used record.
2. **Writer failure and exact retry.** Revoking the verifier's original family
   grant makes its saved Safe publication fail without changing nonce, record
   count, record chain, recorder head or selection. Regranting authority lets
   that byte-identical transaction publish the same report and reach adoption.
3. **Wrong recorder and wrong class.** Another genuine class-6 recorder cannot
   substitute for the constructor-selected verifier. A genuine class-8 receipt
   from that selected verifier also fails adoption. Neither creates a selection
   or conflict; a later class-6 report succeeds under the original rules.
4. **Standing divergence survives newer facts.** A divergent adopted report
   creates an independently reconstructed conflict. Publishing a newer verifier
   head makes the old display unevaluated. Adopting the consistent successor
   restores report currentness but leaves the conflict standing. Original
   credential withdrawal again makes the report unevaluated without erasing
   the adverse record or its chain.
5. **Token precedence.** An actual collection report supplies fallback before
   any token selection. A token report then takes precedence. Once that token
   selection is stale, output remains explicitly unevaluated even though the
   collection report is still current; the token conflict remains disclosed.
6. **Original dispute resolution and exact acknowledgement retry.** The actual
   Artist Safe opens operation 44 with covered evidence. Original class-1
   operation 46 is scheduled by the governor Safe holding the actual arbiter
   role. A saved buyer Safe acknowledgement fails while that action is only
   scheduled, preserving conflict state and nonce. After delayed execution, the
   identical Safe transaction acknowledges the exact disposition once. The
   original divergence and chain remain immutable, with acknowledged disclosure.

## Evidence for operation 46

Both the independently encoded disposition narrative and the six-word
`Dispute.Evidence` are retained in the original Store and covered by actual
archival producers. The evidence binds the exact opening, collection, binding,
generation and narrative hash. The existing collection-envelope profile uses
`6529STREAM_PLATFORM_WORKS_EVIDENCE_V1`; the enclosed bytes remain the original
typed dispute evidence. This is the schema accepted by the current coverage
contract, not a new dispute envelope schema.

The fixture governs two distinct archival families. One uses the original
checkpoint verifier with a locally constructed inclusion vector and two test
observer signatures; the other uses content-addressed possession evidence.
Original receipt, fixity and coverage contracts process both. This demonstrates
their intended contract composition only. It establishes neither a live network
receipt nor external observer/custodian independence. No historical mainnet
fixture is relabeled as the new dispute's evidence.

The original Executor action retains the exact resolution scope, old/new state,
reason hash, delay and arbiter proposer. Original Archive receipts for op24,
op44 and op46 are checked. The acknowledgement checks all five disposition
fields and its emitted receipt; it removes the unresolved head while retaining
the original conflict record, chain and revision. A later attempt refuses replay.

## Independent oracles and remaining acceptance

Expected values reconstruct literal subject domains, credential-attestation and
media-manifest commitments, Metadata record preimages and zero-based chain,
adoption selection, conflict identity/chain, dispute opening and disposition
narrative. Expected HTML includes exact token data, script, seed and media hash.
Expected JSON distinguishes current validity/authorship, stale reports,
standing adverse evidence and acknowledged history, while retaining the actual
Artist attribution. Production previews are used for signing or governance
inputs; they do not supply expected output strings or record commitments.
Each current full JSON result must also equal the corresponding historical full
JSON plus one literal original-work citation. Original HTML/context bytes and
every existing C2PA validity, authorship and standing-conflict assertion remain.

The inherited fixture uses explicit governed Router/Core frames of 16/24 million
gas and an 8-million optional renderer attribution frame. This successor adds
1-million reconciliation reads and wrapper budgets of 6 million for original
Artist attribution and 2 million for report reads. These are unmeasured fixture
settings. Original size guards remain, with runtime guards on the new C2PA
products and Registry. A joined native capture must use the final source graph,
all six ABI cases and the original EIP-170/EIP-3860 and gas acceptance rules via
the [existing wrapper](../../tools/development/run_current_acceptance.py).

No production/shared fixture, runner, catalog, immutable RC1 or release evidence
changes accompany this family. It does not establish universal C2PA verification,
real media retrieval, all credential/identity/estate profiles, simultaneous
multi-conflict disposition, later dispute reopening behavior, cold-gas capacity,
complete STATIC/finality acceptance, audit readiness or testnet readiness. See
[C2PA reconciliation](artist-c2pa-reconciliation.md) and the
[earlier current composition](current-c2pa-composition.md) for adjacent scope.
