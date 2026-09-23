# Unbound Platform Works hydration

This client prepares the separate `UNBOUND_PLATFORM` profile through the
original recovered-authority Request and operation 60. It supports complete
registries of unbound Platform collections, including a registry with no
Artists, and the limited mixed registry described below.

The profile tag is `6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1`, version 1.
Its feature bit is `4194304`; its allowed mask is `4194335`, consisting of
that bit and the original recovered base bits 0–4. The profile does not set
`MULTIPLE_BASE`. At the pinned source, the owners advertise `8388607`; the shared
feature vocabulary recognizes `33554431`. Neither wider mask expands this
profile's admitted histories. Earlier clients keep their existing boundaries.

See the [contract integration guide](../../../docs/integrations/artist-unbound-platform-hydration.md)
and [ADR 0047](../../../docs/adr/0047-complete-artist-authority-hydration.md)
for the source admission and atomic owner-write rules.

## Select the complete registry

At least one selected collection must have `artistId == 0`. Each such collection
must retain its original Platform declaration, an empty Binding, no Acceptance
or Attribution generation, and no policy selector. Its selected Artist ID stays
zero. The request must preserve the complete sorted, unique Artist and collection
scope, full owner journals, replay inventories and imported prefixes.

A mixed registry may also contain ordinary recovered class-1 or class-3 Artists
with their complete Identity and Payout histories. Their collections must have
accepted generation-one PRIMARY_ONLY bindings, base Attribution and direct
policy-14 history, with no Platform history of their own.

The mixed profile excludes delegated evidence, broader consent or attestation
histories, collaborators and multiple binding generations. Both the Request's
witness array and the royalty-freeze array must be empty. Use the original
two-argument preparation and `hydrateRecoveredArtistAuthority(Request)` call.

## Preserve typed Platform and owner state

Each owner's inner semantic envelope has four flat ABI arguments:

```text
abi.encode(tag, uint16(1), uint8(owner), M.State)
```

The enclosing RH ExportHeader and Payload remain unchanged and retain complete
original owner provenance. Their semantic rows depend on the selected subject:

| Owner | Unbound Platform collection | Ordinary mixed-registry subject |
| --- | --- | --- |
| 0: Binding | Empty row; original Binding is entirely empty | Original generation-one Binding and terms |
| 1: Collaborator | No rows | No rows for PRIMARY_ONLY |
| 2: Identity | One distinct timing row when there are no Artists | Complete authority row per Artist |
| 3: Acceptance | Empty row; no invented acceptance | Original accepted record and timestamp |
| 4: Attribution | Complete original Platform slice | Base Attribution with its original proposal era |
| 5: Payout | No rows when there are no Artists | Complete payout row per Artist |
| 6: Consent | Empty row; no invented policy | Complete direct policy rows |

The Platform slice carries the original twenty-word state and every retained
declaration 8, Platform claim 9, attribution allegation 10, governed
contest/dismissal 11 and unused governed correction approval 53. An unused
approval keeps corrective generation zero and remains unaccepted. The client
does not manufacture a corrective binding or acceptance.

Keep claim and contest bodies, their occurrence order and counts, original
replay subjects, and the latest public and STATIC display claim. Operation 11
has an original native journal row while leaving the original record tip
unchanged; the other supported Platform writes advance that tip.

The original record hashes do not cover every retained field. Complete original
Archive envelopes authenticate the additional actor, payload and governance
fields against the independent owner-4 transition. Each retained origin's
catalogue stays complete across all seven owner cutoffs. Selecting one
collection cannot filter another collection's entries out of that evidence.

## Zero Artists and repeated imports

A Platform-only source has registration nonce zero, no principal native journal
and no indexed nonce inventory. Identity carries a distinct tagged timing
checkpoint, with the original timing schema/version, zero count and root, and
the hash of the exact all-zero raw timing configuration. It is not an Identity
bundle for an invented Artist zero.

