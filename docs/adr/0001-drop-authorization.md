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
before any public beta claim. The current implementation is intentionally
characterized but unsafe:

- `StreamDrops.mintDrop` can only be called by `tdhSigner`.
- Fixed-price token recipient and stored execution address use `tx.origin`.
- Drop IDs are built from ad hoc string concatenation and `abi.encodePacked`.
- Replay protection is only `dropExecuted[dropId]` for the packed drop ID.
- There is no EIP-712 domain, deadline, signer epoch, revocation model,
  signature malleability policy, or ERC-1271 contract signer stance.

## Current Behavior

Current source references:

- `smart-contracts/StreamDrops.sol#L55-L58`: `authorized` requires
  `msg.sender == tdhSigner`.
- `smart-contracts/StreamDrops.sol#L72-L110`: `mintDrop` computes a packed
  drop ID, marks it executed, pushes fixed-price ETH, mints, and stores
  execution state.
- `smart-contracts/StreamDrops.sol#L73`: drop ID is derived from
  `abi.encodePacked` string fragments.
- `smart-contracts/StreamDrops.sol#L74-L75`: replay prevention is keyed only by
  `dropExecuted[dropId]`.
- `smart-contracts/StreamDrops.sol#L86`: fixed-price receiver is `tx.origin`.
- `smart-contracts/StreamDrops.sol#L108`: stored execution address is
  `tx.origin`.
- `smart-contracts/StreamDrops.sol#L175-L179`:
  `retrieveMessageAndDropID` exposes the same packed string hashing model.
- `ops/SLITHER_BASELINE.md`: high-impact `encode-packed-collision` findings are
  tracked for both `mintDrop` and `retrieveMessageAndDropID`.

Current characterization tests intentionally pin these behaviors as migration
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
   payable fixed-price execution. Open relayer execution is out of scope until a
   later ADR explicitly defines reimbursement and payment semantics.
8. `quantity` must equal `1` in the P0 design. The contract must reject any
   authorization with `quantity != 1`. Batch minting or one authorization to
   many tokens requires a later ADR and an EIP-712 version bump.
9. `salt` is signer/integrator-chosen entropy used only in the signed payload
   and `dropId` derivation. It is not an EIP-712 domain `salt`, and the contract
   does not store or validate it separately.
10. `nonce` is a signer-allocated opaque unique value within a `signerEpoch`, not
   an on-chain monotonic counter. There is no `signerNonces` storage in the P0
   design. `dropId` is the derived replay identifier, not an independent nonce.
   After validating the signer, the contract must require:
   `dropId == keccak256(abi.encode(DROP_ID_TYPEHASH, signer, signerEpoch, nonce, salt))`.
   The signer pipeline must not issue two live payloads with the same
   `(signer, signerEpoch, nonce, salt)` tuple.
11. `dropId` must be globally unique and consumed in storage before any external
   calls that can transfer ETH or invoke receiver hooks. P0 replay and
   cancellation storage is keyed by `dropId`; no separate per-epoch nonce or
   salt mapping is required unless a later implementation ADR expands the
   accounting model.
12. `deadline` must be enforced against `block.timestamp`.
13. `signerEpoch` must match current contract state so signer compromise or
    rotation can invalidate outstanding payloads.
14. Admins must be able to cancel a specific `dropId` before execution.
15. EOA signatures and ERC-1271 contract signatures are supported.
16. EOA signature and execution validation must reject:
    - wrong signer
    - wrong domain
    - wrong chain ID
    - wrong verifying contract
    - expired deadline
    - replayed drop ID
    - cancelled drop ID
    - stale signer epoch
    - quantity other than one
    - malleable signature
    - zero-address recovered signer
17. ERC-1271 signatures must require the standard magic value from the contract
    signer.
18. EIP-2098 compact signatures are supported and normalized under the same
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
dropId = keccak256(
    abi.encode(DROP_ID_TYPEHASH, signer, signerEpoch, nonce, salt)
);
```

`DROP_ID_TYPEHASH` is distinct from the EIP-712 authorization type hash. The
domain separator already binds `chainId` and `verifyingContract`; the derived
`dropId` is only the replay/cancellation identifier for the validated signer,
epoch, nonce, and salt tuple.

The legacy `mintDrop(address,string,uint256,uint256,uint256,uint256)` path may
remain temporarily during migration work, but it must not be available as a
public-beta drop execution path unless it enforces this ADR's authorization
semantics.

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
- contract signer compatibility

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
- zero recipient
- `quantity != 1`
- raw `tokenData` substitution under a valid signed `tokenDataHash`
- non-zero auction `recipient` before ADR 0002 defines different semantics
- field substitution for poster, recipient, payer, collection, sale mode,
  token data hash, price, quantity, auction reserve, auction end, salt, nonce,
  deadline, and signer epoch
- contract wallet execution without `tx.origin`
- `payer != msg.sender` rejection in the initial P0 implementation
- consumed state is written before external calls
- events for consumption, cancellation, and signer epoch changes

Existing characterization tests must remain useful as pre-refactor evidence but
must not be treated as target-state tests after the implementation lands.

## Rollout Plan

1. Merge this ADR.
2. Implement `P0-AUTH-001`: remove `tx.origin` and use explicit signed
   recipient/execution fields.
3. Implement `P0-AUTH-002`: add EIP-712 domain, typed schema, signature
   validation, consumed-state storage, deadline checks, and replay tests.
4. Implement `P0-AUTH-003`: add ERC-1271 validation and compact-signature
   policy tests.
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
