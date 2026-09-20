# Original DIRECT sales and conservation history V1

This additive profile targets source
`8bb6dfe2957542f641b0d558e1cfd48e1b39ae98`, tree
`d521268a11aaeb867c6c43f9a8140042a187c1cc`. Its retained ABI98 capture contains
2,591 Solidity inputs with no compiler errors. Every literal input was compared
byte for byte with the frozen Git commit. The fixture retains 35 complete ABI
segments, 1,944 entries, 1,232 dependency hashes, 69 source texts and three frozen
integration documents. Existing profiles retain their original source pins.

The client covers the original native fixed-price adapter, ERC20 fixed-price
adapter and English-auction house. Their original authorization, payment,
Mint Manager and delivery calls remain the transaction entry points. Paid
completion appends a typed DIRECT receipt and calls the permanent conservation
floor in the same transaction.

## Original calls and authority

| Product | Supported original calls | Caller and payment |
| --- | --- | --- |
| Native fixed price | `buy`, `cancelAuthorization` | Buy requires the literal caller to equal the signed payer, with exactly the signed price in native value. Cancellation uses the caller's commercial nonce lane. |
| ERC20 fixed price | `registerSale`, `cancelSale`, `buy`, `cancelAuthorization`, `revokePaymentIntent`, `revokePaymentIntentBySignature` | Registration and sale cancellation require the product owner. Buy retains original Artist consent, carries zero native value and transfers tokens through the original adapter. Commercial and payer replay lanes are separate. |
| English auction | `createAuction`, `bid`, `settle`, `cancel`, `setDeliveryRecipient`, `claimNoBidNFT`, `withdrawRefund`, `cancelAuthorization` | Only bid carries native value. Creation, bidder delivery changes, Artist cancellation, deferred NFT claims and refund withdrawal retain their original authority checks. |

`prepareDirectConservationCall` accepts the product coordinates, actual caller
and a discriminated request using these exact method names. It returns an
unsigned call and `factsVerified: false`. It preserves all supplied signatures,
token bytes, payer and recipient identities. Unrelated pause controls, signer
changes and ownership transfers are outside this operational profile.

The floor's `recordDirectPrimarySale` is authenticated transport for the product.
It is not a wallet operation. The client exposes historical floor reads and hash
helpers, with no public DIRECT preparation or synthetic universal-settlement
candidate. The universal `settlementReceipt` at a DIRECT key remains all zero.

## Signing and payer consent

Every EIP-712 domain binds the actual product address and chain. Both platform
and Artist commercial signatures cover the complete original authorization,
including its signer epoch.

| Authorization | Domain name | Version | Primary type |
| --- | --- | --- | --- |
| Native purchase | `6529StreamFixedPriceSale` | `2` | `SaleAuthorization` |
| ERC20 purchase | `6529StreamPaymentIntentVerifier` | `1` | `ERC20SaleAuthorization` |
| Auction creation | `6529StreamEnglishAuction` | `2` | `AuctionAuthorization` |
| ERC20 payer consent | `6529StreamPaymentIntentVerifier` | `1` | `StreamPaymentIntent` |
| Signed payer revocation | `6529StreamPaymentIntentVerifier` | `1` | `StreamPaymentIntentRevocation` |

The ERC20 commercial authorization inherits the payment verifier's domain.
Do not substitute a new fixed-price domain. The helpers
`directConservationNativeTypedData`, `directConservationERC20TypedData`,
`directConservationAuctionTypedData`, `directConservationPaymentIntentTypedData`
and `directConservationPaymentRevocationTypedData` preserve these exact preimages.

The original ERC20 sale record commits its immutable configuration and
registration nonce, which starts at one. Its sale-ID product-kind discriminator
is `uint8(0)`. `directConservationERC20SaleId` can hash nonce zero as a raw preimage;
that does not establish a registered sale.
Commercial bytes32 nonce zero and payer-intent nonce zero remain representable
in signing and hashing; original operation validation decides where they are
admissible. A cancellation's nonce rules need not equal a hash codec's rules.

For an ERC20 purchase, token allowance names the original adapter as spender.
An empty payer signature is exempt only when the literal transaction caller is
the signed payer. That path consumes no payer-intent nonce. Otherwise the
separate signed intent must authorize the exact payer, asset, sale ID and primary
policy, with sufficient maximum amount and an unexpired deadline. Payer and
recipient may differ. A Safe is the literal caller of its inner CALL; a Safe
owner or an outer transaction relayer does not receive the payer exemption.

