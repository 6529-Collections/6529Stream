# Sale-parameter consent in the shared settlement consumers

The native fixed/price-program consumer and the universal ERC20 fixed-price
consumer ask their immutable current artist facade to authorize the actual
registered sale configuration. The check is separate from artist mint-policy,
economics and commercial signatures. Enabling the artist's REQUIRED election
must be integrated together with equivalent guards on every supported sale
path; this consumer increment alone does not authorize opening that election
across older adapters or auctions.

The consumer supplies its stored collection ID, sale ID and complete config
hash to `requireSaleConsent(uint256,bytes32,bytes32)`. The linked
`StreamSaleConsent` helper preserves the consumer as the caller seen by the
facade. It checks the pinned facade runtime and the actual Core-selected pointer,
then requires canonical ERC165 `IStreamArtistSaleAuthority` capability admission
(exactly one 32-byte word equal to one) before accepting the consent call's
successful response containing exactly zero bytes. An attribution-only facade
with an empty-success fallback cannot stand in for this sale API. Missing,
failed or malformed responses fail closed. NONE is decided by the actual facade
on a real binding; it is never inferred from missing capability or failed reads.

The check runs before commercial signatures and funding, and again after payment
and NFT-receiver callbacks before returning success. Native free mints, including
a zero PWYW choice, use the same consent requirement even though they create no
official settlement. A callback that makes the current consent invalid causes
the entire purchase to revert, including payment, permit/replay effects, minting,
and any callback state changes.

Both consumers expose immutable registered `saleConsentFacts(bytes32)` and their
canonical module declarations. These facts remain readable after sale closure or
pause. They grant no authority by themselves. The artist facade independently
checks its accepted binding, current authority, recorded consent and the actual
canonical ModuleRegistry record. The facts read makes no call back to the facade.

The native declaration is `NATIVE_PRIMARY_SALE_ADAPTER` with the
`IStreamNativeSaleBinding` interface. The universal declaration is
`FIXED_PRICE_SALE_ADAPTER` with `IStreamERC20SaleExecution`. The module version
remains `6529STREAM_UNIVERSAL_SETTLEMENT_V1`; constructors are unchanged. Deployers
must link `StreamSaleConsent` into both consumers and `StreamUniversalSaleRights`
into the universal consumer. The latter contains the exact previous fixed-PROFILE
selection logic, extracted for code size; it adds no template support or custody.

This change preserves the commercial EIP-712 schemas, config hashes, Manager
authorization IDs and batch contents, existing replay maps, and the recorder and
contract20 interfaces. Direct current-facade consent reads use the established
available-gas convention with bounded returndata; this is not an ERC1271 cap
claim. The new refund-window consumer must use the same canonical consent gate
at purchase while keeping accrued refunds independent of current artist state.

The domain tests use real consumers, split wallets, recorder, canonical module
registry and official Safe contracts with an explicit artist-consent test seam.
They cover exact caller/config association, required consent on paid/free paths,
callback rollback and retry, malformed reads and Safe access. The universal
low-level rejection cases prove transaction rejection and rollback; they do not
attribute the precise inner token call from final balances alone. Canonical
artist op16 records, current Core and real governance composition remain separate
integration evidence.
