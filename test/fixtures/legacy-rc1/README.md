# Historical RC1 companion contracts

The legacy regression tests exercise `LegacyStreamCore`, its old administration
model and historical deployment rehearsals. Their companion mint and revenue
contracts are retained here from `testnet/current-rc-1`, commit
`569bf87f1fa808787d324f6e1582924b5ccf1d40`. They must not silently acquire the
current system's canonical governance or modular artist requirements.

Only the 13 files that changed, or that must import those changed files, are
copied. Their names have a `LegacyRC1` prefix (`ILegacyRC1` for interfaces), so
Foundry produces unambiguous artifacts. Historical entrypoints import aliases to
retain their test code. The remaining 133 dependencies are shared and pinned.

`provenance.json` records original and transformed byte hashes, the exact type
renames and import rewrites. Strings, signature domains, events, errors and
executable logic are preserved. Different type names, source paths and library
links can change compiler output: these are source-equivalent historical
fixtures, not bytecode-identical RC1 deployment artifacts. Reproduce the published
deployment from its retained tag and compiler evidence.

Run the provenance check without downloading history:

```powershell
python -m tools.development.check_legacy_snapshot
```

The checker reverses the declared transforms and verifies the original hashes.
The full repository check runs it alongside the Solidity source-layout checks.
It rejects companion imports into unpinned or evolving current implementations.
If a shared dependency changes, review whether to extend this historical
frontier or intentionally update the regression. Do not relax its hash checks
merely to make a current feature compile.

These fixtures are not current deployment dependencies. Current behavior belongs
in `test/current` against the actual current topology. The historical gas
snapshot remains historical; it does not establish current gas acceptance.