## Minting, auctions and paid completion

Immediate purchases use the original single-step Mint Manager preview and
execution. `directConservationMintBatch` reconstructs the original batch for
comparison with `previewSingleStepMintOperation`. The captured operation root
and operation ID are checksums of that original execution path, not a new
authorization format.

Native price zero still mints through the original adapter. It does not enter
paid DIRECT admission or append paid product/floor receipts. Unknown,
unpaid, cancelled and no-bid operations return zero-valued product receipts.

Auction creation mints into the house's custody with a zero batch payer and the
Artist as the initial beneficiary. Creation and bidding do not constitute paid
DIRECT completion. Settlement retains the original authorization, operation
identity, rights policy, creation time and registry revision. Its paid payer is
the winning bidder; its paid beneficiary is the selected delivery recipient.
Settlement does not mint again or reactivate the original phase.

The auction's complete origin is private until its paid receipt exists. Retain
authenticated creation evidence when preparing later settlement. A current
auction tuple alone does not reveal every original receipt field.

Commercial nonce consumption, token/native funding, minting or delivery,
product history and floor history are atomic. A floor failure or later original
check reverts the transaction's inner effects. After a Safe inner failure,
the Safe may have consumed its own nonce while the commercial and payer nonces
remain unchanged. Retrying the original call requires a fresh Safe authorization.

Receipt beneficiary records the original token delivery recipient; proceeds
go to the split wallet or escrow. It does not promise current ownership.
A mint receiver may transfer onward during its
callback; Core rejects burning during mint execution. An auction's later
delivery callback can burn an already completed token when the collection
permits it. Completed identity and immutable paid evidence remain meaningful.

## Admission and exact simulation

Paid products use the Core-selected canonical module registry row for
`DIRECT_PRIMARY_SALE_ADAPTER` / `6529STREAM_DIRECT_PRIMARY_SALE_V1`, the original
receipt interface and actual runtime hash. The three original products do not
provide optional module-type/version self-report getters.

Immediate paid receipts require ACTIVE admission at their current creation
time and revision. New auction creation also requires ACTIVE. A previously
created auction may settle under DEPRECATED admission only when both original
creation time and original revision precede the registry's status change.
Bid, delivery, refund and exit calls retain their own original checks; do not
apply creation admission uniformly to every method.

`captureDirectConservation` observes a concrete block, checks code and dependency
pins, original term/digest getters and the relevant public state. This is
preflight evidence. Simulate the exact original calldata from its actual caller
with explicit gas before execution. Only that call exercises private authority,
signature validation, token behavior, callback behavior and bounded nested
floor/provider calls together. Successful direct reads do not prove those
nested calls fit their governed gas limits.

## Safe and receipt workflow

Use `toSafeCall(prepared.call)` or `createSafeCallPlan` with the exact prepared
call. Each of the sixteen supported operational variants can use an ordinary
Safe CALL. Native purchase and bid values are preserved; ERC20 and other calls
carry zero inner native value.

The workflow is:

1. Call `captureDirectConservation(provider, deployment, prepared, { blockTag })`
   at a concrete reviewed block.
2. Call `simulateDirectConservation(provider, capture, { blockTag, gasLimit })`
   with explicit nonzero gas no greater than 100,000,000. Review the refreshed
   capture and exact original return shape.
3. Submit the exact original direct call or authorize it through the Safe.
4. Call `reconcileDirectConservationReceipt(provider, capture, transactionHash,
   options)`. Direct options use `execution: "direct"`; Safe options use
   `execution: "safe"` and an independently verified `expectedSafeTxHash`.

For paid auction settlement, supply `auctionCreation` containing the original
creation capture, transaction hash and transport. The workflow re-reconciles
that historical creation before joining it to the paid receipt. Supply
`releaseKey` when the existing release is reused and its locator is not emitted
again in the payment transaction.

Safe reconciliation checks the actual Safe caller, exact target, calldata,
inner value, `operation: 0`, and the matching execution-success event after the
required product/floor evidence. It supports the shared legacy and indexed
Safe execution-event layouts. Outer success alone is insufficient. The supported
transport uses zero outer native value; funding a Safe and executing the product
are separate actions. Module and batch transports are outside this receipt API.

Receipt reconciliation requires a block strictly later than the saved capture,
historical prestate reads and exact end-of-block operation state. Same-block
follow-up mutations can make a valid transaction unverifiable through this
conservative API. Retain the original capture and creation evidence rather than
substituting later state or inferring success from a displayed balance.

