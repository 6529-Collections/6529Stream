# Operate a second artist's collection locally

The product scenario runner uses an existing current-stack deployment and a
separate transaction journal. It creates another collection through the actual
governance Executor, with a distinct accepted artist, immutable split profile,
native/ERC-20/auction mint phases, metadata, entropy and royalty settings. The
original collection and its recorded deployment evidence remain available.

This runner accepts only a loopback Anvil endpoint on chain 31337, with unlocked
public test accounts and the explicitly labeled development entropy provider.
It does not create or reset an Anvil node, load keys, or send Sepolia transactions.
PowerShell 7 and the existing Foundry `cast` executable are required. Supply the
`current-stack.json` created by the local deployment runner; its matching raw
artifact directory provides the actual contract ABIs.

```powershell
pwsh -NoProfile -File scripts/run-current-stack-scenarios.ps1 `
  -DeploymentState D:/local-stream/current-stack.json `
  -OutputDirectory D:/local-stream/product-demo `
  -RpcUrl http://127.0.0.1:8547 -Stage Status

pwsh -NoProfile -File scripts/run-current-stack-scenarios.ps1 `
  -DeploymentState D:/local-stream/current-stack.json `
  -OutputDirectory D:/local-stream/product-demo `
  -RpcUrl http://127.0.0.1:8547 -Stage Onboard -Execute -AdvanceLocalTime
```

`Status` validates the selected local deployment and writes a public client
configuration. `Onboard` creates a second split, publishes exact governance
calldata, schedules a class-1 action and executes it after the normal 48-hour
delay. `-AdvanceLocalTime` explicitly mines the local chain forward to that
action's `notBefore`; it does not weaken a contract delay. Omit the switch to
stop after scheduling, and rerun the same stage once the action is ready.

By default, the third unlocked account is the new artist, the fourth is the
buyer and the fifth is the second bidder. Override these with `-Artist`,
`-Buyer` and `-SecondBidder`. All must be unlocked local accounts. The new artist
accepts its nomination directly in its own transaction. The platform signer,
governance controller and protocol recipient retain the original deployment's
configured roles.

Keep the output directory for subsequent runs. `scenario-state.json` binds the
deployment file and actors and records each transaction's sender, nonce,
payload, gas limit, hash and receipt. Repeating a completed step validates its
original transaction and does not send it again. If a send completed before
its hash was saved, recovery scans a bounded block range for that sender/nonce
and requires the exact payload. An unresolved pending send stops the runner;
it never silently consumes a replacement nonce. The directory lock prevents
two scenario processes from sharing the journal at once.

`client-config.json` uses the client package's public address names. It contains
no RPC credentials or wallet material. Governance proposal history preserves
any unsubmitted schedule that had to be refreshed because it fell below the
live delay floor. Already-submitted actions and transaction payloads remain
fixed.

Run the offline helper regressions with:

```powershell
pwsh -NoProfile -File scripts/test_current_stack_scenarios.ps1
```
