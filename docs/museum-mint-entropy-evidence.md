# Original mint and entropy evidence

The mint/entropy composer adds usable original mint evidence to a verified
[token examination](museum-dossier-gather.md). An optional concrete source
reader supplies the original coordinator's entropy state and complete bounded
event history. The earlier examination and its profiles remain unchanged.

This implements another MUSEUM-17 producer/consumer join. It does not complete
the full acquisition packet, object dossier, finality assessment or institutional
acceptance.

For public-chain heights, use the separate
[public mint/entropy capture](museum-public-mint-entropy.md). It retains these
native semantics with bounded filtered history and explicit provider trust.
The original reader and examination profiles described here remain unchanged.

## What the retained token already proves

`token_mint_evidence.extract` consumes originals only after the containing
actual-token fixture has passed its existing verifier. It exports:

- The original paid-sale transaction, receipt, calldata and signature bytes.
- The immutable token-data bytes and their commitments.
- Core collection registration, original-coordinator entropy registration,
  mint Transfer and paid-sale settlement events, with exact block, transaction
  and log coordinates and checked ordering.
- The original mint commitment and all six retained source-block Core views,
  including permanent identity, lifecycle and `coordinatorAtMint`.

The unchanged repository fixture was examined at block **1311** and minted at
block **685**. Its mint receipt includes collection registration at log **4**,
entropy registration at **5**, mint Transfer at **6** and sale settlement at
**10**. It has no original-coordinator state reads or complete receipt walk.
Consequently, the composer reports its entropy status, seed, provider, request
and complete later event history as **unresolved**. A rendered image, mint
registration or caller description cannot supply those missing facts.

The coordinator's original deployment runtime commitment is retained separately
from source-block runtime evidence. A newly supplied reader must observe that
runtime at the same examination block; the deployment artifact alone is not
described as a later code read.

## Optional complete source reader

`MintEntropySource(anchor_bytes, transport, provenance=...)` accepts a closed
anchor containing `profile`, `chainId`, `core`, `tokenId`, `collectionId`,
`blockHash`, `blockNumber`, `timestamp`, `stateRoot`, `environment`,
`deploymentEvidenceHash`, `codePins` and `coordinator`.

It reads the actual `coordinatorAtMint(tokenId)`, verifies the original
coordinator's code/interface/Core binding, and obtains `tokenEntropy`,
`tokenSeed` and `tokenEntropyStatus` at that exact block hash. It reconciles
the state with mint registration and the token's complete admitted request and
finalization history. The current coordinator pointer and renderer mode do not
replace the original coordinator.

The event denominator is every transaction receipt in parent-linked blocks
from genesis through the source head. The reader checks receipt/block/log
ordering, exact source coordinates and the source head after its reads. The
bound is **4096 blocks including genesis**, with at most **64** exported
`EntropyRequested`/`EntropyFinalized` references. Exceeding a bound refuses the
capture; it does not return a truncated history or claim an absent event.

The current native profile supports observed statuses `REGISTERED`,
`REQUESTED`, `FINALIZED`, `STALE` and `FAILED`. Only observed, reconciled
`FINALIZED` is marked terminal-eligible by this profile. Minted `NONE`,
`DISABLED` and `NOT_REQUIRED` reject: this profile has no admitted native writer
for those observations. Future consent-bound entropy modes require their own
source admission. No renderer-based exemption is inferred.

Successful replay exports the exact `STREAM_EXPORT_ENTROPY_LEAF_V1` fields,
ABI preimage and hash, plus event references in the original acquisition-packet
fragment shape. A pending or failed status can have complete provenance fields;
that does not make its entropy eligible for finality. Item **4** becomes
`derived_within_source_profile` only after the concrete reader and all joins
pass. The source's declared `synthetic_fixture` or `trusted_rpc` provenance is
preserved. Neither mode supplies consensus, state-trie or receipt-trie proof.

## Build and verify offline

Use the Museum Python environment described in the
[tooling guide](../tools/museum/README.md). Start with a verified examination
and its externally retained manifest hash:

```text
python -m tools.museum.dossier_mint_entropy build \
  --examination out/examination --examination-hash 0x... \
  --disclosure public --output out/mint-examination
python -m tools.museum.dossier_mint_entropy verify \
  out/mint-examination --manifest-hash 0x...
```

To include existing entropy evidence, add all of these build arguments:

```text
--entropy out/entropy-capture \
--entropy-anchor-hash 0x... --entropy-transcript-hash 0x... \
--entropy-snapshot-hash 0x... --provenance trusted_rpc
```

The entropy directory must contain exactly `anchor.json`, `transcript.json`
and `snapshot.json`. Use `synthetic_fixture` for synthetic source vectors.
The composer never contacts an RPC server. It checks all three external pins,
replays the concrete reader, compares the original mint events and token-data
commitment, and rejects conflicting common runtime pins or repeated RPC answers.
Every output directory must be new; publication uses the existing atomic,
no-overwrite repository helper. Public disclosure is checked before file reads.

Outputs include the unchanged `examination/`, original mint bytes under
`mint/`, an updated 19-item `packet/fields.json` and a readable
`packet/examination.md`. With entropy evidence, `entropy/packet-fragment.json`,
`entropy/leaf-preimage.bin` and the exact source triplet are included. The tool
snapshots are inert provenance, never executed by package verification.

`complete-packet` verifies the entire package and refuses with the exact
remaining item numbers. The composition preserves the earlier queue for all
other items; item 4 also remains unresolved without a complete admitted entropy
source. The full accompanying dossier, covering archives, preservation and
authority selections, recovery joins and institutional evidence still need
their own sources.

## Worked retained baseline

The original examination manifest
`0x3bd04c14b2f93994380c93c24982aa82645c7d538be654e6c4fe733e96498c2c`
was composed without an additional entropy capture. The result has **550 files**
and **30,950,495 bytes**, with manifest
`0xa6a162adfe43c6b111a7bccc07f1222e3e6d58434e8935788e895cf82a51412b`.
The earlier examination is byte-identical, and the three new inert tool
snapshots match the generating source. This example retains the actual mint
evidence described above; items **3–18**, including **4**, remain unresolved.
Complete entropy joins are separately covered by explicit synthetic vectors.
