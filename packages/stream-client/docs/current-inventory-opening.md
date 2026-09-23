# Saved native inventory opening

`CurrentInventoryWorkflow` completes the operator sequence between an actual
inventory14 registration and an open secondary sale: retain all original owner
grants, deposit each token once, and open only after the existing custody records
agree. It composes `CurrentSecondaryClient`; it adds no contract method, signing
domain, NFT approval, payment authority or broadcaster.

Supply the intended compiler-selected adapter, inventory-interface and registry
ABIs, as described in [current-secondary.md](current-secondary.md). The existing
compiled test fixture is reused without changing the retained generated catalog.
A journal also pins the adapter and Core runtime hashes and actual Core address.
These deployment pins must come from the operator's independently reviewed build
and deployment records, not from untrusted suggestions.

## One workflow

The [complete file-based example](../examples/current-inventory-opening.mjs)
exposes the four steps below. Files use exclusive creation; existing files are
never overwritten. If only the first file was written before a local disk error,
retain it and the already returned saved object/hash rather than replacing the journal.

1. Call `registrationCall` with the configuration owner, reviewed configuration
   and sorted token IDs. Submit that exact original `registerInventory` CALL
   independently. For a Safe, keep operation `0`, the returned Safe address and
   zero native value. The configuration's secondary-consignment declaration
   still requires actual prior collector delivery; MINTED/current ownership alone
   cannot establish this history.
2. Read the actual `InventoryConfigured` receipt. Use its `saleId` as every
   original `SaleCustodyGrant.saleRef`, including the exact chain, adapter, Core,
   token, owner, nonce and deadline. Obtain the original owner EOA/1271 signatures
   only after comparing the client digest with `custodyGrantDigest` through
   `sales.assertDigest`. The NFT owner's original Core transfer authorization
   remains separately necessary. A deposit's transaction caller may differ from
   its grant owner; the saved recipe records that caller explicitly. The opener
   must satisfy the contract's current owner-or-consignor rule.
3. Call `prepareRegisteredInventory(workflow, provider, input)`, retain the returned
   saved object, then call `persistInventoryJournal(saved, journalPath, hashPath)`.
   `input` contains the receipt, exact config/token list, ordered signed deposits,
   opener, pins and optional registration Safe receipt coordinates. Each deposit
   is `{caller, grant, ownerKind, signature}`. Use full-width `bigint` inputs;
   owner kinds remain original EOA `1n` or ERC1271 `2n`. On a Safe registration,
   always provide `registrationSafe: {address, transactionHash}` with the original
   independently verified Safe transaction hash.
4. Call `resumeInventoryOpening(workflow, provider, journalPath, originalHash)`
   before each transaction. A pending result contains `{safe, call}` with exact
   target, calldata, decimal value `"0"` and operation `0`. An EOA uses the same
   target/calldata/value and the explicit caller. Submit independently; use
   `verifyInventoryStep` on its actual receipt and then resume the unchanged file.
   No helper selects a Safe nonce, gas policy, signature, outer relayer or batch.

The original hash must be retained independently from the journal file. A hash
recalculated from an edited file is a new proposal, not authorization to resume
an old plan. The strict versioned JSON stores integers as canonical decimal
strings and complete signed calldata as hex. Unknown fields, malformed widths,
reordered token/grant entries, different ABI bindings and mismatched commitments
are rejected. ABI fragment order alone does not change the binding fingerprint.

## Resume and retry meaning

Each review resolves a single block, checks its hash again, and reads all items
at that block. The saved origin block must remain canonical. The helper rebuilds
the original sale ID, inventory hash and configuration hash, compares the full
immutable item coordinates, and checks each exact grant digest plus consumed and
revoked state. It does not advance a local counter or assume a prior transaction
succeeded.

- `deposit`: the first still-uncollected token; exactly the saved signed CALL.
- `open`: every item is held under its saved grant; original `openInventory` CALL.
- `opened`: the stored inventory is open. Later purchases may already have
  changed individual items to sold; this does not cause a second opening CALL.
- `cancelled` or `expired`: separate terminal outcomes, never successful opening.
  Original refund/NFT claims remain available through the existing helpers.

Pending calls are simulated with the actual saved caller and zero value. The
contract simulation checks current module admission, owner/custody, ERC1271,
Core transfer authorization and callbacks; a client state review cannot certify
future execution. A failed simulation or Safe target execution never changes
the saved journal. Repair the observed external condition and retry the exact
same call. An expired grant, different accepted grant or changed immutable state
requires explicit review; the helper does not silently sign a replacement.

Receipt checks require the original adapter's exact schema1 deposit plus
consumed-grant events, or its opening event. Safe execution additionally needs
the exact independently verified Safe transaction hash for that direct CALL;
this helper does not authenticate arbitrary Safe module/multisend internals.
Supplied receipts/RPC reads are observations, not independent consensus proofs.
`opened` describes stored progress, not attribution to a particular transaction
or caller. A historical registration receipt is joined to its complete current
stored configuration rather than used to invent a sale nonce.

## Validation boundary

Focused tests use the existing compiler-selected ABI with controlled RPC and
Safe-event responses. They cover complete original preimages, full-width values,
all deposit/open stages, unchanged signed retry bytes, independent callers,
malformed/reordered journals, grant conflicts, receipt failures, runtime/source
drift and block reorganization. They do not execute a new native deployment or
establish contract gas, callback capacity, audit or release acceptance.
