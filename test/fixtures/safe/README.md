# Official Safe test fixtures

These are test-only creation/runtime bytecodes from the official published Safe
packages, not a Safe reimplementation. The fixtures cover 1.3.0, 1.4.1 and 1.5.0.
Each JSON pins the source release commit, package URL, SHA-512 package integrity,
artifact path and bytecode SHA-256. Corresponding upstream licenses are retained.
The source URLs identify the exact upstream source trees.

Each version includes its singleton, proxy factory, CompatibilityFallbackHandler,
MultiSendCallOnly and SignMessageLib. Tests deploy the original creation code,
verify the resulting runtime, and initialize actual proxies through the factory.
No fork, RPC, package installation or secondary Solidity compiler is required.
The root Solidity compiler remains 0.8.19; Safe bytecodes retain their upstream
builds rather than being recompiled with Stream's compiler settings. The retained
package build information identifies Solidity 0.7.6 with optimizer disabled for
the singleton artifacts in these three versions.

Reproduce the files from integrity-pinned upstream packages with:

```text
python -m tools.development.fetch_safe_test_fixtures
```

Ordinary tests read the checked-in fixtures offline. The generator downloads
only fixed official package tarballs, verifies their pinned integrity, and reads
selected members in memory without executing scripts or extracting tar paths.

The [helper](../../helpers/OfficialSafeFixture.sol) builds sorted threshold
signatures and actual Safe transactions. For ERC-1271 approval of a Stream
digest, owners sign Safe's `SafeMessage(bytes)` wrapper over that digest. An
owner signature directly over the Stream digest is intentionally a negative
test. Empty signatures work only after a real Safe message approval.

The [foundation tests](../../unit/revenue/StreamOfficialSafe.t.sol) exercise
real threshold signatures, transaction caller/value, native split-wallet claims,
threshold changes and a nested 1.4.1 signature. The nested measurement cools
storage in an existing transaction; it is not an all-cold transaction benchmark.
These tests do not establish every Stream workflow or arbitrary Safe version,
threshold, nesting depth, guard or handler configuration. The remaining actual
integration evidence is tracked in [Safe acceptance](../../../ops/SAFE_ACCEPTANCE.md).

All signing keys in tests are public deterministic fixtures with no real funds.
Existing Safe owners, configurations and custody wallets are never modified.
