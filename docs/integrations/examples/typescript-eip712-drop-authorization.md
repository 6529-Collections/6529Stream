# TypeScript EIP-712 Drop Authorization Snippets

These INT-014 TypeScript snippets show how a 6529.io-style React, Next,
mobile, Electron, operator UI, or backend signing-service codebase can build
and validate `StreamDrops.DropAuthorization` typed data. They are pre-audit
guidance for the local baseline, not production-ready, not a security claim,
not a generated SDK, not a signing service implementation, and not a custody
approval.

The sequence covers domain construction, typed-data shape, DropAuthorization
message shape, drop ID derivation, token data hashing, sale-mode validation,
signer boundaries, submission preflight, and no-secret logging.

Use these snippets with [docs/integrations/wallets-and-signatures.md](../wallets-and-signatures.md),
[docs/drop-authorization-signing.md](../../drop-authorization-signing.md),
[docs/signer-custody-readiness.md](../../signer-custody-readiness.md), and
[docs/integrations/examples/typescript-artifacts-and-chain-config.md](typescript-artifacts-and-chain-config.md).

## Maturity And Scope

These snippets describe payload construction and preflight validation only.
They do not replace fork/testnet/live evidence, production signer custody,
external audit evidence, Safe configuration evidence, or release signatures.
Public beta and production remain governed by
[docs/release-readiness.md](../../release-readiness.md),
[docs/public-beta-evidence.md](../../public-beta-evidence.md), and
[release-artifacts/latest/public-beta-evidence.json](../../../release-artifacts/latest/public-beta-evidence.json).

Replay protection is not provided by TypeScript or EIP-712 alone. Replay
protection requires the on-chain domain, storage-backed `consumedDropIds`,
storage-backed `cancelledDropIds`, current `signerEpoch`, `deadline`, and
operator signer-rotation policy.

## Source Of Truth

- [docs/integrations/wallets-and-signatures.md](../wallets-and-signatures.md)
- [docs/drop-authorization-signing.md](../../drop-authorization-signing.md)
- [docs/adr/0001-drop-authorization.md](../../adr/0001-drop-authorization.md)
- [docs/integrations/contract-flows.md](../contract-flows.md)
- [docs/integrations/auction-flows.md](../auction-flows.md)
- [test/fixtures/drop-authorization/fixed-price-eoa.json](../../../test/fixtures/drop-authorization/fixed-price-eoa.json)
- [test/fixtures/drop-authorization/auction-eoa.json](../../../test/fixtures/drop-authorization/auction-eoa.json)
- [test/fixtures/drop-authorization/erc1271-contract-signer.json](../../../test/fixtures/drop-authorization/erc1271-contract-signer.json)
- [test/fixtures/drop-authorization/payload-generator/fixed-price-output.json](../../../test/fixtures/drop-authorization/payload-generator/fixed-price-output.json)
- [test/fixtures/drop-authorization/payload-generator/auction-output.json](../../../test/fixtures/drop-authorization/payload-generator/auction-output.json)
- [scripts/generate_drop_authorization_payload.py](../../../scripts/generate_drop_authorization_payload.py)
- [scripts/check_drop_authorization_fixtures.py](../../../scripts/check_drop_authorization_fixtures.py)
- [smart-contracts/StreamDrops.sol](../../../smart-contracts/StreamDrops.sol)
- [test/StreamDropsEIP712.t.sol](../../../test/StreamDropsEIP712.t.sol)
- [test/StreamDropsERC1271.t.sol](../../../test/StreamDropsERC1271.t.sol)
- [test/StreamSafeERC1271ForkSmoke.t.sol](../../../test/StreamSafeERC1271ForkSmoke.t.sol)

## Domain Construction

Build the domain from the selected chain config. Never let a caller pass an
arbitrary verifying contract after the address book has been selected.

```ts
type Hex = `0x${string}`;
type HexAddress = `0x${string}`;

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as const;

type DropAuthorizationDomain = {
  name: "6529StreamDrops";
  version: "1";
  chainId: number;
  verifyingContract: HexAddress;
};

function makeDropAuthorizationDomain(input: {
  chainId: number;
  streamDropsAddress: HexAddress;
}): DropAuthorizationDomain {
  return {
    name: "6529StreamDrops",
    version: "1",
    chainId: input.chainId,
    verifyingContract: input.streamDropsAddress,
  };
}
```

Wrong chain ID and wrong verifying contract must fail before prompting an EOA,
WalletConnect wallet, Safe, ERC-1271 contract signer, or backend signing
service.

## Typed Data Shape

Keep the typed-data shape literal and reviewed.