## Immutable floor history

The six-word product bindings include Core and Mint Manager addresses and runtime
pins, deployment chain and product kind. The sixteen-word paid receipt retains
the complete original authorization digest, collection/token, operation root/ID,
bound mint policy, expected primary policy, profile/wallet, creation time,
escrow flag, payer, registry revision, beneficiary, asset and amount.

`directConservationKey` and `directConservationReceiptHash` use the original
DIRECT namespaces. Floor, first-sale and release hashes include the complete
original tuple with its own `receiptHash` field zeroed. The product getter's
zero-amount convention is separately represented by
`directConservationReceiptLookupHash`.

`inspectDirectConservationReceipt(provider, { chainId, product, authorizationId },
{ blockTag })` verifies the pinned product's local bindings, original typed
receipt and hash. It returns `receipt: null` and a zero hash for a completely
empty receipt. This does not imply that the commercial nonce is unused: a free
mint or an auction custody mint can consume authorization without a paid receipt.
The reader checks the product's stored deployment chain and needs no live
former Core, Manager, registry or provider.

`inspectDirectConservationFloorHistory` reads the pinned floor at a concrete
block and verifies its immutable DIRECT, first-sale and release links. It does
not re-admit former adapters, Managers or providers. Keep a release-key locator
with the receipt: a DIRECT receipt stores `releaseReceiptHash` but not the
semantic `releaseKey` needed by the original release getter. A nonzero release
hash therefore requires a retained key or one recovered from the original
release event. A supplied key is checked against the complete release tuple and
its semantic preimage. A waived receipt has no release locator.

Collection first-sale evidence and successful semantic-release evidence are
reused without rewriting their original recorder, source or timestamp. Current
sale-to-release membership is still checked on every new payment. The semantic
release key commits scope, membership, media inventory, script hash and script
flag. It deliberately excludes provider identity and source-context hash, so
a benign provider/locator change does not create a new semantic release.

Source IDs are one-based; source-set history permits count zero with a nonzero
initial head. Retain source evidence using the exact original append hash.
Later provider loss does not erase prior receipt facts or convert them into a
claim about current archival availability.

## Tier and provider limits

For a prospective paid sale, an undeclared tier bears the lite floor even before
the first completed mint. This differs from the Core's pre-mint descriptive
effective-tier read, which can still be undeclared. Explicit `CONSERVATION_WAIVED`
skips documentary requirements while preserving genuine paid receipts.
Missing evidence never implies a waiver.

The native provider requires its supported complete media/script evidence.
Opaque/token-specific recipes and nonzero external script-library dependencies
remain unavailable in this source profile. Actual Artist personhood evidence
is also unavailable through the native provider, so the corresponding Artist
collection floor remains blocked. Platform identity cannot be invented as a
substitute for Artist evidence.

## Client bounds

These are client allocation limits and observation requirements, not additional
protocol capacities:

- Token data: 8,192 bytes, a narrower bound than the original Core's maximum.
- Each signature: 16,384 bytes; pure ABI input and prepared call: 131,072 bytes.
- Runtime reads: 131,072 bytes; ordinary RPC return data: 65,536 bytes.
- Admission's module-manifest URI: 3,648 UTF-8 bytes.
- Receipt logs: 2,048, with at most four topics and 32,768 data bytes per log.
- Outer transaction calldata: 262,144 bytes.
- Simulation gas: an explicit nonzero value no greater than 100,000,000.

Historical reconciliation requires a provider that can read the captured,
preceding and receipt blocks. These checks do not establish archival
availability beyond the observations actually made.

## Validation boundary

Regenerate the fixture from the retained ABI98 files without invoking Solidity:

```sh
node scripts/generate-current-direct-conservation-fixture.mjs \
  /path/to/abi98-input.json /path/to/abi98-output.json --check
```

The source-derived ABI/hash oracles and mocked RPC/Safe cases validate this
client profile. The separately retained native packet at
`844d5f323acb459adec33db7b218901545ec84c2` reports 73 passing cases: 34 floor-ledger,
25 typed-DIRECT-floor and 14 native-provider tests. Its 82 nonempty production
artifacts meet size limits. That packet excludes original product
signatures/payment/current-stack cases and actual Artist composition. It does
not establish acceptance of this joined source, the cold whole-paid-transaction
gas target, full CI, deployment or release readiness.
