# Complete Artist history client

This separate client carries the developing Complete History profile through
the original operation-60 Registry calls. It supports current collection heads
whose retained records belong to earlier Artists and includes ordinary
collaborator principals. Existing recovered-profile clients keep their original
encodings and refusal rules.

The semantic tag is `6529STREAM_ARTIST_COMPLETE_HISTORY_V1`, version 1. The
profile bit is `33554432`; the closed allowed mask is `33816575`. Knowing the
extended feature vocabulary does not select a profile. The original preparation
worker selects Complete History from observed source records. See the
[contract guide](../../../docs/integrations/artist-complete-history.md).

## Complete scope and carriers

Select zero through 128 Artists and one through 128 collections. The Artist
list is the complete historical principal union, including former primaries
and ordinary collaborators. Collection queries name their actual current head,
which can be pending, refused, withdrawn or partly accepted. An unbound
collection has no synthetic Artist or generation-zero binding.

Each owner semantic envelope encodes five flat ABI arguments:

```text
(schema, uint16 version, uint8 owner, M.State scope, bytes auxiliary)
```

All seven owners carry the identical canonical common inventory and full scope.
That inventory contains original provenance, binding and collaborator histories,
the shared Archive census, Platform rows, acceptance maps and account nonce
lanes. Owner 4 retains every original native record in its scope. Owner 1 has
empty local rows; owners 2 and 5 have one row per selected principal, including
zero rows for an all-unbound graph.

The consent supplement preserves original ratification records and, only in its
first row, the shared sanction inventory. An empty supplement retains the
original untagged consent encoding. Supported principal rows use the original
Class One/Three encodings. Nonempty authority supplements remain unsupported.

## Prepare and observe the original calls

```js
const captured = await captureArtistCompleteHistoryHydration(
  provider, deployment, caller, { request, royaltyFreezes },
  { blockTag, gasLimit }
);
const checked = await simulateArtistCompleteHistoryHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

Without royalty witnesses, preparation uses its original two-argument route
and `hydrateRecoveredArtistAuthority(Request)`. Royalty witnesses use the
original three-argument route and
`hydrateRecoveredArtistAuthorityWithConsents(Request, RoyaltyFreeze[])`.
Both produce a zero-value Registry CALL. Nominal library preparation selectors
are worker entrypoints, not wallet transactions.

Capture pins source and destination dependencies at an explicit block. It
checks original Archive catalogues and independent owner cutoffs, retained
source records and their historical Artist associations. Original Prepared
and Registry calls remain decisive for full composition, private installation
and signature admission. Local carrier validation alone does not prove those
properties; the exported validation qualifiers say so explicitly.

```js
const receipt = await reconcileArtistCompleteHistoryHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash, nonce, safeCodeHash }
);
```

Use `{ execution: "direct" }` for a direct receipt. Safe inspection binds the
exact inner CALL, all signed transaction fields, original Safe digest, runtime,
success event and nonce advance. It supports the existing legacy and indexed
Safe event layouts. Historical inspection and fresh current simulation remain
separate. A later same-block source catalogue append is conservatively refused.

## Evidence and limits

The generated schemas retain genuine production tuple witnesses from ABI198
at source `5104c901b5bb348829c62a5638291c1bf2fb0e5b`. The source projection
authenticates all 4,620 compiler input files against committed Git blobs; this
capture matches the literal bytes without line-ending normalization. It retains the selected ordinary and library
declarations, structural types and their complete source closure. Library enum value
substitution requires a retained compiler ABI witness. Original compiler ABIs
and nominal method identifiers remain unchanged.

Owner blobs and pure calldata are bounded at 2,621,440 bytes; Prepared and
aggregate allocations at 16 MiB; workflow transaction calldata at 2,097,152
bytes. The source catalogue scan allows 16,384 rows and 64 MiB of operation
carrier bytes. A contract-supported history may exceed these client bounds.
Pure codec tests, independent compiler/source oracles,
provider replies and synthetic Safe receipts are distinct evidence. They do not
establish actual Safe execution, atomic seven-owner rollback, runtime capacity,
gas, Class Four support or release readiness. The integrated contract tests own
those acceptance checks. No held recovery handoff supplies client evidence.

Positive provider fixtures cover an undeclared all-unbound allegation, repeated
migration, and an Artist A history beneath a pending Artist B head with retained
economics and royalty records. They are compiler-shaped consistency mocks.
Complex combined sanctions, collaborator adjudication and dispute histories
remain outside this batch's positive provider-fixture evidence.

Run focused client checks after the ordinary package build:

```sh
node --test test/current-artist-complete-history-*.test.mjs
```

Reproduce the retained source projection with the exact authorized ABI198
capture files, without invoking Solidity compilation:

```sh
node scripts/generate-current-artist-complete-history-source-profile.mjs ABI_INPUT ABI_OUTPUT SOURCE_BRIDGE --check
```