```ts
const DROP_AUTHORIZATION_TYPES = {
  DropAuthorization: [
    { name: "dropId", type: "bytes32" },
    { name: "poster", type: "address" },
    { name: "recipient", type: "address" },
    { name: "payer", type: "address" },
    { name: "collectionId", type: "uint256" },
    { name: "saleMode", type: "uint8" },
    { name: "tokenDataHash", type: "bytes32" },
    { name: "price", type: "uint256" },
    { name: "quantity", type: "uint256" },
    { name: "auctionReservePrice", type: "uint256" },
    { name: "auctionEndTime", type: "uint256" },
    { name: "salt", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
    { name: "signerEpoch", type: "uint256" },
  ],
} as const;

type DropAuthorizationMessage = {
  dropId: Hex;
  poster: HexAddress;
  recipient: HexAddress;
  payer: HexAddress;
  collectionId: bigint;
  saleMode: 1 | 2;
  tokenDataHash: Hex;
  price: bigint;
  quantity: bigint;
  auctionReservePrice: bigint;
  auctionEndTime: bigint;
  salt: bigint;
  nonce: bigint;
  deadline: bigint;
  signerEpoch: bigint;
};
```

The primary type is `DropAuthorization`. Do not add, remove, reorder, or rename
fields without a contract change, fixture update, and checker update.

## Token Data Hash

Hash the exact bytes submitted to the contract.

```ts
async function tokenDataHash(tokenData: string): Promise<Hex> {
  const bytes = new TextEncoder().encode(tokenData);
  return keccak256(bytes);
}
```

Do not log raw unreleased `tokenData` in public browser logs, mobile telemetry,
Electron renderer logs, support bundles, or signing-service traces. Prefer
`tokenDataHash`, collection ID, signer epoch, nonce, salt, and drop ID for
diagnostics.

## Drop Id Derivation

`dropId` binds signer identity, signer epoch, nonce, and salt.

```ts
declare const DROP_ID_TYPEHASH: Hex;

function deriveDropId(input: {
  signer: HexAddress;
  signerEpoch: bigint;
  nonce: bigint;
  salt: bigint;
}): Hex {
  return keccak256(abiEncode(
    ["bytes32", "address", "uint256", "uint256", "uint256"],
    [
      DROP_ID_TYPEHASH,
      input.signer,
      input.signerEpoch,
      input.nonce,
      input.salt,
    ],
  ));
}
```

The signing service must allocate unique `(signer, signerEpoch, nonce, salt)`
tuples. The contract enforces uniqueness through derived `dropId`,
`consumedDropIds`, and `cancelledDropIds`, not through a separate monotonic
nonce map.

## Fixed-Price Payload

Fixed-price drops use `saleMode = 1`.

```ts
async function makeFixedPriceAuthorization(input: {
  signer: HexAddress;
  poster: HexAddress;
  recipient: HexAddress;
  payer: HexAddress;
  collectionId: bigint;
  tokenData: string;
  price: bigint;
  nonce: bigint;
  salt: bigint;
  deadline: bigint;
  signerEpoch: bigint;
}): Promise<DropAuthorizationMessage> {
  assertNonZeroAddress(input.poster, "poster");
  assertNonZeroAddress(input.recipient, "recipient");
  if (input.price > 0n) assertNonZeroAddress(input.payer, "payer");
  if (input.price === 0n) assertZeroAddress(input.payer, "free fixed-price payer");

  const dropId = deriveDropId(input);
  return {
    dropId,
    poster: input.poster,
    recipient: input.recipient,
    payer: input.payer,
    collectionId: input.collectionId,
    saleMode: 1,
    tokenDataHash: await tokenDataHash(input.tokenData),
    price: input.price,
    quantity: 1n,
    auctionReservePrice: 0n,
    auctionEndTime: 0n,
    salt: input.salt,
    nonce: input.nonce,
    deadline: input.deadline,
    signerEpoch: input.signerEpoch,
  };
}
```

The transaction sender must match signed `payer` for paid fixed-price drops.
Free fixed-price drops require a zero payer and zero `msg.value`.

## Auction Payload

Auction drops use `saleMode = 2` and mint custody to the auction contract.

```ts
async function makeAuctionAuthorization(input: {
  signer: HexAddress;
  poster: HexAddress;
  collectionId: bigint;
  tokenData: string;
  auctionReservePrice: bigint;
  auctionEndTime: bigint;
  nonce: bigint;
  salt: bigint;
  deadline: bigint;
  signerEpoch: bigint;
}): Promise<DropAuthorizationMessage> {
  assertNonZeroAddress(input.poster, "poster");
  assertFutureTimestamp(input.auctionEndTime, "auctionEndTime");

  const dropId = deriveDropId(input);
  return {
    dropId,
    poster: input.poster,
    recipient: ZERO_ADDRESS,
    payer: ZERO_ADDRESS,
    collectionId: input.collectionId,
    saleMode: 2,
    tokenDataHash: await tokenDataHash(input.tokenData),
    price: 0n,
    quantity: 1n,
    auctionReservePrice: input.auctionReservePrice,
    auctionEndTime: input.auctionEndTime,
    salt: input.salt,
    nonce: input.nonce,
    deadline: input.deadline,
    signerEpoch: input.signerEpoch,
  };
}
```

