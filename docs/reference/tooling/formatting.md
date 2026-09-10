# Formatting reference

This is detailed maintainer reference. Start everyday work with the
[developer commands](../../tooling.md); run aggregate release validation only when
preparing the corresponding evidence. Commands below run from the repository root.

## Solidity Formatting

The canonical formatting gate is:

```bash
make fmt-check
```

`make fmt-check` runs `tools/build/test_solidity_formatting.py` and
`tools/build/check_solidity_formatting.py`. The checker enforces a scoped policy:

- formatting-required non-exempt Solidity files must pass `forge fmt --check`;
- the raw all-files diagnostic `forge fmt --check smart-contracts` may fail
  only for the 17 explicit vendored/provenance exemptions listed in the
  checker;
- any new unformatted Solidity file outside that exemption set fails the gate;
- if an exempt file becomes formatted, the checker fails until the exemption
  list and provenance docs are updated.

The current exemption set is intentionally limited to OpenZeppelin-style
vendored utilities and legacy ERC interfaces with retained provenance notes in
[`vendored-libraries.md`](../../vendored-libraries.md). The first-party interfaces
`INextGenCore2.sol`, `IStreamDrops.sol`, and `IStreamMinter.sol`, plus the
arRNG/VRF provider and legacy delegation integration files `ArrngConsumer.sol`,
`IArrngConsumer.sol`, `IArrngController.sol`,
`IDelegationManagementContract.sol`, `IRandomizer.sol`,
`VRFConsumerBaseV2.sol`, and `VRFCoordinatorV2Interface.sol`, are formatted and
enforced by the scoped gate. Do not mechanically reformat exempt vendored files
in feature PRs. Change the exemption set only in focused provenance PRs that
also update release source-verification expectations when applicable.

Windows contributors can run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

The Windows script prepends `%USERPROFILE%\.foundry\bin` to the current process
`PATH` so a fresh shell can find `forge` after bootstrap. It also routes
`forge` and the selected Python interpreter through checked native-command
wrappers so Windows PowerShell 5.1 fails fast when a tool exits non-zero; this
behavior is covered by `tools/development/test_windows_check_wrapper.py` and the
executable harness in `scripts/test_windows_check_helpers.ps1`. The dedicated
Windows CI release-builder test uses `cmd.exe` only to merge Python's stdout and
unittest stderr before `Tee-Object`; PowerShell still captures and propagates
the resulting native exit code.

To run only the executable Windows wrapper harness:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test_windows_check_helpers.ps1
```

On systems with PowerShell Core installed as `pwsh`, the same harness is also
available through:

```bash
make windows-check-wrapper-runtime
```

CI runs the harness twice: once in the Linux Foundry job under PowerShell Core,
and once in the `windows-latest` job under Windows PowerShell so native-command
exit handling is covered in the environment that motivated the wrapper. That
Windows job independently installs the exact pinned Python, Foundry and Solc
toolchain and runs the complete release-builder authority suite. The workflow
wiring and its third isolated CI toolchain group are protected by
`tools/development/test_windows_ci_wrapper.py` and `tools/development/check_python_toolchain.py`.


## Warning Dispositions

The warning disposition gate is:

```bash
make warning-dispositions-check
```

It runs:

```bash
python -m tools.security.test_warning_dispositions
python -m tools.build.run_forge_size_log --log cache/forge-size.log
python -m tools.security.check_warning_dispositions --solc-warnings-log cache/forge-size.log
```

[`warning-dispositions.md`](../../warning-dispositions.md) is the checked `ONE-007`
baseline for compiler, NatSpec, documentation, linter, vendored, test-only,
ABI-compatibility, and `StreamCore` size-tradeoff warning decisions. The
checker verifies that invalid first-party NatSpec header tags are gone, that
accepted solc warnings remain anchored to the exact current source signatures,
and that retained warning rows name an owner, disposition class, and follow-up.
The live warning parser is pinned to the current Foundry v1.7.1 / Solidity
0.8.19 output shape with a captured forge-size fixture, and the checked solc
identity is warning code plus source file plus source excerpt rather than raw
line number.

Do not change external ABI names, function `stateMutability`, or Core bytecode
shape only to quiet cosmetic warning suggestions. Any such change needs the
normal production evidence: focused tests, ABI compatibility checks, production
size proof, release artifact regeneration, and changelog coverage.
