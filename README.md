# 6529Stream

6529Stream is a set of Solidity smart contracts for 6529 NFT drops, including
fixed-price minting, auction flows, curator rewards, metadata generation, and
randomness adapters.

## Status

This repository is pre-audit and not production-ready.

The current CI and local smoke checks prove only that the contracts compile and
that the Foundry test command executes. They do not prove protocol correctness.
Known P0 blockers and the execution roadmap are tracked in
[`ops/ROADMAP.md`](ops/ROADMAP.md).

## Drop Flow

1. TDH holders provide reputation to drops.
2. If a drop clears the selected network hurdle, it enters a pool.
3. Once a drop is in a pool, addresses that meet TDH signer requirements can
   sign a minting transaction.
4. Once signer requirements are met, the NFT can be minted through fixed-price
   purchase or sent to auction.

## Quickstart

Install Foundry `v1.7.1`, then run:

```bash
make check
```

The canonical smoke check runs:

```bash
forge build
forge test -vvv
```

On Windows, install Python 3.8+ or the `py` launcher, then bootstrap and verify
with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

On Linux or EC2, bootstrap and verify with:

```bash
bash scripts/bootstrap-ec2.sh
make check
```

## Tooling

Tool versions and non-gating diagnostic commands are documented in
[`docs/tooling.md`](docs/tooling.md). The current Slither high/medium baseline
is tracked in [`ops/SLITHER_BASELINE.md`](ops/SLITHER_BASELINE.md).

Current pinned versions:

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Slither | `0.11.5` |

## Repository Layout

| Path | Purpose |
| --- | --- |
| `smart-contracts/` | Solidity source |
| `test/` | Foundry tests |
| `script/` | Foundry scripts |
| `docs/` | Project, security, ADR, and operational docs |
| `ops/` | Roadmap and execution state |

## Important Docs

- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)
- [`ops/ROADMAP.md`](ops/ROADMAP.md)
- [`ops/SLITHER_BASELINE.md`](ops/SLITHER_BASELINE.md)
- [`ops/AUTONOMOUS_RUN.md`](ops/AUTONOMOUS_RUN.md)
- [`docs/status.md`](docs/status.md)
- [`docs/known-blockers.md`](docs/known-blockers.md)
- [`docs/tooling.md`](docs/tooling.md)
- [`docs/slither.md`](docs/slither.md)
