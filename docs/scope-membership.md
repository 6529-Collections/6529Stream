# Published scope membership

`StreamFinalityScopeMembership` authenticates fixed RELEASE, SEASON and VIEW token
subsets against original collection metadata records. COLLECTION and TOKEN reads
use the same Core and `StreamCollectionTokenInventory`. The host adds no mint or
burn hook and does not create artist sanction, view-content approval or finality.

## Fixed deployment and publication authority

Deploy the host with the actual Core, `StreamCollectionMetadataV1`,
`StreamCollectionTokenInventory` and governed-parameter Executor. Core, Metadata,
Schema Registry, native chunk store and inventory runtime identities are pinned.
Construction also checks Metadata's original Core/schema/store code hashes and
the inventory's original Core code hash and deployment chain. Matching getters
on substituted code do not establish a new baseline.

The supported measured deployment profile registers
`SCOPE_MEMBERSHIP_READ_GAS` with genesis value 500,000, floor 50,000 and forwarding
failure class 1. Its key is `keccak256("6529STREAM_GGP_SCOPE_MEMBERSHIP_READ_GAS")`.
The existing governed host permits increases. This cap belongs to membership
dependency reads; Metadata retains its independent 150,000 dependency cap.

Register the exact definition bytes in the actual Schema Registry, under
`RAW_BYTES`:

| Name | Kind | Bytes | Content Keccak |
| --- | --- | ---: | --- |
| `STREAM_SCOPE_MEMBERSHIP_V1` | SCHEMA | 2047 | `70c79fbabc4dc32259b4f3958da52f8c9d27814e9202e1ab2b1c0b75acd3d2cb` |
| `STREAM_SCOPE_MEMBERSHIP_ABI_V1` | CANONICALIZATION | 1309 | `3a8f6aa2c183ea43dff145064f8175f2a7c4bc7c2b65633d0fdfdc36fdeaab5e` |

The files are [the manifest definition](schemas/finality/scope-membership-v1.schema.json)
and [the canonicalization definition](schemas/finality/scope-membership-abi-v1.json).
Their identifiers hash the exact names. Formatting changes their content hashes.

Governance must explicitly admit `keccak256("SCOPE_MEMBERSHIP")` into the existing
IDENTITY family, using only metadata/global authorization classes 7 and 8. A
governed family-writer grant authorizes the actual Metadata publication. The
membership host checks the saved receipt's recorder, class, schema definitions,
record index and chain, full payload and original generic 14-word record hash.
It does not infer authority from a caller's uploaded chunks. A later grant
revocation or schema retirement does not erase the original published record.

These metadata classes establish membership provenance. They do not replace the
separate artist authority needed for sanctions or render-affecting VIEW content.

## Immutable record and list identity

The Metadata record uses the canonical COLLECTION subject for its collection.
Its payload is the exact flat Solidity ABI tuple:

```solidity
abi.encode(
    uint16(1), chainId, core, collectionId, uint8(scopeType),
    tokenCount, tokenListHash, chunkHashes
)
```

`scopeType` is RELEASE 2, SEASON 3 or VIEW 4. The eight-word head has array offset
256. The complete payload is exactly `288 + 32 * chunkHashes.length` bytes,
without trailing bytes or noncanonical integer/address widths.

The list contains strictly increasing, raw 32-byte uint256 token IDs. Every
nonfinal part contains 8192 bytes; the final part contains a multiple of 32 up to
8192. There are at most 64 native-store parts, allowing at most 16,384 members.
This follows the actual encoded storage bound rather than imposing a smaller
token-list limit. The whole-list Keccak and total count must match exactly.
An empty list has zero parts and Keccak(empty); this is valid grammar, not
evidence that an empty collection or scope is finality-ready.

