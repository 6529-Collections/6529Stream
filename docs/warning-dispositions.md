# Warning Dispositions

This document is the checked `ONE-007` warning hygiene baseline for
6529Stream. It is a pre-audit local baseline, not production-ready, and not a
security claim. It exists so compiler warnings, NatSpec/documentation warnings,
Foundry linter warnings, and accepted warning dispositions are visible to
maintainers and reviewers before the repo claims public beta or production
readiness.

## Maturity And Scope

Warning hygiene is a release-review surface. A quiet build is easier to review,
but a warning-free local command is not proof of protocol correctness. The
current policy is:

- fix first-party warning noise when the fix is comment-only, test-only,
  behavior-preserving, and preferably ABI-neutral and bytecode-neutral; when
  compiler metadata or source hashes change, regenerate and review the release
  artifacts that prove the new bytecode hashes;
- do not change external ABI names, `stateMutability`, integration-facing
  marker functions, or Core bytecode shape merely to satisfy cosmetic warning
  suggestions without a measured size and compatibility review;
- document every retained warning with owner, reason, follow-up, and evidence;
- treat new first-party warning categories as fix-now unless maintainers add a
  reviewed disposition here.

The warning baseline complements [`docs/tooling.md`](tooling.md),
[`docs/audit-package.md`](audit-package.md),
[`docs/release-readiness.md`](release-readiness.md),
[`docs/status.md`](status.md), [`docs/slither.md`](slither.md),
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md), and
[`ops/EXECUTION_BACKLOG.md`](../ops/EXECUTION_BACKLOG.md). The generated
risk row for this work is retained in
[`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json).

## Current Warning Baseline

The current committed release gate still runs `forge build`,
`forge build --sizes --via-ir --skip test --skip script --force`,
`forge doc --build`, the scoped Solidity formatting checker, the release
manifest/checksum checks, and the warning disposition checker. The
warning-disposition checker also compares the retained `forge-size.log` output
against the accepted solc warning rows so new compiler warnings cannot silently
enter CI. As of this baseline:

| Category | Current disposition | Owner | Evidence |
| --- | --- | --- | --- |
| Invalid first-party NatSpec header tags | Fixed in this pass by replacing `@title:`, `@date:`, `@version:`, `@author:`, `@notes:`, and `@contributors:` with standard or `@custom:*` tags | oss | `python scripts/check_warning_dispositions.py` scans non-vendored Solidity headers |
| Solc unused-parameter warnings | Accepted local baseline where removing names would churn integration-facing ABI metadata or interface readability without security benefit | protocol | `forge build --sizes --via-ir --skip test --skip script --force` |
| Solc pure/view suggestions | Accepted ABI compatibility baseline because changing `view` to `pure` changes ABI `stateMutability` for externally consumed functions | protocol | ABI compatibility and release artifacts remain stable |
| Solc test-only `selfdestruct` deprecation warnings | Accepted test-only baseline for forced-ETH helpers that prove surplus and reserve accounting cannot be broken by direct ETH transfers | protocol | `forge build` and payment/randomizer tests |
| Foundry linter block-timestamp warnings | Accepted protocol baseline for deadline, auction, mint-window, and final-supply time checks that are tested and documented as time-window logic | security | Auction, mint, drop, and metadata tests plus ADRs |
| Vendored utility linter warnings | Accepted vendored/provenance baseline for retained math/delegation/provider sources | oss | [`docs/vendored-libraries.md`](vendored-libraries.md) and Slither baseline review |
| mdBook HTML warnings from Chainlink VRF prose | Accepted vendored documentation baseline; the comments contain placeholder angle-bracket examples and do not affect bytecode | oss | `forge doc --build` |

The current `StreamCore` production runtime size is recorded in
[`release-artifacts/latest/bytecode-release-proof.json`](../release-artifacts/latest/bytecode-release-proof.json)
and summarized in [`docs/status.md`](status.md). This warning baseline must not
be used to justify spending Core bytes casually. The satellite-first policy in
[`docs/architecture.md`](architecture.md) remains the default for future 1/1
product surfaces and large integration helpers.

## Fixed In This Pass

The following comment-only cleanup is intentionally safe:

- `NATSPEC-INVALID-FIRST-PARTY-HEADERS`: first-party and retained provenance
  contract headers now use standard NatSpec tags (`@title`, `@author`) or
  custom tags (`@custom:date`, `@custom:version`, `@custom:notes`,
  `@custom:contributors`) instead of invalid colon-suffixed tags.

Source files covered by this cleanup:

- [`smart-contracts/AuctionContract.sol`](../smart-contracts/AuctionContract.sol)
- [`smart-contracts/DependencyRegistry.sol`](../smart-contracts/DependencyRegistry.sol)
- [`smart-contracts/NFTdelegation.sol`](../smart-contracts/NFTdelegation.sol)
- [`smart-contracts/RandomizerNXT.sol`](../smart-contracts/RandomizerNXT.sol)
- [`smart-contracts/RandomizerRNG.sol`](../smart-contracts/RandomizerRNG.sol)
- [`smart-contracts/RandomizerVRF.sol`](../smart-contracts/RandomizerVRF.sol)
- [`smart-contracts/StreamAdmins.sol`](../smart-contracts/StreamAdmins.sol)
- [`smart-contracts/StreamCore.sol`](../smart-contracts/StreamCore.sol)
- [`smart-contracts/StreamCuratorsPool.sol`](../smart-contracts/StreamCuratorsPool.sol)
- [`smart-contracts/StreamDrops.sol`](../smart-contracts/StreamDrops.sol)
- [`smart-contracts/StreamMinter.sol`](../smart-contracts/StreamMinter.sol)

This changes source comments, compiler metadata/source hashes, and therefore
release bytecode-proof hashes. It does not change runtime bytecode size, ABI
function selectors, event topics, executable protocol logic, or storage layout.

## Accepted Solc Warning Dispositions

| ID | Detector | Source | Current warning | Disposition | Required follow-up |
| --- | --- | --- | --- | --- | --- |
| `SOLC-UNUSED-RANDOMIZER-SALT-NXT` | `unused-param` | [`smart-contracts/RandomizerNXT.sol`](../smart-contracts/RandomizerNXT.sol) `calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)` | `_saltfun_o` is intentionally unused by this legacy adapter | `accepted-abi-compatibility` because the adapter mirrors the shared randomizer interface and preserving names helps interface comparison | Revisit only in a focused randomizer-interface cleanup with ABI/artifact review |
| `SOLC-UNUSED-RANDOMIZER-SALT-RNG` | `unused-param` | [`smart-contracts/RandomizerRNG.sol`](../smart-contracts/RandomizerRNG.sol) `calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)` | `_saltfun_o` is intentionally unused by the current RNG adapter | `accepted-abi-compatibility` for interface consistency | Revisit only in a focused randomizer-interface cleanup with ABI/artifact review |
| `SOLC-UNUSED-RANDOMIZER-SALT-VRF` | `unused-param` | [`smart-contracts/RandomizerVRF.sol`](../smart-contracts/RandomizerVRF.sol) `calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)` | `_saltfun_o` is intentionally unused by the current VRF adapter | `accepted-abi-compatibility` for interface consistency | Revisit only in a focused randomizer-interface cleanup with ABI/artifact review |
| `SOLC-UNUSED-ROYALTY-TOKENID` | `unused-param` | [`smart-contracts/StreamCore.sol`](../smart-contracts/StreamCore.sol) `royaltyInfo(uint256 tokenId, uint256 salePrice)` | ERC-2981 royalty is token-agnostic, so `tokenId` is unused | `accepted-abi-compatibility` because keeping the ERC-2981 parameter name improves ABI clarity for integrators | Revisit only if royalty behavior changes through the royalty policy process |
| `SOLC-PURE-RANDOMIZER-NXT` | `pure-suggestion` | [`smart-contracts/RandomizerNXT.sol`](../smart-contracts/RandomizerNXT.sol) `isRandomizerContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-PURE-RANDOMIZER-RNG` | `pure-suggestion` | [`smart-contracts/RandomizerRNG.sol`](../smart-contracts/RandomizerRNG.sol) `isRandomizerContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-PURE-RANDOMIZER-VRF` | `pure-suggestion` | [`smart-contracts/RandomizerVRF.sol`](../smart-contracts/RandomizerVRF.sol) `isRandomizerContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-PURE-MINTER-MARKER` | `pure-suggestion` | [`smart-contracts/StreamMinter.sol`](../smart-contracts/StreamMinter.sol) `isMinterContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-PURE-ROYALTY` | `pure-suggestion` | [`smart-contracts/StreamCore.sol`](../smart-contracts/StreamCore.sol) `royaltyInfo(uint256 tokenId, uint256 salePrice)` | Fixed royalty math could be `pure` | `accepted-abi-compatibility` and `accepted-size-tradeoff`; the current ERC-2981 surface is stable and Core changes require measured bytecode review | Revisit only if the royalty policy or ABI baseline changes |
| `SOLC-TEST-SELFDESTRUCT-HELPERS` | `selfdestruct-deprecation` | [`test/StreamAuctionPayments.t.sol`](../test/StreamAuctionPayments.t.sol), [`test/StreamCuratorsPool.t.sol`](../test/StreamCuratorsPool.t.sol), [`test/StreamEmergencyWithdraw.t.sol`](../test/StreamEmergencyWithdraw.t.sol), [`test/StreamFixedPricePayments.t.sol`](../test/StreamFixedPricePayments.t.sol), [`test/StreamRandomizerPayments.t.sol`](../test/StreamRandomizerPayments.t.sol) | Forced-ETH helper contracts intentionally use `selfdestruct` under Solidity 0.8.19 | `accepted-test-only` because the helpers are excluded from the production size build and prove forced-balance accounting behavior | Replace only when the test suite adopts an equivalent deterministic forced-ETH primitive |

## Accepted Documentation And Linter Dispositions

| ID | Detector | Source | Current warning | Disposition | Required follow-up |
| --- | --- | --- | --- | --- | --- |
| `DOC-MDBOOK-VRF-HTML` | `mdbook-html` | [`smart-contracts/VRFConsumerBaseV2.sol`](../smart-contracts/VRFConsumerBaseV2.sol) | Placeholder prose contains `<other arguments>` and `<initialization with other arguments goes here>` examples | `accepted-vendored-prose` because this is retained Chainlink-style provider documentation and does not affect bytecode | Revisit only in a vendored-provider provenance cleanup |
| `LINT-VENDORED-SIGNEDMATH-TYPECAST` | `unsafe-typecast` | [`smart-contracts/SignedMath.sol`](../smart-contracts/SignedMath.sol) | Utility math cast warning | `accepted-vendored-provenance` because the source is retained utility code already covered by vendored-library policy | Revisit only with vendored-library provenance review |
| `LINT-VENDORED-MATH-SHIFT` | `incorrect-shift` | [`smart-contracts/Math.sol`](../smart-contracts/Math.sol) | Utility math shift-order warning | `accepted-vendored-provenance` because the source is retained utility code already covered by vendored-library policy | Revisit only with vendored-library provenance review |
| `LINT-BLOCK-TIMESTAMP-AUCTION` | `block-timestamp` | [`smart-contracts/AuctionContract.sol`](../smart-contracts/AuctionContract.sol) | Auction creation, bid, and settlement use block time | `accepted-protocol-time-window` because auction deadlines are explicit protocol state and covered by auction tests | Keep tests for early, active, late, no-bid, with-bid, and repeat-settlement paths |
| `LINT-BLOCK-TIMESTAMP-CORE` | `block-timestamp` | [`smart-contracts/StreamCore.sol`](../smart-contracts/StreamCore.sol) | Mint/final-supply/freeze windows use block time | `accepted-protocol-time-window` because collection windows and freeze delays are explicit protocol state | Keep tests for mint windows, final-supply tightening, and freeze timing |
| `LINT-BLOCK-TIMESTAMP-DROPS` | `block-timestamp` | [`smart-contracts/StreamDrops.sol`](../smart-contracts/StreamDrops.sol) | Drop execution uses block time | `accepted-protocol-time-window` because drop deadlines are part of EIP-712 authorization and replay safety | Keep expired and deadline-bound drop authorization tests |
| `LINT-BLOCK-TIMESTAMP-MINTER` | `block-timestamp` | [`smart-contracts/StreamMinter.sol`](../smart-contracts/StreamMinter.sol) | Minting path checks collection and drop time windows | `accepted-protocol-time-window` because time gates are required external behavior | Keep mint-window and drop-window regression tests |
| `LINT-BLOCK-TIMESTAMP-TEST-HELPER` | `block-timestamp` | [`test/helpers/ProtocolStateMachine.sol`](../test/helpers/ProtocolStateMachine.sol) | Stateful test helper compares block time | `accepted-test-only` because this code is not a production artifact | Keep production build skipping `test` and `script` paths |

## Size And ABI Policy

`StreamCore` has finite EIP-170 headroom even after recent refactors. Warning
fixes that alter production Solidity code must therefore be judged in this
order:

1. Security and correctness.
2. ABI and integration compatibility.
3. Runtime bytecode size and gas impact.
4. Warning quietness.

Changing an external function from `view` to `pure`, removing a parameter name
from a production ABI, or moving logic back into `StreamCore` is not a
housekeeping task. It requires the same evidence as other production contract
changes: focused tests, ABI compatibility checks, production size proof,
release artifact regeneration, and changelog coverage.

The next material Core headroom refactor should be a separate PR. The most
likely safe direction is to keep Core consensus-critical and move remaining
metadata string formatting or non-consensus lifecycle rendering work into
satellite/read-adapter contracts such as
[`smart-contracts/StreamMetadataRenderer.sol`](../smart-contracts/StreamMetadataRenderer.sol).

## Validation Commands

Run the warning disposition checks directly:

```sh
python scripts/test_warning_dispositions.py
python scripts/run_forge_size_log.py --log cache/forge-size.log
python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log
forge doc --build
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

Run `make warning-dispositions-check` for the focused local target.

## Maintenance

Update this file when any of the following changes:

- a new first-party solc warning appears;
- a new NatSpec, docs, mdBook, lint, Slither, or formatting warning category
  appears in release-oriented local or CI output;
- a previously accepted warning is fixed;
- a warning disposition changes owner, status, or follow-up;
- a Core-size or ABI compatibility tradeoff changes.

Every retained warning must remain one of: `fix-now`,
`accepted-abi-compatibility`, `accepted-size-tradeoff`,
`accepted-protocol-time-window`, `accepted-vendored-provenance`,
`accepted-vendored-prose`, or `accepted-test-only`.
