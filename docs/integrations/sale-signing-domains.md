# Discover the domain before preparing a sale signature

Current immediate sale consumers expose their signing-domain fields through
[IERC5267](../../smart-contracts/interfaces/standards/IERC5267.sol). This follows
the return shape defined by [ERC-5267](https://eips.ethereum.org/EIPS/eip-5267).
Select the getter for the authorization family being signed:

| Authorization | Contract | Getter | Domain name |
| --- | --- | --- | --- |
| `NativeSaleAuthorization` | `StreamNativeFixedPriceSaleAdapter` | `eip712Domain()` | `6529StreamNativeFixedPriceSaleAdapter` |
| `NativePriceProgramAuthorization` | The same native adapter | `priceProgramEip712Domain()` | `6529StreamNativePricePrograms` |
| `UniversalSaleAuthorization` | `StreamUniversalFixedPriceSaleAdapter` | `eip712Domain()` | `6529StreamUniversalFixedPriceSaleAdapter` |

All three return version `1`, the live chain ID and the consumer's own address.
The `fields` bitmap is `0x0f`: name, version, chain ID and verifying contract are
present. Salt is zero and absent from the domain; the extensions array is empty.
Check the chain and deployed consumer address before displaying a signature
request. These getters preserve the existing names and signed message preimages.

The native adapter deliberately retains two previously distinct signature
families. Its standard getter describes fixed sales.
[IStreamNativePriceProgramDomain](../../smart-contracts/interfaces/stream/mint/IStreamNativePriceProgramDomain.sol)
is an explicit Stream extension for price programs, with the same return tuple.
A client that supports only the singular standard getter must add this family
selection before signing free, open-edition or PWYW price-program requests.
Using the fixed domain for a price-program signature fails verification.

Construct the EIP-712 domain from the declared fields, hash the exact named
authorization fields, and compare the resulting digest with the matching
`authorizationDigest` or `priceProgramAuthorizationDigest` read. Domain discovery
does not replace sale configuration, nonce, deadline, payer or artist validation.
Safe signers still use the appropriate Safe message signature workflow; the
Stream domain's verifying contract remains the sale consumer, not the Safe.

The getters are public reads and can also execute through a threshold Safe CALL.
Existing sale interface IDs remain unchanged; discovery uses additive interface
capabilities. The focused test
[StreamSaleSigningDomains](../../test/unit/revenue/StreamSaleSigningDomains.t.sol)
independently reconstructs all three complete digests, exercises Safe reads and
native/price-program purchases, rejects cross-family signing, and fuzzes chain
and verifying-contract binding. Its Core, Manager and artist boundaries are the
explicit revenue-domain fixtures; current-contract and candidate acceptance are
separately tracked in the [delivery ledger](../../ops/V1_DELIVERY.md).

The TypeScript client's retained RC1 ABI export does not yet contain these new
methods. Use the matching implementation ABI until the new candidate/client
projection is generated. Published RC1 contracts are unchanged.
