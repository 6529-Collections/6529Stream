# Developer entry points

Use the same Python command on Windows, macOS and Linux:

```sh
python scripts/dev.py doctor
python scripts/dev.py build
python scripts/dev.py test
python scripts/dev.py docs
```

The default build and tests select the supported current stack. Add a Forge
filter for focused work, or select a wider suite explicitly:

```sh
python scripts/dev.py test --match-contract StreamCurrentStackTest
python scripts/dev.py test --suite unit --match-path 'test/unit/entropy/*.t.sol'
python scripts/dev.py test --suite legacy
python scripts/dev.py test --suite all
```

`check` adds source layout, formatting and Core ABI compatibility checks.
`release` runs the full gate, including historical regression and release
evidence. `clean` clears compiler output and cache while preserving broadcast
receipts and deployment records. Run `--help` for command details.

| Entry point | Purpose |
| --- | --- |
| `dev.py` | Portable day-to-day development commands; callable from any working directory |
| `bootstrap-windows.ps1`, `bootstrap-ec2.sh` | Explicit tool installation for the documented hosts |
| `run-current-stack.ps1` | Demonstrate the current stack on local Anvil |
| `run-current-stack-sepolia.ps1` | Testnet deployment runner; use the deployment guide and dedicated signer |
| `check.ps1`, `check.sh` | Platform implementations of the complete validation gate |
| `windows-check-helpers.ps1` | Native command exit-code propagation for Windows checks |

The Python checkers, generators and their tests live in domain packages under
[tools/](../tools/README.md). Foundry deployment and rehearsal contracts live
in [script/](../script/README.md). See [tooling](../docs/tooling.md) for optional
dependencies, focused checks and release artifact generation order.