The empty-principal external-guard snapshot uses this profile's tag and the
original full provenance commitment, with all other fields zero. Governed
timing changes on an empty-principal source are outside the supported profile.

Original operations 55, 56 and 57 still establish predecessor admission,
verified collection lanes and cutover. Each selected collection lane activates
once. The source has no invented Artist lane. Repeated imports retain the full
seven-owner cutoffs, immutable prefixes, per-era lane and cutover cells, and
cumulative import-binding and governance cells.

Historical lane and cutover cells remain evidence of the earlier era. Old
import-root and governance-action cells remain spent. A fresh claim uses the
successor's original producer domain and follows its imported prefix.

## Capture, simulate and inspect receipts

Client inputs are bounded to 16 retained eras, 128 Artists and 128 collections,
with at most 128 policy selectors across the selected graph. Pure owner-blob,
calldata and supplied timeline-envelope totals allow 2,621,440 bytes; the workflow limits operational
calldata to 2,097,152 bytes. Prepared and aggregate allocation checks use
16 MiB. Archive collection allows at most
16,384 catalogue rows and 64 MiB of operation-carrier bytes. These limits can
exclude larger histories even when a contract could otherwise admit them.

```js
const input = { request, royaltyFreezes: [] };
const captured = await captureArtistUnboundPlatformHydration(
  provider, deployment, caller, input, { blockTag, gasLimit }
);
const checked = await simulateArtistUnboundPlatformHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

Capture copies supplied values before asynchronous reads and pins dependencies
to the requested block. Simulation rechecks the captured source graph and calls
the exact zero-value Registry calldata from the intended caller. The original
Registry and Prepared calls retain responsibility for contract admission,
signatures and private state checks. Simulation does not reserve future state.

```js
const receipt = await reconcileArtistUnboundPlatformHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash, nonce, safeCodeHash }
);
```

Use `{ execution: "direct" }` for a direct receipt. The Safe path preserves the
same target, calldata and zero value as an ordinary CALL. It checks the signed
transaction fields, supplied Safe digest and runtime identity, exact success
event and one nonce advance across the mined block. The client does not execute
or independently verify Safe owner signatures.

Receipt inspection checks original operation-60 evidence, all seven owner
commits and imported lanes. Immutable original rows remain comparable after
later activity. An imported correction approval keeps its immutable body checks
when its corrective generation or acceptance status advances. Mutable heads
are checked only while the destination owner is
at the exact imported revision. The complete original source catalogue must
also match at the mined block; a later same-block source append requires separate
attribution and is conservatively refused by this workflow.

Historical inspection records what was imported. Current inspection performs
fresh source reads and simulation. Neither turns an old record into renewed
authority or proves private lane activation independently of the contract.

## Source and execution boundaries

The client target is pinned to integration commit
`66dc4a308f6a1c1b93187d7295554062d900b5fa`. It includes the reviewed unbound
Platform producer while preserving the earlier Consent constructor repair.
The compact source profile identifies the selected compiler declarations and
source comparisons; its generator checks retained artifacts without compiling.

ABI188 contains 4,365 source literals, all matching that commit's raw Git bytes.
The selected production import closure contains 1,102 sources. The compact
profile reuses 1,007 unchanged source files and retains 26 changed and 69 added
files. It compares all 1,182 retained declarations and supplements them with
one ordinary interface and 70 nominal library declarations, including the 18
unbound Platform libraries. Changed declarations have complete current
overrides. The producer's ABI7 capture and its 34-path integration comparison
remain separately identified evidence.

Compiler-provided nominal tuple witnesses and ordinary public selectors keep
their distinct roles. Source-derived tagged envelopes describe encoded values;
they do not create callable selectors for expanded library tuples. The retained
earlier compiler fixture remains unchanged.

Client tests use supplied provider replies and synthetic receipts. They check
encodings, source joins and client refusal behavior. Actual contract execution,
Safe execution, atomic rollback, linked-call gas, bytecode capacity and release
acceptance require separate integration evidence.
