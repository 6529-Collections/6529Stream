# Current-stack Sepolia instance: 9 September 2026

This directory retains the exact compilation used for the current-stack
Sepolia deployment. All 45 deployment transactions succeeded and the first
paid mint created token 1. The real randomness request is waiting for
Chainlink's subscription reserve; the final demonstration report follows
after the callback, withdrawals and transfer complete.

[Sourcify verification](source-verification.json) records creation and runtime
matches for all 30 named deployed contracts and libraries, including the split
wallet. Each entry links to the public provider result. Raw SSTORE2 data
contracts are covered by the separate public bytecode verification report.

[Pinned wiring observations](wiring-observations.json) record 138 public reads
at Sepolia block 11,671,023: 130 asserted reads and five cross-checks passed.
They check Core's authority words, installed pointers, module links, mint
policies, accepted attribution, splits, royalties and VRF settings. The root
actor and both veto-guardian actors are controlled by the dedicated deployer
in this test instance; the other fifteen governance roles are unassigned.
This is a development authority setup, not a production signer ceremony.

The [compilation manifest](compilation/manifest.json) binds the complete
Solidity 0.8.19 compiler input and selected contract/interface/library outputs.
It uses global via-IR, optimizer 200 runs, Paris, and no CBOR metadata suffix.
The selected Executor runtime is 24,545 bytes, below the 24,576-byte limit.

These files come from the deployment script's actual compilation unit, which
excludes tests and unrelated rehearsal entry points. A regular `current`
profile build includes its integration tests and can produce a different
compiler input. Keep routine exports in `release-artifacts/current`; retain
the actual instance compilation here.

Re-export or verify this snapshot only from the retained deployment output:

```sh
python scripts/generate_current_stack_artifacts.py --foundry-out <deployment-output> --output-dir deployments/current/sepolia-2026-09-09/compilation --check
```

This compilation snapshot alone does not attest to deployed addresses,
constructor values, runtime immutables, successful transactions, or an audit.
Public deployment verification and actual transaction receipts provide those
observations separately.