After authenticating the record, derive the scope ID as:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_SCOPE_MEMBERSHIP_ID_V1"),
    chainId, core, collectionId, uint8(scopeType), recordHash
))
```

The payload omits the resulting ID, avoiding a circular commitment. The ID
identifies an original published scope record, not a deduplicated token set.
Republishing the same members with a different recorder, URI or effective time
creates a different ID. Existing legacy IDs are not aliased or reinterpreted.
`scopeManifestHash` is the original Metadata payload hash, not the list hash.

## Admission and sealing

Anyone may call `beginScopeMembership(recordHash)`. It authenticates the original
record and retains the exact scope, manifest and native pointer/code pins.
Repeating the same begin is idempotent and confers no authority.

`continueScopeMembership(scope, maximumParts)` processes only the next parts,
with a batch bound of 1 through 64 parts. Each token must have an actual Core
collection mapping, nonzero collection serial and MINTED or BURNED lifecycle
with a consistent burn flag. Its inventory entry at serial minus one must match.
Prepared and unallocated tokens fail. The whole part rolls back on failure.

An early begin does not snapshot an incomplete inventory prefix. If a member has
not yet been indexed, continuation fails and can retry after permissionless
inventory indexing. Stopping early cannot seal a subset: sealing requires every
part, the complete member count and a recomputed whole-byte hash. The sealed
scope is immutable. A burn retains membership; later parent mints do not enlarge
the list or change its commitment. A closed parent collection is not required.

## Reads and historical meaning

`requireScopeMembership(scope)` returns exactly eight static words, in order:

| Field | Meaning |
| --- | --- |
| `scopeSubject` | Canonical full-family subject derived from chain/Core/scope |
| `scopeManifestHash` | Original scoped Metadata payload hash; zero for COLLECTION/TOKEN |
| `sourceRecordHash` | Original scoped Metadata record; zero for COLLECTION/TOKEN |
| `tokenCount` | Complete current collection count, one token, or sealed scoped count |
| `tokenListHash` | Scoped whole-list hash or one-token hash; zero for COLLECTION |
| `membershipHash` | Versioned commitment to fixed hosts, complete scope and the other facts |
| `inventoryCount` | Current complete COLLECTION count; zero otherwise |
| `inventoryPrefixHash` | Current complete COLLECTION prefix; zero otherwise |

The selector is `0x4a2ed6c6`. `requireRecoveryScope(scope)` (`0x854fec36`) returns
the same subject and manifest hash in 64 bytes. `scopeTokenAt` enumerates the
same ordered members; `scopeCoversToken` checks membership in that same universe.
Historical publication/progress getters do not assert current validity.

COLLECTION validation intentionally requires today's complete inventory. A later
mint makes it incomplete until indexing catches up, and then changes its count
and prefix. Historical collection serving must use its saved original checkpoint
and inventory commitment rather than substituting this fresh COLLECTION read.
TOKEN identity and sealed RELEASE/SEASON/VIEW commitments retain their original
meaning after ordinary burns and later mints. Validating reads still enforce
fixed runtime and retained source pins. They do not follow current replacement
Metadata/provider pointers; new-candidate selection checks belong to the caller.

## Provider and Router integration

The provider fixes `scopeMembershipHost()` and `scopeMembershipHostCodeHash()` and
joins the membership host's Core and Metadata identities to its own. The Router
must resolve membership from its saved original Finality anchor, then that
registry's original provider and the provider's same fixed membership host.
An unlocked collection uses the authenticated fixed facade's original binding.
A missing or partial saved anchor fails; today's replacement provider is not a
fallback. The developing Router wrappers are a separate integration increment.

The maximum cold record URI and manifest were exercised through the actual
Metadata, Schema Registry and Store at the 500,000 cap. The actual IR call costs
were 211,398 gas for a 2944-byte record return and 63,250 for a 2432-byte manifest
return. The nested manifest read still needs its larger forwarding reserve.
The complete 64-part validating read returned 256 bytes under a 1.2-million-gas
outer call; measured consumption was 388,720. An ordinary 150,000 outer cap fails.
The provider uses a separate 2-million-gas source cap. These measurements do not
prove the complete Registry/provider/Router 12-million-gas serving path.

## Evidence boundary

The pure encoding prerequisite passes six tests, including two 256-case fuzz
properties, in both modes. Six publication tests use actual Metadata, Schema,
Store and Inventory with explicit Core/governance/artist boundaries. They cover
all three families, exact events, incomplete-inventory retry, malformed lists,
retired grants/definitions, burns, later mints and source-code loss/restore.
Two capacity tests cover the maximum record/list representation in both modes.
Full 64-part setup pauses test gas metering; it is not a live one-transaction
admission or final-seal gas claim. Two additional IR tests use actual Core,
Metadata, Schema Registry, Store, Inventory, Module Registry, Executor, System
Manifest and threshold Safe. They exercise delayed governed installation and
publication policy, all three scoped families, actual mint/burn identity,
interleaved collections, later mints and grant-revocation/indexing retry. Mint,
entropy and artist authority remain explicit boundaries in those tests.

Membership alone does not complete inherited-scope artist recovery approval,
adjudicated association supersession, VIEW content adoption, complete scope
finality evidence or the full current-stack release gate.
