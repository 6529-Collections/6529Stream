# Current native secondary sales client

`CurrentSecondaryClient` prepares inventory14, fixed-account delegated claims and
the original maker/delegate offer flows on `StreamPrivateSaleAdapter`. It creates
unsigned CALL data and signing payloads only. There is no wallet, signing key,
provider conversion, ERC-20 payment or broadcaster in this helper.

## Select actual compiler bindings

Supply the ABIs from the intended compiler build, explicitly:

```ts
import { CurrentSecondaryClient } from "@6529/stream-client";
const sales = new CurrentSecondaryClient(chainId, adapter, {
  adapter: selectedAbis.privateSale,
  inventory: selectedAbis.inventoryInterface,
  moduleRegistry: selectedAbis.moduleRegistry,
});
```

The inventory interface matters: its library-emitted events are absent from the
host's compiled ABI. Receipt decoding uses the compiled interface but still
requires the actual adapter emitter. The helper checks all three original Sales
signing tuples against the selected ABI. Other methods must also exist in that
selected ABI. Deployment identity and authority require separate live checks.

Use the existing `scripts/generate-bindings.mjs` with an explicit build-info and
target mapping. Add `IStreamNativeInventorySale` and `IStreamModuleRegistry` from
the same compiler input to that mapping (and retain the required Core binding).
The original `src/generated` catalog is not changed and does not acquire these
new methods automatically. The new test-only fixture generator accepts explicit
compiler input and output files, records their hashes and selects the host,
inventory interface, registry interface and original signing source. Its
`--check` mode reproduces only that fixture; it does not refresh release evidence.

## Inventory14

The configuration owner prepares `registerInventory(owner, config, tokenIds)`.
IDs must be positive, strictly increasing and number 1 through 64. The helper
rejects primary terms, zero price, malformed widths and reordered/duplicate IDs.
The existing contract verifies owner/configuration authority, current signer
revision/evidence, actual token ownership and immutable module admission.

`secondaryConsignment: true` is a substantive declaration: require actual prior
collector delivery from the transfer history. Current ownership or MINTED state
alone cannot establish it. The helper cannot infer or certify this history.

Retain the actual `InventoryConfigured` receipt and its saleId/configHash. When
the sender is a Safe, first require its exact successful Safe transaction hash
with `requireSafeExecution`; outer receipt success alone is insufficient. Each
original `SaleCustodyGrant` uses that saleId as saleRef. Prepare deposits with
`depositInventory`, then `openInventory` once every listed token is in custody.
The owner must separately provide the original Core transfer authorization; a
delegation witness does not approve or transfer the NFT.

`readInventory` and `readInventoryRoyalty` expose current stored config, token
list and royalty disclosure. `purchaseInventory` keeps the supplied expected
config hash and uses the buyer as native payer, caller and NFT claimant. Value
must be at least the reviewed unit price; excess is the same buyer's pull
credit. Supply all amounts, timestamps, token IDs, revisions and indices as
bigint, not JavaScript numbers. Client width checks include uint32/uint64 bounds.
There is no mint or reveal allowance on this secondary path.

`closeInventory(..., "cancel")` and `closeInventory(..., "expire")` use the
original cancellation/expiry selectors. Their authority and timing remain
contract-enforced. They preserve sold items and stage only unsold custody for
consignor claims. NFT delivery retries and pending royalty retries preserve the
original account/receiver accounting. A successful CALL can leave a bounded NFT
delivery pending; inspect the exact delivery event/current claim state.

## Original Sales signatures and callers

`signing(kind, message)` supports SaleAuthorization, SaleOffer and
SaleCustodyGrant under the unchanged **6529Stream Sales**, version **1** domain.
The typed messages also retain their original embedded chainId and saleAdapter;
both must equal the selected client's domain. `signingFromJSON` accepts exactly
kind/message, with canonical decimal strings for every integer. Messages and
returned payloads are copied and frozen. Compare with the actual host getter
using `assertDigest` before requesting signatures.

`authorizationForOffer` constructs the original secondary kind6 authorization:
one buyer, zero mint/primary/content fields, exact singleton beneficiary hashes,
empty mint data/commitment array hashes and the original payer/executor buyer.
Its nonce and deadline are caller-supplied original authorization coordinates.
It does not approve an offer, infer eligibility or select a sale signer.

`acceptOffer(buyer, input, { mode: "maker" })` retains direct maker/EOA/ERC1271
verification. The delegate variant requires `{ mode: "delegate", witness }` and
uses `acceptDelegatedOffer`. In both cases:

- The original buyer is the actual CALL sender, native payer and NFT receiver.
- The platform seller signs the matching original SaleAuthorization.
- The maker or actual delegate signs the original SaleOffer digest; kind1 is
  EOA, kind2 is ERC1271. A Safe signature stays opaque contract signature bytes.
- Only the original token owner supplies the SaleCustodyGrant. For an offer,
  saleRef is the exact offer digest, rather than the separately configured saleId.

Delegation adds no payment, custody, spending or revocation power. Both offer
entrypoints share the existing nonce/digest stores. A fresh listing does not
revive an already consumed offer. The caller must fetch the actual registered
configuration, seller authority, grant/replay state and simulate the full call;
pure encoding cannot certify any of them.

## Delegation observations and claims

`claimRefundFor`, `claimNftFor` and `claimInventoryNftFor` contain no destination
override: the exact credited account receives the money/NFT. Their caller is
the delegate. Original own-account claims still choose a receiver and require
no delegation observation. None of these earned exits grants a new sale or mint.

`observeDelegation` requires independently retained deployment pins: Core,
adapter runtime, module registry/runtime, delegation registry/runtime, usecase
and base manifest. It resolves a single observed block and checks the exact
compact declaration bytes, immutable host getters, registry runtime and full
retained six-word row. Wallet-wide scope is the original all-collections address;
Core-wide scope remains the configured Core. Missing, malformed, expired,
revoked and wrong-context rows fail. Pins and witness are copied before awaits.

For purpose `offer`, it also checks the live ACTIVE module record, runtime,
registered manifest hash, timestamps and revision. Purpose `claim` deliberately
skips module status/registry runtime admission, preserving earned exits; the live
delegation registry row still applies. It does not use a length-only boolean
registry grant getter or fabricate authority from a supplied row object.

An observation is not a signature or future transaction authorization. The
contract repeats its canonical bounded reads and callback checks at execution;
state may change after observation and a client RPC is not independent chain
proof. `simulate` uses the exact returned caller, value and calldata. For a Safe,
`toSafeCall(prepared.call)` preserves CALL operation0 and a decimal native value;
submit through `prepared.caller` and verify the actual Safe execution receipt.
No helper signs, sends or selects the Safe nonce/gas policy.

## Examples and validation

[The read-only examples](../examples/current-secondary.mjs) cover listing,
receipt association, buyer purchase, delegated offer and inventory claim review.
They take explicit compiler bindings and caller-selected providers/addresses.
Use one fixed block tag for a coherent multi-read review; rerun simulation near
submission. There is no simulated automatic retry or transaction submission.

The focused Node tests exercise independent original preimages, compiler ABI
calldata/event parity, full-width JSON and values, fixed account claims, original
maker/delegate principal separation, precise grant/manifest failures, immutable
observations, original own exits and Safe CALL coordinates. These client tests
use controlled RPC responses; they do not execute a new contract deployment or
establish native contract, callback-capacity, audit or release acceptance.
