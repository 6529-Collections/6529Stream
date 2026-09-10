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

External-call gas limits remain a separate, open inventory in
[`ops/EXTERNAL_CALL_GAS_INVENTORY.json`](../ops/EXTERNAL_CALL_GAS_INVENTORY.json).
The ERC-20 sale adapter's asset-policy probe uses 30,000 gas; its payment-intent
verifier starts contract-signature checks at a locally governed, raise-only
400,000 gas. These two sites remain open under issue #669 because that local
setting does not implement the required factory-wide gas-parameter binding.
The warning dispositions below grant no exception to that remaining work.

## Current Warning Baseline

The current committed release gate still runs `forge build`, the diagnostic
`forge build --sizes --via-ir --skip test --skip script --force`,
`forge doc --build`, the scoped Solidity formatting checker, the canonical
target-isolated release builder, release manifest/checksum checks, and the
warning disposition checker. The warning-disposition checker compares the
retained aggregate `forge-size.log` output against the accepted solc warning
rows so new compiler warnings cannot silently enter CI. Foundry compilation
outputs for this forced diagnostic belong in the wrapper's isolated
`out-diagnostics` and `cache-diagnostics` directories; its retained log remains
`cache/forge-size.log` and does not replace ordinary compiler artifacts. Foundry compilation
restrictions can admit test helpers to that diagnostic despite its skip flags;
the log is therefore warning evidence, not production bytecode or source-input
evidence. The diagnostic wrapper accepts Forge's size exit only when the sole
negative runtime margin is the exact test-only `LegacyStreamCore` row at 24,587
bytes (`-11` margin); any production overage, second overage, helper-size drift,
compile failure, or other error still fails. Canonical target-isolated artifacts
and `check_contract_size_budget.py` remain the production size authorities. The
parser is tested against a captured
`forge build --sizes --via-ir --skip test --skip script --force` fixture from
Foundry v1.7.1 and Solidity 0.8.19, and it keys the accepted solc rows by
warning code, source file, and source excerpt. The state-export wrappers also
bind each diagnostic's reported line to its exact enclosing function and check
the complete forwarding body. Line numbers locate current source; they are not
permanent baseline identities. As of this baseline:

| Category | Current disposition | Owner | Evidence |
| --- | --- | --- | --- |
| Invalid first-party NatSpec header tags | Fixed in this pass by replacing `@title:`, `@date:`, `@version:`, `@author:`, `@notes:`, and `@contributors:` with standard or `@custom:*` tags | oss | `python -m tools.security.check_warning_dispositions` scans non-vendored Solidity headers |
| Solc unused-parameter warnings | Accepted local baseline where removing names would churn integration-facing ABI metadata or interface readability without security benefit | protocol | `forge build --sizes --via-ir --skip test --skip script --force` |
| Solc pure/view suggestions | Accepted ABI compatibility baseline because changing `view` to `pure` changes ABI `stateMutability` for externally consumed functions | protocol | ABI compatibility and release artifacts remain stable |
| Solc test-only `selfdestruct` deprecation warnings | Accepted test-only baseline for forced-ETH helpers that prove surplus and reserve accounting cannot be broken by direct ETH transfers | protocol | `forge build` and payment/randomizer tests |
| Foundry linter block-timestamp warnings | Accepted protocol baseline for deadline, auction, manager phase-window, mint-window, and final-supply time checks that are tested and documented as time-window logic | security | Auction, mint-manager, mint, drop, and metadata tests plus ADRs |
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

