# Current-authority RIGHTS selection

`StreamCurrentAuthorityRightsRecordSelection` is an explicit deployment profile
for the original RIGHTS selection role. Deploy it before that selector's first
selection or permanent seal. It uses the same constructor as
`StreamRightsRecordSelection`:

```solidity
constructor(address core, address metadata, address schemas)
```

It advertises the original Rights selection, bounded-record witness and selection
lock interfaces, plus `IStreamRightsRecordCurrentAuthority`:

```solidity
currentAuthorityProfile()
    returns (bytes32);
currentArtistIdentityContext()
    returns (address[3] targets, bytes32[3] codeHashes);
```

The profile is `keccak256("6529STREAM_CURRENT_AUTHORITY_RIGHTS_SELECTION_V1")`.
The diagnostic returns the current Artist facade, operation Coordinator and
Identity owner, in that order. Its distinct name separates this three-target
result from WORK and CONSERVATION's five-target `currentArtistContext()`.

## Authenticated succession

The original host rejects a resolved Artist tuple that differs from the tuple
captured at its construction. The explicit current-authority profile instead
accepts the fresh tuple returned by the existing
`StreamRecordArtistIdentityReads.resolveCurrent` proof. That proof begins with
Metadata's immutable original Artist facade and runtime. It applies the existing
Core pointer, predecessor, complete authority import, owner completion and
repeated-ancestry checks before admitting a successor.

The new selector keeps the original Core, Metadata, schema registry, byte store,
chain ID and all three constructor-captured Artist runtime checks. Only equality
between that captured Artist tuple and the authenticated current tuple is
relaxed. A pointer change alone is insufficient, and changing the original
captured code still prevents current consumption. This profile does not relax
the shared ancestry proof's own requirements for original or intermediate hosts.

Both selection entrypoints, `requireCurrent`, preparation and execution of a
permanent seal, and the new diagnostic apply these checks. ACCOUNT licensors
also require a valid current graph. An ARTIST licensor is resolved through the
fresh Identity tuple and retains the original immutable registration hash; its
meaning remains the documentary identity described in
[ADR 0042](../adr/0042-current-rights-record-selection.md).

## Retained evidence and authority

The original Rights tuple, event, selection commitment domain, indexed history,
predecessor and revision rules, RIGHTS grant precedence, exact record/payload
witness and active definition checks remain unchanged. Rights JSON, licences
and effective-date interpretation continue through the original readers.
Selection and [permanent seal](record-selection-locks.md) commitments still bind
the actual selector deployment address. Raw history, current-head and seal
getters preserve the same historical-read behavior.

This is a new original deployment, not an importer for an already deployed
legacy selector. It has no setter for an Artist graph and introduces no new
Core role, signer authority or grant registry. A finality graph must bind this
host's actual address and runtime from its original construction. Replacing an
existing host address does not transfer its selections or seals.

## Validation boundary

The additive source is reviewed and ABI/type checked. Focused unit and genuine
current-stack scenarios are authored separately; their runtime execution,
linked bytecode size, gas budgets and complete provider/finality composition
remain required validation. The legacy host and shared Metadata/Artist proof
are unchanged.