Auction payload construction must reject nonzero recipient, nonzero payer,
nonzero price, and missing auction end time before signing.

## Pre-Signature Validation

Run validation before signing, before persisting payloads, and again before
submission.

```ts
function assertDropAuthorizationPreflight(input: {
  domain: DropAuthorizationDomain;
  message: DropAuthorizationMessage;
  expectedSignerEpoch: bigint;
  now: bigint;
  expectedStreamDrops: HexAddress;
  expectedChainId: number;
}) {
  assertNumberEquals(input.domain.chainId, input.expectedChainId, "chain ID");
  assertAddressEquals(
    input.domain.verifyingContract,
    input.expectedStreamDrops,
    "verifying contract",
  );
  assertBigIntEquals(
    input.message.signerEpoch,
    input.expectedSignerEpoch,
    "signer epoch",
  );
  if (input.message.deadline < input.now) throw new Error("expired deadline");
  if (input.message.quantity !== 1n) throw new Error("quantity must be 1");
  assertSaleModeFields(input.message);
}
```

Wrong signer, wrong domain, wrong chain, expired, replayed, cancelled, stale
signer epoch, malformed signature, high-s malleable signature, zero recovered
signer, token-data substitution, and bad sale-mode fields must all fail closed.

## Signer Boundary

Production signer keys and Safe owner keys do not belong in browser, mobile,
Electron renderer, or operator support tooling.

```ts
type TypedDataToSign = {
  domain: DropAuthorizationDomain;
  types: typeof DROP_AUTHORIZATION_TYPES;
  primaryType: "DropAuthorization";
  message: DropAuthorizationMessage;
};

function buildTypedDataToSign(
  domain: DropAuthorizationDomain,
  message: DropAuthorizationMessage,
): TypedDataToSign {
  return {
    domain,
    types: DROP_AUTHORIZATION_TYPES,
    primaryType: "DropAuthorization",
    message,
  };
}
```

EOA signing, ERC-1271 validation, and Safe-approved-hash flows all validate the
same digest and message shape. ERC-1271 support is a signer-validation path,
not a different authorization schema.

## Submission Preflight

Before submitting `executeDrop`, compare current chain, current
`StreamDrops` address, current signer epoch, deadline, `dropId`,
`tokenDataHash`, sale-mode fields, sender, and `msg.value` against the signed
payload.

```ts
async function assertSubmissionMatchesAuthorization(input: {
  sender: HexAddress;
  value: bigint;
  message: DropAuthorizationMessage;
  tokenData: string;
}): Promise<void> {
  assertStringEquals(
    input.message.tokenDataHash,
    await tokenDataHash(input.tokenData),
    "token data hash",
  );
  if (input.message.saleMode === 1 && input.message.price > 0n) {
    assertAddressEquals(input.sender, input.message.payer, "paid fixed-price payer");
    assertBigIntEquals(input.value, input.message.price, "fixed-price value");
  }
  if (input.message.saleMode === 1 && input.message.price === 0n) {
    assertBigIntEquals(input.value, 0n, "free fixed-price value");
  }
  if (input.message.saleMode === 2) {
    assertBigIntEquals(input.value, 0n, "auction creation value");
  }
}
```

Do not let users edit signed fields in the UI. Any edit requires a new
signature and a new `dropId`.

## No-Secret Logging

Log only reviewed public values:

- chain ID;
- verifying contract;
- collection ID;
- sale mode;
- `dropId`;
- `tokenDataHash`;
- signer epoch;
- nonce;
- salt;
- deadline;
- transaction hash; and
- decoded custom error name.

Do not log private keys, seed phrases, signer-service credentials, raw
signatures, Safe owner material, WalletConnect pairing URIs, WalletConnect
session topics, raw unreleased `tokenData`, bearer tokens, private RPC URLs, or
admin credentials.

## Testing And Fixtures

Consumers should test against committed fixtures and their own generated
payloads:

- fixed-price EOA typed data matches the fixture;
- auction EOA typed data matches the fixture;
- ERC-1271 contract signer payload uses the same digest;
- wrong chain ID fails before signing;
- wrong verifying contract fails before signing;
- edited signed fields force a new signature;
- wrong payer/value semantics fail before submission;
- stale signer epoch fails before signing or submission;
- expired deadline fails before signing or submission;
- raw signatures and raw unreleased token data are redacted from logs; and
- replay/cancellation is attributed to on-chain storage state.

## Validation Commands

```sh
python scripts/test_typescript_eip712_drop_authorization.py
python scripts/check_typescript_eip712_drop_authorization.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_wallet_signature_flows.py
python scripts/check_wallet_signature_flows.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
make typescript-eip712-drop-authorization-check
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update these snippets whenever the EIP-712 domain, typed-data fields,
sale-mode semantics, signer epoch policy, fixture generator, signature
validation path, or drop authorization fixtures change. Keep examples
framework-light and preserve the order: artifact/chain config, domain, message,
drop ID, token-data hash, sale-mode validation, signer boundary, submission
preflight, then logs.
