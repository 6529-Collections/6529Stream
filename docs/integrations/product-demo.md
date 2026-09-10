# Run the current product scenarios locally

The scenario runner operates an existing current-stack deployment. It creates a
second collection through the actual governance Executor, accepts a distinct
artist, then demonstrates native and ERC-20 purchases, a two-bid English auction,
split withdrawals and state-export publication. Each stage keeps a transaction
journal so an interrupted run can resume.

Use a loopback Anvil endpoint on chain 31337 with unlocked public test accounts
and the explicitly labeled development entropy provider. The runner does not
create or reset a node, load keys or send Sepolia transactions. It requires
PowerShell 7, Foundry `cast`, Node.js and the built [Stream client](typescript-client.md).
Supply the `current-stack.json` from the local deployment runner; its retained
artifact directory supplies the matching contract ABIs and local test-token
bytecode. Production contracts are not recompiled by these scenarios.

```powershell
npm --prefix packages/stream-client run build

pwsh -NoProfile -File scripts/run-current-stack-scenarios.ps1 `
  -DeploymentState D:/local-stream/current-stack.json `
  -OutputDirectory D:/local-stream/product-demo `
  -RpcUrl http://127.0.0.1:8547 -Stage Status

pwsh -NoProfile -File scripts/run-current-stack-scenarios.ps1 `
  -DeploymentState D:/local-stream/current-stack.json `
  -OutputDirectory D:/local-stream/product-demo `
  -RpcUrl http://127.0.0.1:8547 -Stage All -Execute -AdvanceLocalTime
```

Use the same arguments with an individual `-Stage` to stop at a specific product:

| Stage | Actual operations and required readback |
| --- | --- |
| `Status` | Check local chain, deployment binding and actors; export public client addresses. |
| `Onboard` | Create a distinct immutable 90/10 split; govern collection creation, metadata, entropy, royalty, three mint phases, primary revenue assignment and publisher role; accept the artist nomination. |
| `Native` | Compare the client authorization digest with the adapter, obtain platform and artist signatures, buy for 0.000001 test ETH, finalize entropy and metadata, and withdraw both recipients' proceeds. |
| `ERC20` | Deploy the explicitly labeled standard-mode test token, govern asset admission and sale registration, approve the adapter, sign the sale and separate payer intent, relay a 1,000-unit purchase, finalize metadata and withdraw 900/100 units. |
| `Auction` | Sign and create an auction, finalize metadata, bid 0.000001 and 0.0000011 test ETH from distinct accounts, withdraw the first bidder's refund, settle after expiry, verify winner ownership and withdraw both splits. |
| `Export` | Capture collection ownership at a past canonical block, publish its commitment through the actual Executor and verify the emitted event and latest export. |
| `All` | Run the stages in the order above, reusing confirmed operations. |

Complete `Onboard` before the purchase or auction stages. `Onboard` and the first
`ERC20` configuration each use the normal 48-hour class-1 governance delay.
`-AdvanceLocalTime` explicitly mines the local chain forward to the scheduled
`notBefore` or auction end; it does not change a contract delay. Without that
switch, the runner stops after scheduling or bidding and can resume after the
recorded timestamp. Submitted governance actions retain their expiry and exact
payload; an expired action requires operator recovery rather than silent replacement.

The third unlocked account is the new artist, the fourth is the buyer and the
fifth is the second bidder. Override them with `-Artist`, `-Buyer` and
`-SecondBidder`. The artist must differ from the original controller and protocol
recipient. The original collection's accepted artist is checked on every run.
The new artist accepts directly; purchase and auction authorizations use the
client's canonical EIP-712 payloads, checked against the deployed digest methods,
then signed through local `eth_signTypedData_v4`. The ERC-20 payer separately
signs its bounded payment intent, allowing the controller to relay the purchase.

Keep the output directory. `scenario-state.json` binds the deployment file and
actors, records the internal address map, and stores each transaction's sender,
nonce, payload, gas limit, hash, receipt, raw RPC transaction and canonical block
header. Repeating a completed operation validates its original transaction and
does not send it again. If a send completed before its hash was saved, recovery
scans a bounded block range for that sender/nonce and requires the exact payload.
An unresolved pending send stops the runner; it never consumes a replacement
nonce. A directory lock prevents concurrent scenario processes. An unsubmitted
governance schedule may be refreshed if it falls below the live delay floor;
the original plan remains in the journal.

`client-config.json` contains only supported public client address aliases.
Signing request and typed-data files preserve the exact unsigned messages.
Each artwork has a decoded final metadata file, and the journal records its
entropy identity and exact Core metadata notification. The export snapshot is a
small ownership demonstration, **not a complete protocol reconstruction**; its
local URN is a commitment identifier, not a hosted retrieval endpoint.

The payment asset is `MockStreamPaymentToken`, not a public stablecoin. Entropy
is supplied by the local controller and does not demonstrate Chainlink service,
secure randomness or oracle billing. The protocol remains pre-audit; these are
runnable local product flows, not production-readiness evidence.

Run the offline helper regressions after building the client:

```powershell
pwsh -NoProfile -File scripts/test_current_stack_scenarios.ps1
```
