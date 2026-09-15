# Preparing entropy recovery with the client

The current client prepares the original token/scope incident calls, a fresh
recovery quote and request, operation-17 Artist content consent, and an executor
fee-credit claim. All writes are unsigned ordinary calls. A Safe uses
`toSafeCall`; the Safe itself remains the caller and owns any credited excess.

The [contract flow](entropy-fresh-recovery.md) defines eligibility. Declare the
incident, wait the required delay, and read a fresh quote before obtaining Artist
consent. The quote includes a commitment to every supplied recovery input.
Another request, reason or evidence commitment cannot reuse that client quote.
A provider quote, collection journal, role or binding can still change before
inclusion; execution recomputes the live contract conditions.

```typescript
import {
  prepareEntropyIncident,
  prepareFreshEntropyRecovery,
  readFreshEntropyRecoveryPreview,
  prepareEntropyRecoveryContentConsent,
  assertCurrentArtistDigest,
  prepareEntropyFeeCreditClaim,
  toSafeCall,
} from "@6529/stream-client";

// Execute this using the actual incident-role Safe, then wait the contract delay.
const incident = prepareEntropyIncident(coordinator,
  { kind: "token", tokenId }, reasonURI, incidentEvidenceHash);

// After the delay, prepare the original input and an explicit ETH allowance.
const recovery = prepareFreshEntropyRecovery(coordinator,
  { oldRequestKey, reasonURI, providerEvidenceHash }, nativeAllowance);
const quote = await readFreshEntropyRecoveryPreview(provider, recovery, { blockTag });

// For an Artist-bound collection, use the exact current registry and Core.
// Empty signature means the Artist authority Safe executes the consent CALL.
const consent = prepareEntropyRecoveryContentConsent(chainId, registry, core,
  collectionId, recovery, quote, { nonce, deadline, signature: "0x" });
await assertCurrentArtistDigest(provider, consent, { blockTag });
const artistSafeCall = toSafeCall(consent.call);
const incidentRoleSafeCall = toSafeCall(recovery.call);

// After execution, the credited executor can direct its pull credit.
const creditClaim = toSafeCall(prepareEntropyFeeCreditClaim(coordinator, destination));
```

The preview's `providerFee` is the provider's quote. It does not calculate the
required caller contribution: token requests can use the collection reveal
escrow, while scope requests use caller funding. Choose an explicit allowance.
Changing that allowance preserves the recovery calldata and original Artist
signing message. Unused ETH belongs to the executor that sent the recovery call.

The Artist helper preserves the original `6529StreamArtistRegistry` domain,
`StreamArtistContentConsent` type, entropy host address and reserved family.
It does not create a new signer scheme or substitute a manifest hash for the
contract's proposed content-state hash. Nonempty signatures remain opaque EOA
or ERC-1271 bytes. Integer fields use `bigint`, including nonces and native value.

For a scope incident use `{ kind: "scope", scopeId }`. Declaration alone never
authorizes another random draw. The existing client helpers do not construct the
[explicit finding profile](artist-entropy-unavailability.md); follow its separate
operator sequence. Its new contract source and runtime validation are qualified
in that guide.

The offline `packages/stream-client/examples/current-entropy-recovery.mjs`
example takes explicit JSON, with integer values represented as decimal strings,
and prints the two prepared Safe calls. Supply the complete preview returned
by the reader, including `inputHash`. It neither contacts RPC nor signs or sends.

## Validation

Six focused client cases compare every call with compiler-selected Solidity
interfaces, exercise the exact original Artist tuple/domain, preserve Safe
value and full-width integers, reject mismatched previews and malformed output,
and cover the independent token/scope incident selectors and executor credit
claim. The compiler fixture generator takes explicit standard-JSON input/output
files. These are encoding and client tests; the
[fresh-recovery guide](entropy-fresh-recovery.md#validation-boundary) records
the separate native contract evidence and remaining joined-system acceptance.
