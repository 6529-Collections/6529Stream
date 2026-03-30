# 6529Stream

## ELI5: What This Project Does

Imagine a system for releasing digital art where:

1. A trusted organizer approves a drop.
2. The art piece gets minted as an NFT.
3. Buyers can either buy directly or bid in an auction.
4. The money gets split between the artist/poster, the platform payout address, and a curators pool.
5. Curators can later claim their rewards with proof they are eligible.

That is what 6529Stream does on-chain.

In short: **it is a smart-contract pipeline for approved drops -> NFT minting -> optional auctions -> reward distribution.**

---

## Technical Overview

6529Stream is a drop-to-mint protocol for generative NFT collections, adapted from NextGen-style contracts.  
The protocol is organized into modular contracts for admin control, collection storage, minting windows, drop execution, auction settlement, and curator rewards.

### High-Level Flow

1. **Admin permissions are configured** in `StreamAdmins`.
2. **Collection metadata and supply** are set in `StreamCore`.
3. **Mint windows** are configured in `StreamMinter`.
4. **An authorized signer executes drops** via `StreamDrops.mintDrop(...)`.
5. **Optional auction lifecycle** is handled by `StreamAuctions`.
6. **Curator rewards** are claimed from `StreamCuratorsPool` via merkle proofs.

---

## Repository Layout

Solidity files are organized by responsibility:

- `smart-contracts/contracts`: deployable protocol contracts (`StreamCore`, `StreamMinter`, `StreamDrops`, `StreamAdmins`, `StreamCuratorsPool`, `StreamAuctions`, etc.)
- `smart-contracts/interfaces`: interface definitions (`I*`)
- `smart-contracts/libraries`: reusable libraries
- `smart-contracts/tokens`: ERC token primitives/extensions
- `smart-contracts/utils`: utility contracts (`Ownable`, `ReentrancyGuard`, `Context`)
- `smart-contracts/randomizers`: randomizer and RNG/VRF integrations
- `test`: Foundry tests

---

## Core Contracts

- `StreamAdmins`: global and function-level authorization source of truth.
- `StreamCore`: ERC-721 core, collection configuration, mint bookkeeping, metadata, royalties.
- `StreamMinter`: mint phase windows and mint/mint-to-auction entry points.
- `StreamDrops`: authorized drop execution and payment-splitting logic.
- `StreamCuratorsPool`: merkle-verified curator reward claims.
- `StreamAuctions`: bidding, extension logic, and final auction claim settlement.

---

## How `StreamDrops` Works

`mintDrop` supports two paths:

- **Option `1` (fixed price)**
  - Validates exact payment.
  - Splits payment:
    - 50% to poster
    - 25% to payout address
    - 25% to curators pool
  - Mints via `StreamMinter.mint(...)`.

- **Option `2` (auction)**
  - Mints to auction flow through `StreamMinter.mintAndAuction(...)`.
  - Stores auction poster and starting price for later settlement.

Drop IDs are deterministic hashes of the drop payload, and duplicate execution is blocked.

---

## Testing

The project uses Foundry tests under `test/`.

Current suite validates:

- **Admin controls**: signer and admin authorization boundaries.
- **Minter controls**: stream-drops-only minting, phase gating, supply limits, and auction timing constraints.
- **Drop controls**: constructor safety checks, duplicate prevention, price validation, payment splits, auction metadata forwarding, and execution-address behavior.

Run tests:

```bash
forge test
```

Current status in this repo: **17 passing tests, 0 failing tests**.

---

## Implemented Smart Contract Changes

This section records behavior changes already made:

1. Added zero-address validation in `StreamDrops` constructor for:
   - TDH signer
   - minter contract
   - admin contract
   - payout address
   - curators pool address
2. Replaced `tx.origin` with `msg.sender` in `StreamDrops.mintDrop` fixed-price mint recipient assignment.
3. Replaced `tx.origin` with `msg.sender` for `executionAddress` recorded in drop info.

These changes reduce `tx.origin` risk and improve deployment/config safety while preserving core protocol flow.

---

## Known Issues / Audit Notes (Temporary)

The following issues are currently known and should be treated as high-priority for a future patch:

1. **Critical: fixed-price mint recipient regression in `StreamDrops`**
   - Current fixed-price flow mints to `msg.sender`.
   - Because `mintDrop` is restricted to the authorized signer, this can mint to the signer instead of the intended buyer.
   - Impact: user-payment vs NFT-delivery mismatch and potential custody/trust failure.

