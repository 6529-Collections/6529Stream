# Prepared native content purchases

The additive purchase profile supports repeated positive-price purchases from one
immutable curated manifest. It uses the actual Manager, Ledger, Core preparation
and official primary recorder. The original auction entry and whole-sale replay
key remain separate.

The sale retains its original `saleId`, creation `saleNonce`, configuration and
lifecycle. Each buyer has a monotonic purchase nonce. The canonical purchase ID is
`keccak256(abi.encode(keccak256("6529STREAM_SALE_PURCHASE_V1"), chainId, adapter,
saleId, buyer, purchaseNonce))`. The original intent uses that purchase nonce as
its `executionNonce`; its original content, execution and settlement domains do
not change.

## Admission and settlement

The sale calls `executePreparedNativeContentPurchaseMint` with the original
`MintBatch` and a typed `GateData`: active intent hash, Ledger authorization ID,
content selection/proof, complete original 24-field `SaleAuthorization`, and its
explicit signer/kind/signature. The active purchase getter supplies the ten-field
`Purchase` tuple. The Manager reads and canonically validates both active records.

For public record authority, the Ledger authorization ID equals the unique active
intent hash; authorizer and the entire signed presentation must be zero. For the
initial private profile, it is the canonical TICKET wrapper over the full original
Sales EIP-712 digest. The active intent hash is a different identity. Private
purchases require STRICT_MATCH mode 0 and an atomic `finalizeBy == 0` presentation.
Deferred public purchases may use ALLOW_CURRENT mode 1 as admitted by the carrier.

The Manager recomputes all four domain-separated hashes from its complete actual
recipient, beneficiary, token-data and commitment arrays before saving admission.
The separate admitted gate verifies the signature and immutable historical signer
membership, along with its received fields and original content proof. Gate
signature verification alone is not evidence of the raw token-data array: that
array is authenticated by the Manager's purchase-bound admission.

Admission commits the actual adapter, intent hash, complete purchase tuple and
original content facts before the operation root is assigned. The same commitment
is checked after Core preparation, after funding and after mint completion. The
recorder consumes `(adapter, purchaseId)` and the original settlement key, and
stores the original facts/content/result records. It does not consume the old
whole-sale auction flag. The per-content CONTEXT counter remains capped at one.

Economics are explicitly collection PROFILE only. Mode 0 requires the current
concrete policy to equal the original policy; mode 1 retains the original evidence
and settles current admitted rights. Token/default/template economics, offers,
free price overrides and ERC20 purchases are outside this increment.

## Full-payload private revocation

`mintSaleAuthorizationId` derives the same original-domain TICKET used by Ledger.
`voidMintSaleAuthorization` takes the full payload and optional revocation
signature. It reads only `curatedSaleAuthorizationBinding(saleId)`: the immutable
collection, phase, signer, explicit kind and configuration hash. The configured
signer can call directly, including through a Safe CALL. A relayer supplies the
original `MintTicketRevocation(chainId, manager, ledger, authorizationId)` under
the original Sales domain. An ordinary sale signature cannot revoke it.

Historical revocation does not require a currently active phase, module, Artist,
payment path or unexpired deadline. It uses the existing Manager-scoped Ledger
void and replay readback, emits the existing schema-1 void event with family 2,
and does not mint or allocate operation nonces. Unknown or malformed historical
bindings fail closed. The separate secondary custody revocation route is unchanged.

## Validation boundary

Focused tests cover literal digest derivation, full-array substitution, public
empty presentation, distinct active-intent/TICKET identities, historical
revocation, actual Manager/Ledger consume-versus-void replay and an identical
signed Safe transaction retry after a failed Ledger write. The revocation fixture
uses typed Core/Artist/governance and historical sale-record boundaries; it is
not a complete current paid-purchase demonstration. The batch-hash harness tests
the actual shared codec, not independent gate signature admission.

The focused 223-source ABI check passes with ten authored tests. All 173 original
Manager ABI entries and 107 original recorder entries are retained. Manager's
storage is unchanged; the recorder appends only the nested purchase-consumption
map after its existing state. A token comparison confirms original mutation
bodies are unchanged. Six stored view encodings move into the existing fixed
Manager view library, retaining their exact typed output and storage references.

All ten selected production products fit in the recorded IR/200-runs/Paris
measurement: Manager runtime 22,694 bytes and recorder runtime 20,128 bytes.
The earlier oversized Manager capture is retained separately. These are selected
code-generation results, not execution results. The satellite carrier and
actual-current composed purchase tests are separate coordinated work. No native
runtime result is claimed here yet.

The separate `StreamCurrentCuratedPurchaseSettlement` suite now has four authored
current-Core cases: two works from one immutable sale, duplicate-content rollback
under a fresh purchase nonce, identical signed Safe retry after late receiver and
post-delivery consent failures, and strict original-policy refusal alongside a
committed ALLOW_CURRENT purchase paying the replacement collection PROFILE.
The last case pays the separately updated live reveal fee at mint. These cases
use the carrier task's `NativeCuratedSaleFixture` unchanged: Core, Manager, Ledger,
recorder, Resolver, split wallet and Safe are actual products; Artist, entropy and
governance retain the explicitly typed fixture boundaries. The focused 362-source
ABI capture includes the exact upstream carrier/fixture work-in-progress bytes.
That capture is type evidence only. Integrate the corresponding carrier fixture
before running this dependent suite; no native result is claimed for it.
