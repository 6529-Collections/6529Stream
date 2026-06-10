# Slither Baseline

This is the tracked high/medium Slither baseline for 6529Stream. It is a triage
input, not an accepted security baseline.

## Capture Metadata

| Field | Value |
| --- | --- |
| Status | Open baseline; not accepted as a CI gate |
| Last generated | `2026-06-10 19:03 UTC` |
| Slither | `0.11.5` |
| Solidity compiler | `0.8.19` |
| solc-select | `1.2.0` |
| Command | `slither . --config-file slither.config.json --foundry-compile-all --json <temp-file>` |
| Raw JSON | Not committed; regenerate locally when needed |

Slither returned detector results successfully, but the process exited non-zero
because findings exist. That is expected until the roadmap accepts a gated
baseline.

## Impact Counts

| Impact | Count |
| --- | ---: |
| High | 4 |
| Medium | 28 |
| Low | 63 |
| Informational | 575 |
| Optimization | 6 |
| Total | 676 |

## Detector Counts

| Detector | Impact | Count |
| --- | --- | ---: |
| `encode-packed-collision` | High | 0 |
| `incorrect-exp` | High | 1 |
| `suicidal` | High | 3 |
| `uninitialized-state` | High | 0 |
| `weak-prng` | High | 0 |
| `divide-before-multiply` | Medium | 9 |
| `incorrect-equality` | Medium | 1 |
| `locked-ether` | Medium | 7 |
| `uninitialized-local` | Medium | 10 |
| `unused-return` | Medium | 1 |
| Low-impact findings | Low | 63 |
| Informational findings | Informational | 575 |
| Optimization findings | Optimization | 6 |

Dependency-script encoding delta from the previous tracked capture:

- High findings decreased from 9 to 8 because the final
  `encode-packed-collision` row is fixed.
- Medium findings decreased from 29 to 28 because
  `StreamCore.retrieveDependencyScript(uint256).scripttext` is now initialized.
- `encode-packed-collision` is now zero current findings; the remaining fixed
  rows are kept below as audit traceability.
- `uninitialized-local` is now 10 current findings; the
  `StreamDrops.mintDrop` and `StreamCore.retrieveDependencyScript` rows are
  fixed, while the broader `P0-INIT-001` workstream remains open.
- Mint-accounting state delta from the previous tracked capture:
  - High findings decreased from 8 to 6 because the two dead
    `uninitialized-state` mint-accounting mappings were removed.
  - Informational findings decreased from 580 to 577 because the removed
    storage and retrieval surface no longer appears in lower-impact detectors.
  - `uninitialized-state` is now zero current findings; the fixed rows are
    kept below as audit traceability.
- Weak-helper randomness delta from the previous tracked capture:
  - High findings decreased from 6 to 4 because the concrete production-source
    `XRandoms` helper contract was removed.
  - Informational findings decreased from 577 to 575 because the removed helper
    source no longer appears in lower-impact detectors.
  - `weak-prng` is now zero current findings; the fixed rows are kept below as
    audit traceability.
- `arbitrary-send-eth` and `reentrancy-eth` remain at zero findings.
- Slither still exits non-zero because the remaining tracked baseline findings
  require fixes, accepted-risk rationale, or false-positive proof before audit
  readiness.

## Status Semantics

| Status | Meaning |
| --- | --- |
| `Open` | Production-impacting finding that still needs a fix, accepted-risk rationale, or false-positive proof |
| `Accepted` | Non-production or explicitly accepted finding with documented rationale |
| `False Positive` | Tool finding proven not to apply |
| `Fixed` | Finding removed by code change and covered by regression test |
| `Needs Issue` | Finding needs a dedicated issue before Gate F |

## High And Medium Findings

Every `Open` or `Needs Issue` row is blocking triage until it is fixed,
accepted with rationale, or proved false positive. Issue cells link the grouped
GitHub work item that owns that resolution.