2. **Centralization / trust dependency**
   - `StreamDrops.mintDrop` can only be called by `tdhSigner`.
   - A signer compromise or misuse can control mint execution behavior.
   - Mitigation direction: explicit signed payload validation, signer rotation controls, and operational hardening.

3. **Payment split uses push-transfers with immediate external calls**
   - ETH is forwarded during mint execution to poster/payout/curators using low-level calls.
   - Any recipient-side failure reverts the whole mint path.
   - Mitigation direction: pull-payment model or resilient accounting + separate withdrawals.

4. **Missing event coverage on critical admin/config updates**
   - Contract updates and important config changes are not consistently emitted as events.
   - Impact: weaker monitoring, incident response, and forensic traceability.

5. **Uneven revert ergonomics and custom error usage**
   - Errors rely on mixed string messages and generic reverts.
   - Impact: less precise failure diagnostics and higher gas than custom errors.

These notes are intentionally brief and non-exhaustive; they document current known risk areas pending a full remediation pass.

---

## Alignment With Proposed Stream Notes

This section compares the current contracts against the proposed approach shared in governance notes.

### What Is The Same

1. **NextGen-style architecture is present**
   - The contracts are derived from a NextGen-style system and support optional on-chain metadata/generative script composition in `StreamCore`.

2. **Auction path exists**
   - There is a mint-to-auction flow (`StreamDrops` -> `StreamMinter.mintAndAuction` -> `StreamAuctions`) with anti-sniping-style extension logic.

3. **Primary proceeds are split with creator/poster participation**
   - Both fixed-price and auction claim flows include a 50% share to poster/creator address.

### What Is Different / Contradictory

1. **Who can trigger minting**
   - Notes: "Anyone can pay gas + initial auction amount to mint."
   - Current contracts: only `tdhSigner` can call `StreamDrops.mintDrop` (`authorized` modifier).

2. **Auction starting price policy**
   - Notes: start at `0.06529 ETH`.
   - Current contracts: starting price is arbitrary per drop (`_price`), no global minimum/default hardcoded to `0.06529 ETH`.

3. **Auction extension end condition**
   - Notes: extensions for 24h after initial 24h, then hard stop at 48h.
   - Current contracts: extension triggers whenever bid is near end time; no explicit 48h hard cap is enforced.

4. **Revenue split target**
   - Notes: "as with Meme Cards, primary and secondary proceeds are 50:50 to creator."
   - Current contracts:
     - Primary flow is `50% poster + 25% payout + 25% curators`.
     - Secondary royalties are configured in `StreamCore` as a fixed `6.9%` default royalty to a fixed address, not an on-chain 50:50 split to creator.

5. **1/1 positioning vs collection design**
   - Notes emphasize 1/1 Stream NFTs.
   - Current contracts support multi-token collections and multi-quantity mint calls; 1/1 is possible by configuration but not enforced as a protocol rule.

### What Exists In Contracts But Is Not In The Notes

1. **Fixed-price (non-auction) mint path**
   - `StreamDrops` supports direct fixed-price minting (`_opt == 1`) in addition to auctions.

2. **Curators pool claim mechanism**
   - `StreamCuratorsPool` has merkle-proof reward claims and explicit curators share wiring in mint/auction proceeds.

3. **Function-level admin matrix**
   - `StreamAdmins` supports both global admin permissions and per-function selector permissions.

4. **Dependency registry + on-chain script assembly**
   - `StreamCore` integrates dependency script retrieval/composition for on-chain generative metadata paths.

### What Is Missing From Contracts Relative To Notes

1. **No on-chain Main Stage submission model**
   - The "single place for submissions" process is not represented in current contracts.

2. **No on-chain TDH vote threshold gates (Track 1 / Track 2)**
   - There is no contract logic checking global TDH % thresholds, average voting windows, or spot voting windows.

3. **No explicit "10% for 2 hours" time-sensitive gate**
   - The described time-sensitive path is not encoded on-chain.

4. **No TDH accrual cap engine**
   - The proposed monthly cap/gradient logic tied to The Memes TDH issuance is not implemented in these contracts.

5. **No explicit recipient parameter/signature-binding flow in drop execution**
   - Current implementation does not encode an EIP-712 style signed payload that binds recipient/terms as described in a trust-minimized "anyone can execute" model.
