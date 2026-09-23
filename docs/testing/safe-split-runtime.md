# Split-wallet deployment through threshold Safes

The focused [StreamSplitWalletSafeDeploymentTest](../../test/unit/revenue/StreamSplitWalletSafeDeployment.t.sol) exercises the actual
`StreamSplitFactory.deployWallet(bytes32)` and the actual clone's
`StreamSplitWallet.initialize(...)` boundary through upstream Safe 1.3.0, 1.4.1
and 1.5.0. Each Safe has three deterministic fixture owners and requires two
real owner signatures. This is local execution evidence for these named paths.

The factory, wallet implementation, CREATE2 clone, asset policy registry and
linked revenue libraries are the production contracts. The constructor authority
is `MockGovernedParameterAuthority`; the optional revenue runtime registry is
unbound. This suite does not establish governance admission, the full current
system, a bound runtime registry, cold gas capacity or release readiness.

## Cases and expected boundaries

Each of the three version-specific test cases exercises this sequence:

| Call | Protocol outcome | Safe outcome | Nonce |
| --- | --- | --- | --- |
| Deploy a registered profile | Creates and initializes the predicted clone | `true`, `ExecutionSuccess` | 0 to 1 |
| Deploy the same profile again | Returns the same wallet without another deployment | `true`, `ExecutionSuccess` | 1 to 2 |
| Deploy an unknown profile, `safeTxGas = 0` | `UnknownProfile(profileId)` | Reverts; no execution receipt | 2 to 2 |
| Same unknown profile, `safeTxGas = 100000` | `UnknownProfile(profileId)` | Returns `false`, `ExecutionFailure` | 2 to 3 |
| Direct clone initialization | `UnauthorizedInitializer(safe)` | Reverts; no execution receipt | 3 to 3 |
| Repeat the same initialization | Same caller-first refusal | Same revert, transaction hash and signed envelope | 3 to 3 |

For the zero-gas estimation path, Safe 1.3.0 and 1.4.1 wrap the target failure as
`Error("GS013")`; Safe 1.5.0 bubbles the exact target error. The test checks those
bytes explicitly. All three versions roll back the Safe nonce on this path.

Every Safe transaction uses `CALL`, zero value and zero refund payment. The
suite checks the installed singleton and compatibility handler, owner list,
threshold and version. Receipt assertions accommodate the transaction hash in
Safe 1.3.0 event data and its indexed position in Safe 1.4.1 and 1.5.0.

The first clone receives 12,345 wei before deployment. Its exact 52-byte runtime,
implementation binding, factory, profile, metadata, entry, aggregate shares,
balance and untouched release accounting are checked after deployment and each
initializer refusal. The deployment event includes the exact version, schema,
creation-code hash and runtime-code hash.

An owner EOA cannot initialize the clone either. Both that owner and an unrelated
EOA can deploy fresh registered profiles because `deployWallet` is permissionless.
These are explicit `vm.prank` caller controls, not EOA signature tests. The extra
direct unknown-profile oracle is a test-contract call, not a Safe invocation.

The initialized production clone is the target of the direct initialization
negatives. A Safe cannot reach the factory-only `AlreadyInitialized` branch:
the caller guard runs first. Existing factory-context and uninitialized-clone
unit cases in [StreamSplitWalletClones](../../test/unit/revenue/StreamSplitWalletClones.t.sol)
and [StreamSplitWallet](../../test/unit/revenue/StreamSplitWallet.t.sol) retain
that separate coverage.

## Retained run

The retained local run on 22 September 2026 passed all three exact ABI test
cases at source `3c16b6b96724d25d3307165db5c5c2ac1ed3c99c`, with no skipped
cases, integrity errors or compiler attempts during execution. The original
native capture for that source selected seven outputs from a 22-source closure and completed
its native pass in 38.119 seconds. It used Solidity 0.8.19, Paris, via IR,
optimizer 200, no CBOR/hash metadata and the current profile's documented
fixture limits. Only the canonical test-directory overlay changed
`test/current` to `test`; the complete current graph was not compiled.

The canonical `run_native_execution_view.py` runner executed cached artifacts
at verbosity 4 and chain ID 31337. Its retained physical cache profile is
`default`; the effective execution profile is `current`. Independent review
checked all 18 Safe attempts, nine caller controls, nine factory deployment
events, three first-Safe factory-origin initialization calls and 519 wallet
getter observations. The per-call record includes exact calldata, trace node
indices, Safe envelopes, recovered owners, EIP-712 hashes, receipts and nonce
reads. `vm.prank` controls distinguish their effective caller from Forge's raw
test-host trace caller.

The packet `safe-split-runtime` is retained outside Git with the integrator
handoff. These hashes identify its original results and reviewed call maps;
the large compiler and trace outputs are intentionally not repository files.

| Packet file | SHA-256 |
| --- | --- |
| `native-v2/source-plan.json` | `846434565edad9991449cbf51dc10e75401fb0d821c70a02667d06979c1b49a7` |
| `native-v2/native-cohort/part-000/record.json` | `1ddfa87a572b8277ea2f2c70b6f5c24990595d9480299e99c75a7ad214d0904a` |
| `prepared-v2/view/execution-view.json` | `d1a7bcdc24bd71ec2adf166b61e6805c6add79784944708e57c04d1d21a7a96a` |
| `execute-v2/result.json` | `e8eb459d42326bfb27d1efc0520812c277d09af4c288823978be9e3c11a965c9` |
| `execute-v2/host-000/stdout` | `41750a20221b751be3b5c35a95278a5e1921e5fd7bebee5d276a41ad6dae15ed` |
| `per-call-evidence.json` | `be48fa295e2d719dc06aedb09c1e0fe650e52f93cf705bc88b10bcaf9fcbb7f4` |
| `independent-call-review.json` | `3b19d7effdd8d5a94c20da02c1ffd31779f755a213aebbb39b579fd3f1ba84c7` |
| `deployment-review.json` | `267ab2c5735f2464e6370d1385f6bc721c9097efa6fa1ea30134e936e6c00e2b` |

The separate deployment review matched all 15 production CREATE operations and
nine split CREATE2 operations against the exact native bytes across the three
cases. It checked linked library addresses, library self-address words and every
production immutable against its expected constructor value. The factory's
13,288-byte full initcode includes all 768 bytes of dynamic constructor arguments;
each clone uses the exact 62-byte initcode and 52-byte runtime. These production
creations fit the ordinary size limits; only the test host uses a fixture size
allowance. The official Safe components remain the pinned upstream fixtures
checked by `OfficialSafeFixture`, not newly compiled Stream contracts.

The original execution at source `874866dc3d650bde3bf32bb9aefda871d8690589`
passed 1.3.0 and 1.4.1 but failed the test's assumed `GS013` wrapper for 1.5.0.
Its retained trace shows the correct `UnknownProfile` returned by the factory
and bubbled unchanged through the 1.5.0 Safe. The successor source
`3c16b6b96724d25d3307165db5c5c2ac1ed3c99c` corrects that test oracle; no
production contract change was needed.

This narrow run does not change the historical
[ABI176 all-call inventory](../../packages/stream-client/docs/safe-acceptance.md). Its
counts and entry identifiers remain bound to their original source capture;
this newer test source needs an explicit source binding before evidence can be
carried into a later complete inventory.
