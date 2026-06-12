# Drop Authorization Signing

This guide documents the current no-secret local examples for signing
`StreamDrops.DropAuthorization` payloads. It is pre-audit, not production-ready,
and not a security claim. The fixtures use placeholder Anvil
addresses and deterministic test signatures only; they are not live or
unreleased drop payloads.

## Maturity And Scope

The authoritative implementation is
[`smart-contracts/StreamDrops.sol`](../smart-contracts/StreamDrops.sol). The
accepted protocol decision is
[`docs/adr/0001-drop-authorization.md`](adr/0001-drop-authorization.md), and
the target-state Solidity coverage lives in
[`test/StreamDropsEIP712.t.sol`](../test/StreamDropsEIP712.t.sol),
[`test/StreamDropsERC1271.t.sol`](../test/StreamDropsERC1271.t.sol), and
[`test/helpers/DropAuthTestHelper.sol`](../test/helpers/DropAuthTestHelper.sol).

This guide covers:

- fixed-price EOA signing;
- auction EOA signing;
- ERC-1271 contract-signer expectations using the local mock path;
- replay, cancellation, signer epoch rotation, deadline, wrong domain, wrong
  signer, zero address, and token-data substitution failures.

It does not add a production signing service, production key custody, live
payload distribution, or public-beta readiness.

## Canonical EIP-712 Schema

`StreamDrops` signs the following EIP-712 domain:

```json
{
  "name": "6529StreamDrops",
  "version": "1",
  "chainId": 31337,
  "verifyingContract": "0x100000000000000000000000000000000000dEaD"
}
```

Production payloads must replace `chainId` and `verifyingContract` with the
live network and deployed `StreamDrops` address. The on-chain domain separator
uses `EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)`.

The signed primary type is:

```text
DropAuthorization(
  bytes32 dropId,
  address poster,
  address recipient,
  address payer,
  uint256 collectionId,
  uint8 saleMode,
  bytes32 tokenDataHash,
  uint256 price,
  uint256 quantity,
  uint256 auctionReservePrice,
  uint256 auctionEndTime,
  uint256 salt,
  uint256 nonce,
  uint256 deadline,
  uint256 signerEpoch
)
```

The contract exposes `DROP_AUTHORIZATION_TYPEHASH` for the full payload and
`DROP_ID_TYPEHASH` for:

```text
DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt)
```

`dropId` must equal `deriveDropId(signer, signerEpoch, nonce, salt)`.
`tokenDataHash` must equal `keccak256(bytes(tokenData))`. EIP-712 provides the
domain-separated encoding and signature digest only; replay protection is
storage-backed through `consumedDropIds`, `cancelledDropIds`, signer epoch
rotation, unique nonce/salt allocation, and deadline checks.

## Fixture Index

The committed fixtures are local, deterministic, and no-secret:

| Fixture | Purpose | Signature path |
| --- | --- | --- |
| [`fixed-price-eoa.json`](../test/fixtures/drop-authorization/fixed-price-eoa.json) | Free fixed-price mint to an explicit recipient | 65-byte EOA signature |
| [`auction-eoa.json`](../test/fixtures/drop-authorization/auction-eoa.json) | Auction drop creation with poster, reserve, end time, and auction custody | 65-byte EOA signature |
| [`erc1271-contract-signer.json`](../test/fixtures/drop-authorization/erc1271-contract-signer.json) | Fixed-price mint authorized by a local ERC-1271 mock signer | mock bytes plus `0x1626ba7e` |

Every fixture includes:

- the complete EIP-712 `types`, `domain`, `primaryType`, and `message`;
- the raw `token_data` string supplied to `mintDrop`;
- expected `drop_id`, `token_data_hash`, `domain_separator`, `struct_hash`,
  and EIP-712 `digest`;
- expected signature bytes or ERC-1271 mock bytes;
- no-secret policy flags;
- failure cases that tie the fixture to expected revert paths.

## Unsigned Payload Generator

Use
[`scripts/generate_drop_authorization_payload.py`](../scripts/generate_drop_authorization_payload.py)
to produce canonical unsigned EIP-712 typed data from no-secret JSON input
templates. The generator does not accept signing key material, does not sign,
does not broadcast, and does not turn local evidence into production readiness.
It emits the `typed_data`, `token_data`, `dropId`, `tokenDataHash`,
`domainSeparator`, `structHash`, and `digest` that an external signer or
signing service can compare before returning a signature.

The maintained local templates and generated unsigned outputs are:

| Input | Generated output | Sale mode |
| --- | --- | --- |
| [`fixed-price-input.json`](../test/fixtures/drop-authorization/payload-generator/fixed-price-input.json) | [`fixed-price-output.json`](../test/fixtures/drop-authorization/payload-generator/fixed-price-output.json) | fixed price |
| [`auction-input.json`](../test/fixtures/drop-authorization/payload-generator/auction-input.json) | [`auction-output.json`](../test/fixtures/drop-authorization/payload-generator/auction-output.json) | auction |

Check or regenerate the committed examples with:

```sh
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
```

The generator regression tests live in
[`scripts/test_drop_authorization_payload_generator.py`](../scripts/test_drop_authorization_payload_generator.py).

For production use, replace the placeholder `chainId`, `verifyingContract`,
`signer`, recipient, poster, nonce, salt, deadline, and sale fields in a
reviewed private working copy, then pass the generated typed data to the
approved signing system. Retain the generated payload, signer identity, signer
epoch, reviewer approval, returned signature, and command evidence separately
under the non-local evidence process.

