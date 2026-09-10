# Deployment and rehearsal scripts

Start with [the current stack demo](current/README.md). It deploys permanent Core,
governance, registry and product modules, seals genesis, then exercises paid
minting, entropy, metadata, split withdrawals and transfer on local Anvil.

```text
anvil --port 8547 --chain-id 31337
```

In another shell at the repository root:

```powershell
pwsh -NoProfile -File scripts/run-current-stack.ps1 -RpcUrl http://127.0.0.1:8547
```

The helper uses Anvil's public unlocked accounts on loopback. Its local provider is
explicitly insecure development randomness. For configured Sepolia/VRF and signer
requirements read the [current guide](current/README.md); the local example is not
a production deployment recipe.

| Directory | Purpose |
| --- | --- |
| `current/` | Current deployment, exact genesis plans and development-only helpers |
| `legacy/` | Historical deployment, auction ceremony, browser and emergency rehearsals |

Legacy rehearsals remain regression/evidence tools. They use an earlier Core and
satellite arrangement; their addresses, constructors and authorization schemas do
not apply to permanent Core. See [historical architecture](../docs/reference/legacy-stack/architecture.md).

Compiler profile, linked libraries and creation bytecode determine deployment
identity. Keep each broadcast paired with its exact compiler export; simulation
alone is not a receipt. Keep secrets out of committed evidence. Follow
[deployment records](../deployments/README.md), [tooling](../docs/tooling.md) and
[release readiness](../docs/release-readiness.md).
