# ADR 0001: Drop Authorization

## Status

Accepted.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P0-AUTH-ADR](https://github.com/6529-Collections/6529Stream/issues/17) |
| Blocks | `P0-AUTH-001`, `P0-AUTH-002`, `P0-AUTH-003` |
| Related issues | [P0-AUTH-001](https://github.com/6529-Collections/6529Stream/issues/18), [P0-AUTH-002](https://github.com/6529-Collections/6529Stream/issues/10), [P0-AUTH-003](https://github.com/6529-Collections/6529Stream/issues/19) |
| Affected contract | `smart-contracts/StreamDrops.sol` |
| Work type | `DESIGN` |

## Problem

Drop execution needs a signer-authorized, replay-safe, wallet-compatible design
before any public beta claim. At ADR acceptance, the implementation was
intentionally characterized but unsafe:

- `StreamDrops.mintDrop` could only be called by `tdhSigner`.
- Drop IDs were built from ad hoc string concatenation and `abi.encodePacked`.
- Replay protection was only `dropExecuted[dropId]` for the packed drop ID.
- There was no EIP-712 domain, deadline, signer epoch, revocation model,
  signature malleability policy, or ERC-1271 contract signer stance.
- Before `P0-AUTH-001`, fixed-price token recipient and stored execution
  address used `tx.origin`.

## Implementation Status

`P0-AUTH-001` removed executable `tx.origin` usage from drop execution.

`P0-AUTH-002` replaces the packed-hash drop path with:

- `DropAuthorization` EIP-712 typed data
- domain-separated hashing with `name`, `version`, `chainId`, and
  `verifyingContract`
- consumed and cancelled `dropId` storage
- `signerEpoch` rotation
- per-drop cancellation
- EOA signature recovery with low-`s`, valid-`v`, and zero-signer checks
- EIP-2098 compact signature support
- explicit fail-closed behavior for contracts that do not return a valid
  ERC-1271 response

`P0-AUTH-003` adds ERC-1271 contract signer validation against the same EIP-712
digest. Contract signers must return the standard magic value from
`isValidSignature(bytes32,bytes)`. Empty returns, short returns, invalid magic
values, extra return data, reverts, wrong digest, and wrong signature bytes fail
closed.

## Pre-Implementation Baseline Behavior

Historical source references from the pre-EIP-712 baseline:

- `smart-contracts/StreamDrops.sol#L58-L61`: `authorized` requires
  `msg.sender == tdhSigner`.
- `smart-contracts/StreamDrops.sol#L81-L146`: `mintDrop` accepts an explicit
  recipient, computes a packed drop ID, marks it executed, pushes fixed-price
  ETH, mints, and stores execution state.
- `smart-contracts/StreamDrops.sol#L92-L104`: drop ID is derived from
  `abi.encodePacked` string fragments including the explicit recipient.
- `smart-contracts/StreamDrops.sol#L105-L106`: replay prevention is keyed only by
  `dropExecuted[dropId]`.
- `smart-contracts/StreamDrops.sol#L113-L144`: fixed-price recipient and stored
  execution address use the explicit `_recipient`; auction `_recipient` must be
  `address(0)`, while the stored execution address uses the poster for the
  current no-bid settlement fallback.
- `smart-contracts/StreamDrops.sol#L235-L257`:
  `retrieveMessageAndDropID` exposes the same packed string hashing model.
- `ops/SLITHER_BASELINE.md`: high-impact `encode-packed-collision` findings are
  tracked for both `mintDrop` and `retrieveMessageAndDropID`.

Characterization tests intentionally pin these behaviors as migration
tripwires:

- `test/StreamDropsCharacterization.t.sol`
- `test/StreamDropsIntegrationCharacterization.t.sol`

## Decision

6529Stream will replace drop authorization with EIP-712 typed structured data
and storage-backed replay protection.

The public-beta target design is:

1. `tx.origin` is removed from protocol authorization and recipient logic.
2. Drop intent is signed as EIP-712 typed data.
3. The EIP-712 domain includes:
   - `name`: `6529StreamDrops`
   - `version`: `1`
   - `chainId`
   - `verifyingContract`
4. A signed drop intent includes, at minimum:
   - `dropId`
   - `poster`
   - `recipient`
   - `payer`
   - `collectionId`
   - `saleMode`
   - `tokenDataHash`
   - `price`
   - `quantity`
   - `auctionReservePrice`
   - `auctionEndTime`
   - `salt`
   - `nonce`
   - `deadline`
   - `signerEpoch`
5. `tokenDataHash` is `keccak256(bytes(tokenData))`. Raw token data may be
   passed to the minting function for storage/rendering, but the signature binds
   to the hash. The contract must verify
   `keccak256(bytes(tokenData)) == auth.tokenDataHash` before storing token
   data, rendering metadata, or emitting token-data-bearing events.
6. For fixed-price execution, `recipient` is the NFT receiver and the stored
   execution address. For auction execution, the eventual NFT receiver is
   determined by auction settlement; until ADR 0002 defines custody and
   settlement semantics, signed auction authorizations must set
   `recipient == address(0)` and the contract must reject non-zero auction
   recipients.
7. For the initial P0 implementation, `payer` must equal `msg.sender` for
   payable fixed-price execution.
8. For free fixed-price execution, where `price == 0`, `payer` must equal
   `address(0)`. For auction execution, `payer` must equal `address(0)` until
   ADR 0003 defines bid-time payment semantics. Open relayer execution is out
   of scope until a later ADR explicitly defines reimbursement and payment
   semantics.
9. `poster` is signed attribution and payment-routing metadata. The P0 contract
   treats a valid signer signature as authorization for the supplied `poster`
   and does not enforce `poster == signer`. Off-chain signer pipelines may
   enforce poster-to-signer policy, but changing the on-chain interpretation of
   `poster` requires a later ADR and an EIP-712 version bump.
10. Sale-mode-specific price fields must not be silent. For fixed-price
    execution, `price` is the fixed payment amount, and `auctionReservePrice`
    and `auctionEndTime` must both be zero. For auction execution,
    `auctionReservePrice` is the reserve price, `auctionEndTime` is the auction
    end time, and `price` must be zero. Buy-now auction pricing is out of scope
    for P0 and requires a later ADR plus an EIP-712 version bump.
11. `quantity` must equal `1` in the P0 design. The contract must reject any
   authorization with `quantity != 1`. Batch minting or one authorization to
   many tokens requires a later ADR and an EIP-712 version bump.
12. `salt` is signer/integrator-chosen entropy used in the signed payload and
   `dropId` derivation. When the active signer is an ERC-1271 ZK authorizer,
   `salt` is also the canonical authorization carrier for the ZK nullifier:
   encode `salt = uint256(nullifierHash)` and require the proof to bind that
   nullifier to the EIP-712 digest. It is not an EIP-712 domain `salt`, and the
   contract does not store or validate it separately.
13. `nonce` is a signer-allocated opaque unique value within a `signerEpoch`, not
   an on-chain monotonic counter. There is no `signerNonces` storage in the P0
   design. `dropId` is the derived replay identifier, not an independent nonce.
   After validating the signer, the contract must require:
   `dropId == keccak256(abi.encode(DROP_ID_TYPEHASH, signer, signerEpoch, nonce, salt))`.
   `DROP_ID_TYPEHASH` is
   `keccak256("DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt)")`.
   The signer pipeline must not issue two live payloads with the same
   `(signer, signerEpoch, nonce, salt)` tuple.
14. `dropId` must be globally unique and consumed in storage before any external
   calls that can transfer ETH or invoke receiver hooks. P0 replay and
   cancellation storage is keyed by `dropId`; no separate per-epoch nonce, salt,
   or nullifier mapping is required unless a later implementation ADR expands
   the accounting model.
15. `deadline` must be enforced against `block.timestamp`.
16. `signerEpoch` must match current contract state so signer compromise or
    rotation can invalidate outstanding payloads.
17. Admins must be able to cancel a specific `dropId` before execution.
18. EOA signatures are supported by `P0-AUTH-002`.
19. ERC-1271 contract signatures are supported by `P0-AUTH-003`.
20. EOA signature and execution validation must reject:
    - wrong signer
    - wrong domain
    - wrong chain ID
    - wrong verifying contract
    - expired deadline
    - replayed drop ID
    - cancelled drop ID
    - stale signer epoch
    - zero poster
    - sale-mode-specific payer violation
    - fixed-price authorization with non-zero auction fields
    - auction authorization with non-zero fixed-price field
    - quantity other than one
    - malleable signature
    - zero-address recovered signer
21. ERC-1271 signatures must require the standard magic value from the contract
    signer.
22. EIP-2098 compact signatures are supported and normalized under the same
    malleability policy as 65-byte ECDSA signatures.

## Intended API Shape

The implementation may choose exact Solidity names, but it should preserve this
interface shape:

```solidity
struct DropAuthorization {
    bytes32 dropId;
    address poster;
    address recipient;
    address payer;
    uint256 collectionId;
    uint8 saleMode;
    bytes32 tokenDataHash;
    uint256 price;
    uint256 quantity;
    uint256 auctionReservePrice;
    uint256 auctionEndTime;
    uint256 salt;
    uint256 nonce;
    uint256 deadline;
    uint256 signerEpoch;
}
```

The implementation should expose a typed-data helper or documented off-chain
fixture so integrators can reproduce the digest exactly.

The helper must also expose the `dropId` derivation:

```solidity
DROP_ID_TYPEHASH = keccak256(
    "DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt)"
);

dropId = keccak256(
    abi.encode(DROP_ID_TYPEHASH, signer, signerEpoch, nonce, salt)
);
```

`DROP_ID_TYPEHASH` is distinct from the EIP-712 authorization type hash. The
domain separator already binds `chainId` and `verifyingContract`; the derived
`dropId` is only the replay/cancellation identifier for the validated signer,
epoch, nonce, and salt tuple.

For ERC-1271 ZK authorizers, `salt` should be treated as
`uint256(nullifierHash)`. The authorizer cannot consume a nullifier inside
`isValidSignature` because `StreamDrops` calls ERC-1271 with `staticcall`.
Instead, the authorizer should verify that the proof public inputs bind the
nullifier hash to the supplied EIP-712 digest, and `StreamDrops` consumes the
derived `dropId` as the stateful one-time-use record.

The legacy `mintDrop(address,address,string,uint256,uint256,uint256,uint256)`
path must not be available as a public-beta drop execution path. `P0-AUTH-002`
removes that ABI in favor of `mintDrop(DropAuthorization,string,bytes)`.

## Replay, Revocation, And Signer Compromise

Replay protection is contract storage, not an assumption provided by EIP-712.

Required state:

- `mapping(bytes32 => bool) consumedDropIds`
- `mapping(bytes32 => bool) cancelledDropIds`
- `uint256 signerEpoch` or equivalent epoch state
- signer registry or signer address state, as finalized by the admin/governance
  ADR

Required controls:

- recompute `dropId` from the validated signer, `signerEpoch`, `nonce`, and
  `salt`
- consume `dropId` before external calls
- reject consumed or cancelled `dropId`
- reject stale signer epoch
- emit events for consumption, cancellation, and signer epoch changes
- expose read-only views for consumed and cancelled drop IDs

Signer compromise response:

1. Pause drop execution if the admin/governance ADR supplies a pause control.
2. Rotate signer or increment signer epoch.
3. Cancel known affected drop IDs where practical.
4. Publish the compromised epoch and replacement epoch in the security notes.

## Events

The P0 implementation must emit events for external state transitions. Event
names may change during implementation, but the event catalog must include:

- drop authorization consumed
- drop authorization cancelled
- signer epoch changed
- drop signer changed, if signer address changes are implemented in this
  contract

Events should include stable IDs and indexed query fields where useful:

- indexed `dropId`
- indexed `signer`
- indexed `poster`
- indexed `recipient`
- `payer`
- `collectionId`
- `saleMode`
- `tokenDataHash`
- `deadline`
- `signerEpoch`

## Alternatives Considered

### Keep Signer-Only Execution

Rejected. Requiring `msg.sender == tdhSigner` centralizes execution, makes
third-party integration brittle, and does not solve typed replay-safe
authorization.

### Continue `eth_sign` Or String Signing

Rejected. Human-readable strings are ambiguous, easier to compose incorrectly,
and do not bind domain fields as clearly as EIP-712.

### Merkle-Only Drops

Rejected for this ADR. Merkle allowlists may be useful later, but they do not
replace a per-drop signed execution authorization model.

### Leave ERC-1271 Out Of Scope

Rejected. Contract signers are expected for Safe, DAO, and smart-wallet
operations. The implementation must support ERC-1271 or the repository cannot
honestly claim contract-wallet-ready drop authorization.

### Allow Open Relayers Immediately

Rejected for P0. Relayers require payment, replay, and cancellation semantics
that overlap with the payment accounting ADR. The first safe implementation
binds payable execution to `payer == msg.sender`; a later ADR may add open
relaying.

## Security Impact

This ADR addresses:

- `tx.origin` recipient and execution bugs
- packed-hash collision risk in drop authorization
- replay across calls, contracts, chains, domains, and signer epochs
- signature malleability
- signer rotation and compromise response
- contract signer compatibility through ERC-1271

This ADR does not by itself fix auction custody, push payments, emergency
withdrawals, randomizer callbacks, or metadata finalization.

## Migration Impact

This is a breaking authorization change before public beta.

Expected migration consequences:

- off-chain drop builders must produce EIP-712 payloads
- old packed drop IDs are not accepted for new public-beta execution
- existing characterization tests that assert unsafe current behavior must be
  updated or replaced by target-state tests in implementation PRs
- downstream indexers should key new drops by typed `dropId`, authorization
  events, and minted token ID

No production migration is promised while the repository remains pre-audit and
not production-ready.

## Test Plan

P0 implementation must add tests for:

- valid EOA signature
- valid ERC-1271 contract signature
- invalid ERC-1271 magic value, reverted signature check, empty return, and
  malformed short or extra return data
- wrong ERC-1271 digest and wrong contract signature bytes
- contract signer without an ERC-1271 implementation fails closed
- wrong `dropId` for the signer, `signerEpoch`, `nonce`, and `salt`
- wrong signer
- wrong domain name or version
- wrong chain ID
- wrong verifying contract
- expired deadline
- replayed drop ID
- cancelled drop ID
- stale signer epoch
- malleable ECDSA signature
- EIP-2098 compact signature
- zero-address recovered signer
- zero poster
- zero recipient
- `quantity != 1`
- payable fixed-price authorization where `payer != msg.sender`
- free fixed-price authorization where `payer != address(0)`
- auction authorization where `payer != address(0)`
- fixed-price authorization where `auctionReservePrice != 0`
- fixed-price authorization where `auctionEndTime != 0`
- auction authorization where `price != 0`
- `poster` attribution is preserved in emitted events and payment-accounting
  inputs without requiring `poster == signer`
- raw `tokenData` substitution under a valid signed `tokenDataHash`
- non-zero auction `recipient` before ADR 0002 defines different semantics
- field substitution for poster, recipient, payer, collection, sale mode,
  token data hash, price, quantity, auction reserve, auction end, salt, nonce,
  deadline, and signer epoch
- contract wallet execution without `tx.origin`
- consumed state is written before external calls
- events for consumption, cancellation, and signer epoch changes

Existing characterization tests must remain useful as pre-refactor evidence but
must not be treated as target-state tests after the implementation lands.

## Rollout Plan

1. Merge this ADR.
2. Implement `P0-AUTH-001`: remove `tx.origin` and use explicit
   recipient/execution fields.
3. Implement `P0-AUTH-002`: add EIP-712 domain, typed schema, EOA signature
   validation, consumed-state storage, deadline checks, compact-signature
   support, and replay tests.
4. Implement `P0-AUTH-003`: add ERC-1271 validation and contract-signer tests.
5. Update docs, examples, and issue links.
6. Remove or disable unsafe legacy public execution paths before public beta.

## Non-Goals

- Defining auction custody and settlement.
- Defining pull-payment accounting and open relayer reimbursement.
- Defining metadata freeze behavior.
- Defining randomizer provider behavior.
- Building a Merkle allowlist model.
- Preserving compatibility with unsafe packed drop IDs for public beta.

## Accepted Risks

- The initial P0 implementation does not support open relayers. This is accepted
  until payment accounting and relayer reimbursement are designed.
- The exact signer registry and pause controls depend on the admin/governance
  ADR. This ADR only requires signer epoch and cancellation semantics to exist.
- The exact auction custody consequences of signed auction drops depend on the
  auction custody ADR. This ADR reserves auction `recipient` as zero and binds
  auction intent fields, but it does not decide custody or settlement transfer
  mechanics.
- EIP-712 payloads are more complex for integrators than the current packed
  string. This is accepted because typed signing is required for safety and
  auditability.