## Operator Signing Flow

Use this flow for a real signing service or an offline ceremony:

1. Read the deployed `StreamDrops` address, active `tdhSigner`, current
   `signerEpoch`, and target `chainId`.
2. Allocate a signer-scoped `nonce` and random `salt`; never reuse the same
   `(signer, signerEpoch, nonce, salt)` tuple.
3. Build `dropId = deriveDropId(signer, signerEpoch, nonce, salt)`.
4. Hash the exact `tokenData` string as `tokenDataHash`.
5. Set `deadline` to the last acceptable execution timestamp.
6. Fill fixed-price or auction sale fields exactly as described below.
7. Sign the typed data with the current EOA signer, or configure the current
   ERC-1271 signer so `isValidSignature(digest, signature)` returns
   `0x1626ba7e`.
8. Retain the typed-data JSON, digest, signature result, signer identity,
   signer epoch, and reviewer approval as no-secret release evidence.

For local verification of the fixture EOA signatures, use the digest and
signature fields with Foundry `cast wallet verify --no-hash --address`. In
production, use a secure signer or HSM-backed flow and never commit key
material.

## Replay And Revocation Model

Replay protection is not automatic just because EIP-712 is used.
`StreamDrops.mintDrop` recomputes the digest, validates the signer, validates
the payload, then writes `consumedDropIds[dropId] = true` before executing the
sale path. A second execution of the same signed payload fails with
`Drop Executed`.

Admins can call `cancelDrop(dropId)` before execution, which writes
`cancelledDropIds[dropId] = true`. Later execution fails with `Drop cancelled`.
Admins can also rotate or invalidate the signer epoch. Payloads signed for an
old `signerEpoch` fail with `Bad epoch` even if their EOA or ERC-1271 signature
is otherwise valid.

The failure checklist in each fixture covers wrong signer, wrong domain,
expired deadline, replay, cancellation, stale signer epoch, bad drop ID, token
data substitution, and zero address validation. These are also covered by the
Solidity tests linked above.

## Auction Signing Notes

Auction payloads set `saleMode = 2`, `recipient = address(0)`, `payer =
address(0)`, `price = 0`, `auctionReservePrice` to the poster-approved reserve,
and `auctionEndTime` to the signed bid end timestamp. The bid start happens
when `mintDrop` creates the token and registers the auction with the configured
auction contract. The bid end window is the signed `auctionEndTime`.

The signature does not carry every auction policy. Minimum bid and increment
rules are enforced by the auction contract after registration. The current
auction custody expectation is that the minted NFT is held by the auction
contract until the auction state machine reaches no-bid settlement, with-bid
settlement, or cancellation. Operators should retain the signed auction payload
and later auction ceremony evidence together so the poster, reserve, bid
start/end windows, minimum bid assumptions, and custody history can be reviewed.

## ERC-1271 Contract Signers

If the active `tdhSigner` is a contract, `StreamDrops` does not attempt ECDSA
recovery. It calls:

```solidity
isValidSignature(bytes32 digest, bytes signature)
```

The call must succeed, return exactly 32 bytes, and decode to the ERC-1271 magic
value `0x1626ba7e`. Invalid magic, empty return, short return, extra return,
revert, wrong digest, and wrong signature bytes all fail closed with `Bad
contract sig`.

The fixture
[`erc1271-contract-signer.json`](../test/fixtures/drop-authorization/erc1271-contract-signer.json)
uses the local mock signature bytes from
[`test/StreamDropsERC1271.t.sol`](../test/StreamDropsERC1271.t.sol). It is a
contract-signer example, not an EOA signature.

## Failure Checklist

Before any production drop signing ceremony, verify:

- domain `name`, `version`, `chainId`, and `verifyingContract` match the target
  deployment;
- the recovered EOA signer, or the ERC-1271 contract signer, matches the active
  `tdhSigner`;
- `signerEpoch` matches the current contract state;
- `dropId` derives from signer, `signerEpoch`, `nonce`, and `salt`;
- `nonce` and `salt` are unique for the signer epoch;
- `deadline` leaves enough operational time but is not open-ended;
- fixed-price payloads use a non-zero `recipient`, optional `payer`, exact
  `msg.value == price`, and zero auction fields;
- auction payloads use zero `recipient`, zero `payer`, zero `price`, signed
  `auctionReservePrice`, signed `auctionEndTime`, and known auction custody;
- `tokenDataHash` matches the exact `tokenData` bytes that will be submitted;
- replayed, cancelled, stale-epoch, wrong-domain, wrong-signer, zero address,
  malleable, and malformed signatures fail in local tests.

## Local Verification Commands

```sh
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
make check
```

## Maintenance

Update this guide and the fixtures whenever `StreamDrops.DropAuthorization`,
`DROP_AUTHORIZATION_TYPEHASH`, `DROP_ID_TYPEHASH`, domain construction,
ERC-1271 validation, signer lifecycle controls, replay storage, or auction
registration semantics change.

Required cross-links:

- [`docs/known-blockers.md`](known-blockers.md)
- [`docs/release-readiness.md`](release-readiness.md)
- [`docs/tooling.md`](tooling.md)
- [`docs/audit-package.md`](audit-package.md)
- [`docs/incident-response.md`](incident-response.md)
- [`ops/ROADMAP.md`](../ops/ROADMAP.md)
