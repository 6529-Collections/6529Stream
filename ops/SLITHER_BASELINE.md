# Slither Baseline

This is the tracked high/medium Slither baseline for 6529Stream. It is a triage
input, not an accepted security baseline.

## Capture Metadata

| Field | Value |
| --- | --- |
| Status | Open baseline; not accepted as a CI gate |
| Last generated | `2026-06-10 01:24 UTC` |
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
| High | 13 |
| Medium | 26 |
| Low | 51 |
| Informational | 434 |
| Optimization | 6 |
| Total | 530 |

## Detector Counts

| Detector | Impact | Count |
| --- | --- | ---: |
| `arbitrary-send-eth` | High | 4 |
| `encode-packed-collision` | High | 3 |
| `incorrect-exp` | High | 1 |
| `reentrancy-eth` | High | 1 |
| `uninitialized-state` | High | 2 |
| `weak-prng` | High | 2 |
| `divide-before-multiply` | Medium | 9 |
| `locked-ether` | Medium | 1 |
| `uninitialized-local` | Medium | 12 |
| `unused-return` | Medium | 4 |
| Low-impact findings | Low | 51 |
| Informational findings | Informational | 434 |
| Optimization findings | Optimization | 6 |

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
| `arbitrary-send-eth` | 1 | `StreamAuctions` | `emergencyWithdraw()` | first-party | `smart-contracts/AuctionContract.sol#L147-L153` | High | Medium | Open | Replace emergency payout push with bounded owed/surplus accounting | Payment invariant and emergency withdrawal tests | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| `arbitrary-send-eth` | 1 | `NextGenRandomizerRNG` | `emergencyWithdraw()` | first-party | `smart-contracts/RandomizerRNG.sol#L78-L84` | High | Medium | Open | Replace emergency payout push with bounded owed/surplus accounting | Payment invariant and emergency withdrawal tests | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| `arbitrary-send-eth` | 1 | `StreamCuratorsPool` | `emergencyWithdraw()` | first-party | `smart-contracts/StreamCuratorsPool.sol#L84-L90` | High | Medium | Open | Replace emergency payout push with bounded owed/surplus accounting | Payment invariant and emergency withdrawal tests | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| `arbitrary-send-eth` | 1 | `StreamMinter` | `emergencyWithdraw()` | first-party | `smart-contracts/StreamMinter.sol#L124-L130` | High | Medium | Open | Replace emergency payout push with bounded owed/surplus accounting | Payment invariant and emergency withdrawal tests | [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| `encode-packed-collision` | 1 | `StreamCore` | `retrieveDependencyScript(uint256)` | first-party | `smart-contracts/StreamCore.sol#L402-L408` | High | High | Open | Use typed dependency chunk encoding, versioned content hashes, and frozen dependency pinning per ADR 0006 | Encoding collision and frozen dependency regression | [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9) | Gate C | TBD |
| `encode-packed-collision` | 1 | `StreamDrops` | `retrieveMessageAndDropID(address,address,string,uint256,uint256,uint256,uint256)` | first-party | Removed in `P0-AUTH-002` | High | High | Fixed | Removed legacy packed helper; `hashDropAuthorization` now uses EIP-712 domain-separated typed data | Explicit digest, replay, wrong-domain, wrong-chain, wrong-contract, and field-substitution tests in `test/StreamDropsEIP712.t.sol` | [`P0-AUTH-002`](https://github.com/6529-Collections/6529Stream/issues/10) | Gate C | TBD |
| `encode-packed-collision` | 1 | `StreamDrops` | `mintDrop(address,address,string,uint256,uint256,uint256,uint256)` | first-party | Removed in `P0-AUTH-002` | High | High | Fixed | Replaced legacy packed-hash `mintDrop` ABI with `mintDrop(DropAuthorization,string,bytes)` and storage-backed consumed/cancelled drop IDs | EOA, EIP-2098, replay, expiry, cancellation, stale-epoch, wrong-domain, wrong-chain, wrong-contract, wrong-signer, malleability, zero signer, bad quantity, and token-substitution tests in `test/StreamDropsEIP712.t.sol` | [`P0-AUTH-002`](https://github.com/6529-Collections/6529Stream/issues/10) | Gate C | TBD |
| `incorrect-exp` | 1 | `Math` | `mulDiv(uint256,uint256,uint256)` | vendored | `smart-contracts/Math.sol#L55-L134` | High | Medium | Needs Issue | Likely false positive; confirm against pinned upstream OpenZeppelin or replace retained library with package-managed upstream before acceptance | Library provenance or math regression | [`P0-LIB-001`](https://github.com/6529-Collections/6529Stream/issues/11) | Gate F | TBD |
| `reentrancy-eth` | 1 | `StreamAuctions` | `participateToAuction(uint256)` | first-party | `smart-contracts/AuctionContract.sol#L64-L88` | High | Medium | Open | Move bidding to pull credits and state-before-external-call flow | Malicious bidder regression | [`P0-AUCT-002`](https://github.com/6529-Collections/6529Stream/issues/12) | Gate C | TBD |
| `uninitialized-state` | 1 | `StreamCore` | `state variable tokensMintedPerAddress` | first-party | `smart-contracts/StreamCore.sol#L74` | High | High | Open | Initialize, remove, or complete mint-accounting design | Mint-accounting regression | [`P0-CORE-001`](https://github.com/6529-Collections/6529Stream/issues/13) | Gate C | TBD |
| `uninitialized-state` | 1 | `StreamCore` | `state variable tokensMintedAllowlistAddress` | first-party | `smart-contracts/StreamCore.sol#L77` | High | High | Open | Initialize, remove, or complete mint-accounting design | Mint-accounting regression | [`P0-CORE-001`](https://github.com/6529-Collections/6529Stream/issues/13) | Gate C | TBD |
| `weak-prng` | 1 | `randomPool` | `randomNumber()` | first-party | `smart-contracts/XRandoms.sol#L32-L35` | High | Medium | Open | ADR 0005 requires removal, test/demo scoping, or production-disablement before Gate C | Randomness provider regression and production-scope test | [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14) | Gate C | TBD |
| `weak-prng` | 1 | `randomPool` | `randomWord()` | first-party | `smart-contracts/XRandoms.sol#L37-L40` | High | Medium | Open | ADR 0005 requires removal, test/demo scoping, or production-disablement before Gate C | Randomness provider regression and production-scope test | [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14) | Gate C | TBD |
| `divide-before-multiply` | 1 | `Base64` | `encode(bytes)` | vendored | `smart-contracts/Base64.sol#L20-L91` | Medium | Medium | Needs Issue | Likely false positive; confirm against pinned upstream OpenZeppelin or replace retained library with package-managed upstream before acceptance | Library provenance or precision regression | [`P0-LIB-001`](https://github.com/6529-Collections/6529Stream/issues/11) | Gate F | TBD |
| `divide-before-multiply` | 8 | `Math` | `mulDiv(uint256,uint256,uint256)` | vendored | `smart-contracts/Math.sol#L55-L134` | Medium | Medium | Needs Issue | Likely false positive; confirm against pinned upstream OpenZeppelin or replace retained library with package-managed upstream before acceptance | Library provenance or precision regression | [`P0-LIB-001`](https://github.com/6529-Collections/6529Stream/issues/11) | Gate F | TBD |
| `locked-ether` | 1 | `RejectETH` | `receive()` | test-only | `test/mocks/MockRandomizer.sol#L34-L38` | Medium | High | Accepted | Accepted as a test-only receiver used to characterize failing ETH transfers | None; test-only baseline row | Accepted test-only | Gate A | TBD |
| `uninitialized-local` | 1 | `Bytes32Strings` | `containsExactCharacterQty(...)._occurrences` | first-party | `smart-contracts/Bytes32Strings.sol#L46` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `Bytes32Strings` | `containsExactCharacterQty(...).i` | first-party | `smart-contracts/Bytes32Strings.sol#L47` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `registerDelegationAddressUsingSubDelegation(...).subdelegationRightsCol` | first-party | `smart-contracts/NFTdelegation.sol#L118` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `revokeDelegationAddressUsingSubdelegation(...).subdelegationRightsCol` | first-party | `smart-contracts/NFTdelegation.sol#L288` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `retrieveTokenStatus(...).status` | first-party | `smart-contracts/NFTdelegation.sol#L617` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `retrieveSubDelegationStatus(...).subdelegationRights` | first-party | `smart-contracts/NFTdelegation.sol#L650` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `DelegationManagementContract` | `retrieveStatusOfActiveDelegator(...).status` | first-party | `smart-contracts/NFTdelegation.sol#L677` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamCore` | `retrieveGenerativeScript(...).scripttext` | first-party | `smart-contracts/StreamCore.sol#L394` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamCore` | `retrieveDependencyScript(...).scripttext` | first-party | `smart-contracts/StreamCore.sol#L403` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamDrops` | `mintDrop(...).tokenid` | first-party | Removed in `P0-AUTH-002` | Medium | Medium | Fixed | Rewritten typed authorization path initializes branch locals explicitly; captured Slither run no longer reports `StreamDrops.mintDrop` uninitialized locals | `make slither` targeted log check plus EIP-712 and characterization tests | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `StreamMinter` | `mint(...).mintIndex` | first-party | `smart-contracts/StreamMinter.sol#L76` | Medium | Medium | Open | Initialize local before use or prove Solidity zero-value intent with tests/docs | Targeted regression for affected function | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| `uninitialized-local` | 1 | `MockStreamMinter` | `mint(...).mintedCount` | test-only | `test/mocks/MockStreamMinter.sol#L71` | Medium | Medium | Accepted | Accepted as a test-only helper baseline | None; test-only baseline row | Accepted test-only | Gate A | TBD |
| `unused-return` | 1 | `StreamDropsCharacterizationTest` | `testAuctionDropMintsCurrentCustodyToPayoutAndStoresPosterPrice()` | test-only | `test/StreamDropsCharacterization.t.sol#L135-L156` | Medium | Medium | Accepted | Accepted as a test-only characterization call where return value is intentionally ignored | None; test-only baseline row | Accepted test-only | Gate A | TBD |
| `unused-return` | 1 | `StreamDropsCharacterizationTest` | `testFixedPriceDropRecordsExplicitRecipientAndExecutionAddress()` | test-only | `test/StreamDropsCharacterization.t.sol#L58-L86` | Medium | Medium | Accepted | Accepted as a test-only characterization call where return value is intentionally ignored | None; test-only baseline row | Accepted test-only | Gate A | TBD |
| `unused-return` | 1 | `StreamDropsIntegrationCharacterizationTest` | `testAuctionDropCurrentlyMintsCustodyToPayoutAndRecordsAuctionState()` | test-only | `test/StreamDropsIntegrationCharacterization.t.sol#L109-L130` | Medium | Medium | Accepted | Accepted as a test-only characterization call where return value is intentionally ignored | None; test-only baseline row | Accepted test-only | Gate A | TBD |
| `unused-return` | 1 | `StreamDropsIntegrationCharacterizationTest` | `testFixedPriceDropPaysSynchronouslyAndMintsToExplicitRecipient()` | test-only | `test/StreamDropsIntegrationCharacterization.t.sol#L23-L42` | Medium | Medium | Accepted | Accepted as a test-only characterization call where return value is intentionally ignored | None; test-only baseline row | Accepted test-only | Gate A | TBD |

## Triage Rules

- Fix first-party high findings before any public beta claim.
- Convert each fixed finding into a regression test in the test matrix.
- Replace retained upstream libraries with pinned upstream packages or document
  provenance before accepting vendored library rows.
- Keep every `Needs Issue` row linked to a GitHub issue before accepting or
  suppressing it.
- Do not suppress a detector until a row is `Fixed`, `Accepted`, or
  `False Positive`.
- Do not convert Slither into a CI gate until high and medium findings have a
  stable accepted baseline.
