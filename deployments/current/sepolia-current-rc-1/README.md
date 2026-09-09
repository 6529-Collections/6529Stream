# Sepolia current-stack RC candidate

This directory retains the corrected candidate's exact deployment compilation.
Deployment and the complete live demonstration are pending. It is not yet a
frozen release or evidence of a successful testnet launch.

The [compilation manifest](compilation/manifest.json) binds 63 exported files
to one Solidity `0.8.19+commit.7dd6d404` input with global via-IR and 200 optimizer
runs. Its compiler-input SHA-256 is
`a6b5de40106999537691ef53997de24d61e8800bea3d1d35820494f214e63c72`.
The complete input includes the deployment script and all selected production
contracts and linked libraries, with no test sources. Export and independent
readback match the actual deployment build.

The largest selected runtime is the governance Executor at 24,545 bytes. Core
is 18,997 bytes. Compilation correspondence and runtime-size checks do not
constitute an external audit.

The [earlier prototype](../sepolia-2026-09-09/README.md) predates the final
entropy subject-kind correction. Its source, deployment and verification
records remain separate historical evidence.

See the [supported product guide](../../../docs/current-stack.md) and
[deployment instructions](../../../script/current/README.md) for behavior,
commands and the remaining full-v1 scope.