- [`smart-contracts/domains/auctions/legacy/AuctionContract.sol`](../smart-contracts/domains/auctions/legacy/AuctionContract.sol)
- [`smart-contracts/domains/dependencies/DependencyRegistry.sol`](../smart-contracts/domains/dependencies/DependencyRegistry.sol)
- [`smart-contracts/integrations/delegation/NFTdelegation.sol`](../smart-contracts/integrations/delegation/NFTdelegation.sol)
- [`smart-contracts/integrations/randomizers/legacy/RandomizerNXT.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerNXT.sol)
- [`smart-contracts/integrations/randomizers/legacy/RandomizerRNG.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerRNG.sol)
- [`smart-contracts/integrations/randomizers/legacy/RandomizerVRF.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerVRF.sol)
- [`smart-contracts/domains/access/StreamAdmins.sol`](../smart-contracts/domains/access/StreamAdmins.sol)
- [`smart-contracts/core/StreamCore.sol`](../smart-contracts/core/StreamCore.sol)
- [`smart-contracts/domains/revenue/StreamCuratorsPool.sol`](../smart-contracts/domains/revenue/StreamCuratorsPool.sol)
- [`smart-contracts/domains/mint/legacy/StreamDrops.sol`](../smart-contracts/domains/mint/legacy/StreamDrops.sol)
- [`smart-contracts/domains/mint/legacy/StreamMinter.sol`](../smart-contracts/domains/mint/legacy/StreamMinter.sol)
- [`smart-contracts/domains/mint/StreamMintManager.sol`](../smart-contracts/domains/mint/StreamMintManager.sol)

This changes source comments, compiler metadata/source hashes, and therefore
release bytecode-proof hashes. It does not change ABI function selectors, event
topics, or executable protocol logic for the otherwise unchanged contracts. In
the current CON-014 artifact refresh, `StreamCore` runtime/hash changes are
additionally attributable to the expanded imported `IStreamMintManager` source
and Core prepared-mint manager storage changes, including
`pendingPreparedMintManager`; Core's external ABI method identifiers remain
unchanged. `StreamPrimarySaleSettlement` has unchanged source, ABI method
identifiers, and storage layout; the regenerated proof refreshes the stale
prior via-IR release artifact baseline to the current compiled output.

## Accepted Solc Warning Dispositions

| ID | Detector | Source | Current warning | Disposition | Required follow-up |
| --- | --- | --- | --- | --- | --- |
| `SOLC-UNUSED-RANDOMIZER-SALT-NXT` | `unused-param` | [`smart-contracts/integrations/randomizers/legacy/RandomizerNXT.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerNXT.sol) `calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)` | `_saltfun_o` is intentionally unused by this legacy adapter | `accepted-abi-compatibility` because the adapter mirrors the shared randomizer interface and preserving names helps interface comparison | Revisit only in a focused randomizer-interface cleanup with ABI/artifact review |
| `SOLC-UNUSED-RANDOMIZER-SALT-RNG` | `unused-param` | [`smart-contracts/integrations/randomizers/legacy/RandomizerRNG.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerRNG.sol) `calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)` | `_saltfun_o` is intentionally unused by the current RNG adapter | `accepted-abi-compatibility` for interface consistency | Revisit only in a focused randomizer-interface cleanup with ABI/artifact review |
| `SOLC-UNUSED-RANDOMIZER-SALT-VRF` | `unused-param` | [`smart-contracts/integrations/randomizers/legacy/RandomizerVRF.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerVRF.sol) `calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)` | `_saltfun_o` is intentionally unused by the current VRF adapter | `accepted-abi-compatibility` for interface consistency | Revisit only in a focused randomizer-interface cleanup with ABI/artifact review |
| `SOLC-UNUSED-EXECUTOR-ENCODED-PAGE-RETURNS` | `unused-param` | [`smart-contracts/domains/governance/StreamGovernanceExecutor.sol`](../smart-contracts/domains/governance/StreamGovernanceExecutor.sol) `terminalFreezeActionPage` | Solc 5667 reports the three named return variables because memory-safe assembly forwards the encoded tuple directly | `accepted-abi-compatibility`; the protocol owner retains readable ABI output names and the existing bytecode-size optimization. [`StreamGovernanceBootstrap`](../smart-contracts/domains/governance/StreamGovernanceBootstrap.sol) returns `abi.encode(ids, deadlines, next)`, and the Executor returns its complete payload without decoding and re-encoding | Keep exact page membership, deadlines, cursor and bounds assertions in `testTerminalFreezeRawPaginationAndPermissionlessElapsedPruning` in [`test/unit/governance/StreamGovernanceExecutor.t.sol`](../test/unit/governance/StreamGovernanceExecutor.t.sol); reconsider the disposition if that forwarding implementation changes |
| `SOLC-UNUSED-EXECUTOR-STATE-EXPORT-FORWARDERS` | `unused-param` | `StreamGovernanceExecutor.latestStateExport`, `stateExport`, `publishStateExport`, `challengeStateExport`, `supersedeStateExport` | Solc 5667 reports named ABI arguments and returns used through raw calldata or an encoded tuple instead of Solidity variable references | `accepted-abi-compatibility`; the three writers forward complete `msg.data` with the real manifest and execution context to [`StreamStateExport`](../smart-contracts/domains/governance/StreamStateExport.sol), which dispatches exact selectors and decodes their typed arguments. The two readers return the complete encoded latest/record tuples through memory-safe assembly, retaining readable ABI names | Preserve the exact forwarding bodies and typed tuple encoders. [`test/current/StreamCurrentStateExport.t.sol`](../test/current/StreamCurrentStateExport.t.sol) asserts decoded empty/live records, exact receipts, role checks, governance-execution exclusion and immutable history |
| `SOLC-TEST-UNUSED-LEGACY-ROYALTY-TOKENID` | `unused-param` | [`test/regression/legacy/helpers/LegacyStreamCore.sol`](../test/regression/legacy/helpers/LegacyStreamCore.sol) `royaltyInfo(uint256 tokenId, uint256 salePrice)` | The retained transitional test helper is token-agnostic, so `tokenId` is unused | `accepted-test-only`; the permanent production Core forwards `tokenId` to the authenticated resolver and does not emit this warning | Remove with the legacy characterization helper |
| `SOLC-PURE-RANDOMIZER-NXT` | `pure-suggestion` | [`smart-contracts/integrations/randomizers/legacy/RandomizerNXT.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerNXT.sol) `isRandomizerContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-PURE-RANDOMIZER-RNG` | `pure-suggestion` | [`smart-contracts/integrations/randomizers/legacy/RandomizerRNG.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerRNG.sol) `isRandomizerContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-PURE-RANDOMIZER-VRF` | `pure-suggestion` | [`smart-contracts/integrations/randomizers/legacy/RandomizerVRF.sol`](../smart-contracts/integrations/randomizers/legacy/RandomizerVRF.sol) `isRandomizerContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-PURE-MINTER-MARKER` | `pure-suggestion` | [`smart-contracts/domains/mint/legacy/StreamMinter.sol`](../smart-contracts/domains/mint/legacy/StreamMinter.sol) `isMinterContract()` | Marker function could be `pure` | `accepted-abi-compatibility` because changing `view` to `pure` changes ABI `stateMutability` for no security gain | Revisit only in a coordinated interface version bump |
| `SOLC-TEST-PURE-LEGACY-ROYALTY` | `pure-suggestion` | [`test/regression/legacy/helpers/LegacyStreamCore.sol`](../test/regression/legacy/helpers/LegacyStreamCore.sol) `royaltyInfo(uint256 tokenId, uint256 salePrice)` | The retained transitional helper's fixed royalty math could be `pure` | `accepted-test-only`; the permanent production Core performs an authenticated external resolver read and cannot be pure | Remove with the legacy characterization helper |
| `SOLC-TEST-SELFDESTRUCT-HELPERS` | `selfdestruct-deprecation` | [`test/regression/legacy/auctions/StreamAuctionPayments.t.sol`](../test/regression/legacy/auctions/StreamAuctionPayments.t.sol), [`test/unit/revenue/StreamCuratorsPool.t.sol`](../test/unit/revenue/StreamCuratorsPool.t.sol), [`test/unit/protocol/StreamEmergencyWithdraw.t.sol`](../test/unit/protocol/StreamEmergencyWithdraw.t.sol), [`test/regression/legacy/mint/StreamFixedPricePayments.t.sol`](../test/regression/legacy/mint/StreamFixedPricePayments.t.sol), [`test/unit/entropy/StreamRandomizerPayments.t.sol`](../test/unit/entropy/StreamRandomizerPayments.t.sol) | Forced-ETH helper contracts intentionally use `selfdestruct` under Solidity 0.8.19 | `accepted-test-only` because their retained occurrence is aggregate diagnostic warning evidence and any such source is rejected from canonical release inputs | Replace only when the test suite adopts an equivalent deterministic forced-ETH primitive |