| Detector | Occurrences | Contract | Function | Source kind | Source location | Severity | Confidence | Status | Resolution | Required test | Issue | Gate | Owner |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `arbitrary-send-eth` | 1 | `StreamAuctions` | `emergencyWithdraw()` | first-party | Fixed in `P0-AUCT-002` | High | Medium | Fixed | Bounded auction emergency withdrawal to auction-local surplus after bidder credits and active highest-bid escrow | `test/StreamAuctionPayments.t.sol` | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| `arbitrary-send-eth` | 1 | `NextGenRandomizerRNG` | `emergencyWithdraw()` | first-party | Fixed in `P0-PAY-007`/`P0-PAY-008` | High | Medium | Fixed | Treats all adapter ETH as randomness reserve, exposes zero emergency-withdrawable balance, and transfers no emergency-withdrawable ETH | `test/StreamEmergencyWithdraw.t.sol` | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| `arbitrary-send-eth` | 1 | `StreamCuratorsPool` | `emergencyWithdraw()` | first-party | Fixed in `P0-PAY-005` | High | Medium | Fixed | Bounded curator pool emergency withdrawal to surplus after local curator credits owed | `test/StreamCuratorsPool.t.sol` | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8), [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29) | Gate C | TBD |
| `arbitrary-send-eth` | 1 | `StreamMinter` | `emergencyWithdraw()` | first-party | Fixed in `P0-PAY-007`/`P0-PAY-008` | High | Medium | Fixed | Exposes `totalOwed() == 0` and withdraws only `emergencyWithdrawable()` surplus, covering forced ETH without an ordinary payable path | `test/StreamEmergencyWithdraw.t.sol` | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| `encode-packed-collision` | 1 | `StreamCore` | `retrieveDependencyScript(uint256)` | first-party | Fixed in `P0-META-001` | High | High | Fixed | Replaced packed dynamic dependency-script composition with initialized `string.concat` rendering and typed dependency chunk/content hash views that use `abi.encode`, dependency key, chunk count, chunk index, chunk byte length, and per-chunk content hash | Ambiguous chunk-boundary and typed hash regressions in `test/StreamMetadataEncoding.t.sol` | [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9) | Gate C | TBD |
| `encode-packed-collision` | 1 | `StreamDrops` | `retrieveMessageAndDropID(address,address,string,uint256,uint256,uint256,uint256)` | first-party | Removed in `P0-AUTH-002` | High | High | Fixed | Removed legacy packed helper; `hashDropAuthorization` now uses EIP-712 domain-separated typed data | Explicit digest, replay, wrong-domain, wrong-chain, wrong-contract, and field-substitution tests in `test/StreamDropsEIP712.t.sol` | [`P0-AUTH-002`](https://github.com/6529-Collections/6529Stream/issues/10) | Gate C | TBD |
| `encode-packed-collision` | 1 | `StreamDrops` | `mintDrop(address,address,string,uint256,uint256,uint256,uint256)` | first-party | Removed in `P0-AUTH-002` | High | High | Fixed | Replaced legacy packed-hash `mintDrop` ABI with `mintDrop(DropAuthorization,string,bytes)` and storage-backed consumed/cancelled drop IDs | EOA, EIP-2098, replay, expiry, cancellation, stale-epoch, wrong-domain, wrong-chain, wrong-contract, wrong-signer, malleability, zero signer, bad quantity, and token-substitution tests in `test/StreamDropsEIP712.t.sol` | [`P0-AUTH-002`](https://github.com/6529-Collections/6529Stream/issues/10) | Gate C | TBD |
| `incorrect-exp` | 1 | `Math` | `mulDiv(uint256,uint256,uint256)` | vendored | `smart-contracts/Math.sol#L55-L134` | High | Medium | Needs Issue | Likely false positive; confirm against pinned upstream OpenZeppelin or replace retained library with package-managed upstream before acceptance | Library provenance or math regression | [`P0-LIB-001`](https://github.com/6529-Collections/6529Stream/issues/11) | Gate F | TBD |
| `suicidal` | 3 | Forced-ETH test helpers | `force(address)` | test-only | `test/StreamAuctionPayments.t.sol`, `test/StreamCuratorsPool.t.sol`, `test/StreamFixedPricePayments.t.sol` | High | Medium | Accepted | Accepted as intentional Solidity 0.8.19 `selfdestruct` helpers used only to test forced-ETH surplus accounting | Forced-ETH tests in the owning files | Accepted test-only | Gate A | TBD |
| `reentrancy-eth` | 1 | `StreamAuctions` | `participateToAuction(uint256)` | first-party | Fixed in `P0-AUCT-002` | High | Medium | Fixed | Replaced synchronous outbid refund `call` with bidder credit accounting; highest-bid state and auction escrow accounting update before any external withdrawal path | `test/StreamAuctionPayments.t.sol` | [`P0-AUCT-002`](https://github.com/6529-Collections/6529Stream/issues/12) | Gate C | TBD |
| `uninitialized-state` | 1 | `StreamCore` | `state variable tokensMintedPerAddress` | first-party | Removed in `P0-CORE-001` | High | High | Fixed | Removed the never-written public-sale mint-count mapping and retrieval API instead of exposing an always-zero counter with no accepted quota semantics | Retained airdrop-counter regression in `test/StreamMintAccounting.t.sol` | [`P0-CORE-001`](https://github.com/6529-Collections/6529Stream/issues/13) | Gate C | TBD |
| `uninitialized-state` | 1 | `StreamCore` | `state variable tokensMintedAllowlistAddress` | first-party | Removed in `P0-CORE-001` | High | High | Fixed | Removed the never-written allowlist mint-count mapping and retrieval API because the current drop path has no allowlist phase semantics | Retained airdrop-counter regression in `test/StreamMintAccounting.t.sol` | [`P0-CORE-001`](https://github.com/6529-Collections/6529Stream/issues/13) | Gate C | TBD |
| `weak-prng` | 1 | `randomPool` | `randomNumber()` | first-party | Removed in `P0-RAND-008` | High | Medium | Fixed | Removed the concrete production-source `XRandoms` helper contract instead of shipping block-derived helper randomness alongside production randomizer adapters | `test/StreamRandomizerLifecycle.t.sol::testNxtRandomizerCannotBeConfiguredForProductionCollections` plus Slither `weak-prng=0` confirmation | [`P0-RAND-008`](https://github.com/6529-Collections/6529Stream/issues/73) | Gate C | TBD |
| `weak-prng` | 1 | `randomPool` | `randomWord()` | first-party | Removed in `P0-RAND-008` | High | Medium | Fixed | Removed the concrete production-source `XRandoms` helper contract instead of shipping block-derived helper randomness alongside production randomizer adapters | `test/StreamRandomizerLifecycle.t.sol::testNxtRandomizerCannotBeConfiguredForProductionCollections` plus Slither `weak-prng=0` confirmation | [`P0-RAND-008`](https://github.com/6529-Collections/6529Stream/issues/73) | Gate C | TBD |
| `divide-before-multiply` | 1 | `Base64` | `encode(bytes)` | vendored | `smart-contracts/Base64.sol#L20-L91` | Medium | Medium | Needs Issue | Likely false positive; confirm against pinned upstream OpenZeppelin or replace retained library with package-managed upstream before acceptance | Library provenance or precision regression | [`P0-LIB-001`](https://github.com/6529-Collections/6529Stream/issues/11) | Gate F | TBD |
| `divide-before-multiply` | 8 | `Math` | `mulDiv(uint256,uint256,uint256)` | vendored | `smart-contracts/Math.sol#L55-L134` | Medium | Medium | Needs Issue | Likely false positive; confirm against pinned upstream OpenZeppelin or replace retained library with package-managed upstream before acceptance | Library provenance or precision regression | [`P0-LIB-001`](https://github.com/6529-Collections/6529Stream/issues/11) | Gate F | TBD |
| `incorrect-equality` | 1 | `DropAuthTestHelper` | `signMalleableAuthorization(...)` | test-only | `test/helpers/DropAuthTestHelper.sol#L113-L123` | Medium | Medium | Accepted | Accepted as a test-only helper branch used to manufacture malleable signatures for negative authorization tests | `test/StreamDropsEIP712.t.sol` malleability tests | Accepted test-only | Gate A | TBD |
| `locked-ether` | 7 | Rejection/reentrancy/mock receivers | payable test helpers | test-only | `test/StreamAuctionPayments.t.sol`, `test/StreamCuratorsPool.t.sol`, `test/StreamEmergencyWithdraw.t.sol`, `test/StreamFixedPricePayments.t.sol`, `test/mocks/MockRandomizer.sol` | Medium | High | Accepted | Accepted as test-only receivers and mocks used to characterize failed transfers, reentrancy attempts, and randomizer provider payments | Payment and emergency-withdrawal tests in the owning files | Accepted test-only | Gate A | TBD |
| `uninitialized-local` | 1 | `Bytes32Strings` | `containsExactCharacterQty(...)._occurrences` | first-party | `smart-contracts/Bytes32Strings.sol#L46` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `Bytes32Strings` | `containsExactCharacterQty(...).i` | first-party | `smart-contracts/Bytes32Strings.sol#L47` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `registerDelegationAddressUsingSubDelegation(...).subdelegationRightsCol` | first-party | `smart-contracts/NFTdelegation.sol#L118` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `revokeDelegationAddressUsingSubdelegation(...).subdelegationRightsCol` | first-party | `smart-contracts/NFTdelegation.sol#L288` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `retrieveTokenStatus(...).status` | first-party | `smart-contracts/NFTdelegation.sol#L617` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `retrieveSubDelegationStatus(...).subdelegationRights` | first-party | `smart-contracts/NFTdelegation.sol#L650` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `retrieveStatusOfActiveDelegator(...).status` | first-party | `smart-contracts/NFTdelegation.sol#L677` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamCore` | `retrieveGenerativeScript(...).scripttext` | first-party | `smart-contracts/StreamCore.sol#L394` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamCore` | `retrieveDependencyScript(...).scripttext` | first-party | Fixed in `P0-META-001` | Medium | Medium | Fixed | Initialized the dependency-script accumulator to an empty string before concatenation and covered the rendered output through the metadata encoding regression suite | `test/StreamMetadataEncoding.t.sol` | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15), [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamDrops` | `mintDrop(...).tokenid` | first-party | Removed in `P0-AUTH-002` | Medium | Medium | Fixed | Rewritten typed authorization path initializes branch locals explicitly; captured Slither run no longer reports `StreamDrops.mintDrop` uninitialized locals | `make slither` targeted log check plus EIP-712 and characterization tests | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamMinter` | `mint(...).mintIndex` | first-party | `smart-contracts/StreamMinter.sol#L76` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `MockStreamMinter` | `mint(...).mintedCount` | test-only | `test/mocks/MockStreamMinter.sol#L71` | Medium | Medium | Accepted | Accepted as a test-only helper baseline | None; test-only baseline row | Accepted test-only | Gate A | TBD |
| `unused-return` | 1 | `StreamDropsERC1271Test` | `testValidContractSignatureMintsAndConsumesDropId()` | test-only | `test/StreamDropsERC1271.t.sol#L35-L61` | Medium | Medium | Accepted | Accepted as a test-only assertion helper pattern where tuple fields are intentionally ignored except the signer check | `test/StreamDropsERC1271.t.sol` | Accepted test-only | Gate A | TBD |

## Source-Level Suppressions

Source suppressions must stay narrow, include an adjacent code comment, and be
backed by a regression test or accepted-risk rationale.

| Detector | Scope | Status | Rationale | Required test | Issue | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| `reentrancy-eth`, `write-after-write` | `NextGenRandomizerRNG.requestRandomWords(uint256,uint256)` | Accepted scoped suppression | arRNG returns the provider request ID from an external payable call, so the adapter must record request state after that call. The function uses a local request-in-progress guard, fulfillment rejects during the guarded window, and the suppression is limited to this function. | `test/StreamRandomizerLifecycle.t.sol::testArrngControllerCannotReenterFulfillmentDuringRequest`; `test/StreamRandomizerLifecycle.t.sol::testArrngZeroRequestIdFailsBeforeRecordingLifecycle` | [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37) | TBD |

## Triage Rules

- Fix first-party high findings before any public beta claim.
- Convert each fixed finding into a regression test in the test matrix.
- Replace retained upstream libraries with pinned upstream packages or document
  provenance before accepting vendored library rows.
- Keep every `Needs Issue` row linked to a GitHub issue before accepting or
  suppressing it.
- Do not suppress a detector until the finding or scoped suppression is
  documented as `Fixed`, `Accepted`, or `False Positive`.
- Do not convert Slither into a CI gate until high and medium findings have a
  stable accepted baseline.
