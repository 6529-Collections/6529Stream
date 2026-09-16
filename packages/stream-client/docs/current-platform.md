# Declared PLATFORM auction callers

These helpers prepare the current declaration-authorized PLATFORM auction
families. They preserve the platform signature and each contract's original
domain. The caller supplies the verified chain, house, Resolver and Artist
deployment. The retained RC1 address catalog is not a deployment catalog for
these newer operations.

## Choose the family

| Family | Rights selection | Initial operation |
| --- | --- | --- |
| 8 | Collection TEMPLATE | Deferred auction or prepared custody acquisition |
| 9 | Default TEMPLATE | Deferred auction or prepared custody acquisition |
| 10 | Collection PROFILE | Deferred auction or prepared custody acquisition |
| 11 | Default PROFILE | Deferred auction or prepared custody acquisition |
| 12 | Exact token PROFILE | Activate rights on an existing pre-bid custody auction |
| 13 | Exact token TEMPLATE | Activate rights on an existing pre-bid custody auction |

Every family uses `primaryPolicyMode = 1n` (`ALLOW_CURRENT`). Families 12 and 13
bind an already acquired NFT, its original auction configuration, acquisition
origin and declaration. They do not perform another mint. A token override is
an exact token selection; it cannot be skipped to use a collection or default
assignment.

The PLATFORM declaration is its own authorization path. Do not insert an
Artist-zero approval or reuse an Artist signing domain. Template grammar allows
static accounts and the original `SALE_POSTER`, with no implied Artist or paid
collaborator source. A filed permissionless claim alone is not a contest or a
correction and does not by itself invalidate a declaration.

## Review the hashes and signing payload

All Solidity integers are `bigint`; hash fields are exact `bytes32` hex strings.
The exports independently compute the source preimages:

- `platformRightsConfigurationHash` commits to the actual deferred or custody
  configuration, nested clock, original rights and declaration.
- `platformCustodyOriginHash` commits to the original Manager, operation,
  authorization, token, serial, funding account and forwarded reveal fee.
- `platformTokenCustodyConfigurationHash` commits to the activation
  authorization and its recomputed authorization digest. A supplied digest must
  equal that recomputation.

Use the matching signing helper and compare it with the actual house getter
before collecting a signature:

| Signing helper | Domain name | House getter |
| --- | --- | --- |
| `platformCreationSigningPayload` | `6529StreamPlatformNativeRightsAuction` | `platformRightsCreationDigest` |
| `platformCustodySigningPayload` | `6529StreamPlatformPreparedCustodyAuction` | `platformCustodyAcquisitionDigest` |
| `platformTokenCustodySigningPayload` | `6529StreamPlatformTokenCustodyRights` | `platformTokenCustodyDigest` |

All three use version `1`, the actual chain ID and the house as verifying
contract. The public signing payload includes the complete typed message and
digest. Signature bytes may represent an EOA or ERC-1271 wallet; the helper
cannot establish that the platform currently accepts them.

## Prepare, inspect and simulate

The registration builders return an immutable packet containing `caller`,
`payload`, the unsigned `call`, and digest/configuration read calls:

```javascript
const prepared = preparePlatformCustodyRegistration(
  chainId, house, config, original, tokenData, authorization, platformSignature,
);
const inspection = await inspectPlatformCustodyRegistration(
  provider, prepared, config, original,
  { resolver, artistRegistry }, { blockTag: reviewedBlockNumber },
);
await simulatePreparedPlatformWrite(
  provider, prepared, { blockTag: reviewedBlockNumber },
);
const safeCall = toSafeCall(prepared.call);
```

`preparePlatformRightsRegistration` requires the original poster as caller and
uses zero native value. `preparePlatformCustodyRegistration` uses the signed
executor as caller and exactly `revealFeeDeposit` as native value. That executor
may differ from the original poster. Keep the original poster for rights and
beneficiary selection; the acquisition funding account remains the executor.

Prepared custody binds the expected sale nonce, token ID, collection serial,
Manager operation nonce, context and artwork hash. Confirm these coordinates
again before submission. The deposit must cover the actual current reveal fee;
it is not a replacement for the signed exact transaction value.

Inspectors take a concrete nonnegative block number. They compare canonical
digest/configuration getters, nominated source bindings, declaration state and
the selected assignment. Activation inspection also reads the original auction,
stored declaration, custody origin and activation nonce. The result separately
lists checked facts and checks it does not perform. A numeric pin does not detect
a reorganization during those reads; applications must independently verify the
reviewed block hash and refresh after a reorganization.

Families 8–11 have no public creation-nonce getter. Exact mint coordinates,
complete declaration admission, template grammar, runtime identity, current
timing, phase eligibility and platform signature acceptance remain contract
checks. The inspector is a partial preflight, not an authorization or readiness
certificate. The caller must verify the deployment and ABI provenance.

Simulation validates the packet's canonical linkage and issues one `eth_call`
from its required caller with its exact target, data and native value. It does
not execute predecessor calls, reserve a nonce, submit a transaction or prove
Safe authorization. Refresh changed state and simulate again before execution.

## Activate and use known-token custody rights

`preparePlatformTokenCustodyActivation` takes the original poster, the exact
activation authorization and platform signature. Activation must precede the
first bid and preserve the original custody NFT. After a confirmed activation,
read back the stored activation and effective configuration hash using the
current generated bindings.

Use `preparePlatformTokenCustodyBid`,
`prepareSignedPlatformTokenCustodyBid` and
`preparePlatformTokenCustodySettlement` after activation. These select the
dedicated PLATFORM token-custody entrypoints. Ordinary bid/settlement calls are
not substitutes for them. Before activation, families 8–11 use the ordinary
native house entrypoints through the current generated bindings.

Known-token custody bids carry **zero actual reveal fee**: their native value
is exactly the bid amount. Supplying a nonzero reveal-fee argument is rejected.
Signed bids retain `nativeAuctionBidTypedData`, the existing
`6529StreamNativeEnglishAuction` domain, and the activated effective config hash.
The signed `maxRevealFee` is a cap, not an additional deposit. The executor sends
the signed bid; the payer and delivery recipient remain the signed identities.

Follow the [Safe CALL plan guide](safe-call-plans.md) for ordered review,
individual simulation and receipt checks. After a failed Safe execution, inspect
the failure and current state before retrying. Preserve the reviewed target
calldata/value when retrying the same operation; a new Safe envelope may require
a new Safe nonce and signatures.

## Evidence and limits

The compiled interface fixture records its source commit and SHA-256 hashes of
the successful Solidity input/output. Regenerate or check it with:

```sh
node scripts/generate-current-platform-fixture.mjs INPUT OUTPUT SOURCE_COMMIT --check
```

Tests cover literal Solidity hash preimages, compiled ABI encoding, packet
mutation rejection and synthetic RPC boundaries. They do not demonstrate a
deployed platform signature, current-stack purchase or Safe transaction.
Combined contract/runtime and new-candidate acceptance remain separate.