The 111-source current integration compile that introduced state exports
reported 19 physical warnings for these five new wrappers, represented by 18
function-scoped identities because both `stateExport` outputs share one source
line. Its existing terminal-page warning is separate. That focused compile
does not contain all legacy diagnostic targets and cannot replace the complete
aggregate warning gate. The earlier captured parser fixture remains unchanged
historical evidence; it does not attest the new state-export implementation.

## Accepted Documentation And Linter Dispositions

| ID | Detector | Source | Current warning | Disposition | Required follow-up |
| --- | --- | --- | --- | --- | --- |
| `DOC-MDBOOK-VRF-HTML` | `mdbook-html` | [`smart-contracts/vendor/chainlink/VRFConsumerBaseV2.sol`](../smart-contracts/vendor/chainlink/VRFConsumerBaseV2.sol) | Placeholder prose contains `<other arguments>` and `<initialization with other arguments goes here>` examples | `accepted-vendored-prose` because this is retained Chainlink-style provider documentation and does not affect bytecode | Revisit only in a vendored-provider provenance cleanup |
| `LINT-VENDORED-SIGNEDMATH-TYPECAST` | `unsafe-typecast` | [`smart-contracts/vendor/openzeppelin/SignedMath.sol`](../smart-contracts/vendor/openzeppelin/SignedMath.sol) | Utility math cast warning | `accepted-vendored-provenance` because the source is retained utility code already covered by vendored-library policy | Revisit only with vendored-library provenance review |
| `LINT-VENDORED-MATH-SHIFT` | `incorrect-shift` | [`smart-contracts/vendor/openzeppelin/Math.sol`](../smart-contracts/vendor/openzeppelin/Math.sol) | Utility math shift-order warning | `accepted-vendored-provenance` because the source is retained utility code already covered by vendored-library policy | Revisit only with vendored-library provenance review |
| `LINT-BLOCK-TIMESTAMP-AUCTION` | `block-timestamp` | [`smart-contracts/domains/auctions/legacy/AuctionContract.sol`](../smart-contracts/domains/auctions/legacy/AuctionContract.sol) | Auction creation, bid, and settlement use block time | `accepted-protocol-time-window` because auction deadlines are explicit protocol state and covered by auction tests | Keep tests for early, active, late, no-bid, with-bid, and repeat-settlement paths |
| `LINT-BLOCK-TIMESTAMP-DROPS` | `block-timestamp` | [`smart-contracts/domains/mint/legacy/StreamDrops.sol`](../smart-contracts/domains/mint/legacy/StreamDrops.sol) | Drop execution uses block time | `accepted-protocol-time-window` because drop deadlines are part of EIP-712 authorization and replay safety | Keep expired and deadline-bound drop authorization tests |
| `LINT-BLOCK-TIMESTAMP-MINTER` | `block-timestamp` | [`smart-contracts/domains/mint/legacy/StreamMinter.sol`](../smart-contracts/domains/mint/legacy/StreamMinter.sol) | Minting path checks collection and drop time windows | `accepted-protocol-time-window` because time gates are required external behavior | Keep mint-window and drop-window regression tests |
| `LINT-BLOCK-TIMESTAMP-MINT-MANAGER` | `block-timestamp` | [`smart-contracts/domains/mint/StreamMintManager.sol`](../smart-contracts/domains/mint/StreamMintManager.sol) | Manager phase execution checks configured start and end windows | `accepted-protocol-time-window` because phase windows are explicit launch policy state outside Core | Keep phase not-started, ended, pause, and executor regression tests |
| `LINT-BLOCK-TIMESTAMP-TEST-HELPER` | `block-timestamp` | [`test/helpers/ProtocolStateMachine.sol`](../test/helpers/ProtocolStateMachine.sol) | Stateful test helper compares block time | `accepted-test-only` because this code is not a production artifact | Keep canonical release validation rejecting `test` and `script` paths |
| `LINT-BLOCK-TIMESTAMP-FINALITY-REGISTRY` | `block-timestamp` | [`smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol`](../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol) | Terminal-freeze staging compares block time against the veto floor and open-to-execute window | `accepted-protocol-time-window` because the 72-hour veto floor and 7-day execution window are explicit [GOV-WINDOWS] wall-clock policy | Keep the freeze-machine window regression tests in `test/unit/finality/StreamArtworkFinalityFreeze.t.sol` |
| `LINT-BLOCK-TIMESTAMP-FINALITY-PREVIEW` | `block-timestamp` | [`smart-contracts/domains/finality/StreamArtworkFinalityPreview.sol`](../smart-contracts/domains/finality/StreamArtworkFinalityPreview.sol) | View-only preview mirrors the registry's staged-window comparison | `accepted-protocol-time-window` because the preview must report exactly the execution-time window state | Keep preview-parity tests in `test/unit/finality/StreamArtworkFinalityRegistry.t.sol` |

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
[`smart-contracts/domains/metadata/StreamMetadataRenderer.sol`](../smart-contracts/domains/metadata/StreamMetadataRenderer.sol).

## Validation Commands

Run the warning disposition checks directly:

```sh
python -m tools.security.test_warning_dispositions
python -m tools.build.run_forge_size_log --log cache/forge-size.log
python -m tools.security.check_warning_dispositions --solc-warnings-log cache/forge-size.log
forge doc --build
python -m tools.release.test_release_manifest
python -m tools.release.generate_release_manifest --check
python -m tools.release.test_release_checksums
python -m tools.release.generate_release_checksums --check
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
