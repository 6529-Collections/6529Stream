# Current-stack development deployment

`DeployCurrentStack.s.sol` deploys the current Core, governance, canonical module
registry, mint manager and ledger, signed native sale, English auction, accepted
artist registry, entropy coordinator, metadata router, royalty resolver, and
immutable split wallet. It commits one genesis plan, prepares its catalog in a
separate transaction, then atomically activates and seals the stack. It freezes the
SystemManifest pointer, and publishes an explicitly labeled development manifest.
These module metadata hashes describe development configurations. They are not
release checksums, audit evidence, or a frozen release candidate.

The deployment uses Solidity 0.8.19, optimizer 200 runs, and **global via-IR**, the
same instance profile as the current-stack integration test. The script's deployer
is the bootstrap authority and controller of each separate governance actor.
Manager, ledger, sale, auction, asset policy, and royalty control belongs to the
governance executor after setup. The governance catalog includes operational
controls, root and role rotation, and module-status updates with their action
classes. Governance actors are simple development/testnet controllers.

## Local Anvil

Provide an existing Anvil node on chain 31337. The helper uses only loopback RPC
and Anvil's standard public unlocked accounts; it neither starts a daemon nor
reads a private key.

```powershell
pwsh -NoProfile -File scripts/run-current-stack.ps1 -RpcUrl http://127.0.0.1:8547
```

The helper deploys, accepts collection attribution, signs an exact fixed-price
sale through Anvil's EIP-712 RPC, pays 0.01 ETH, requests and completes development
entropy, exports final onchain metadata and artwork, releases both split shares,
and transfers the NFT. Public addresses and receipts are saved to
`$env:TEMP/6529stream-current-local/current-stack.json`. Use `-DeployOnly` to stop
after deployment or `-OutputDirectory` to choose an artifact directory.

`DevelopmentEntropyProvider` accepts controller-supplied values. **These are not
secure randomness.** Its constructor rejects every chain except 31337. The local
mode never presents this provider as Chainlink VRF.

For deployment simulation without an RPC endpoint:

```powershell
$env:STREAM_DEPLOYER = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
$env:STREAM_PROTOCOL_TREASURY = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8'
forge script script/current/DeployCurrentStack.s.sol:DeployCurrentStack --via-ir --isolate --skip test --sender $env:STREAM_DEPLOYER
```

The current offline isolated simulation uses 10,966,570 gas for preparation and
12,683,466 for activation plus sealing, including transaction intrinsic gas.
These are simulation measurements, not RPC receipts. Re-estimate against the
intended chain and final configuration before broadcasting.

## Sepolia

The script permits Sepolia chain 11155111 and deploys the actual subscription-
funded `StreamEntropyProviderVRF` adapter. It requires explicit public VRF
configuration; no upstream coordinator, key hash, or subscription is invented.

| Environment variable | Meaning |
| --- | --- |
| `STREAM_DEPLOYER` | Broadcast sender and initial governance actor controller |
| `STREAM_PROTOCOL_TREASURY` | Protocol split account; defaults to deployer |
| `STREAM_ARTIST` | Initial nominated artist; defaults to deployer |
| `STREAM_PLATFORM_SIGNER` | Sale authorization signer; defaults to deployer |
| `STREAM_VRF_COORDINATOR` | Actual Sepolia VRF v2.5 coordinator |
| `STREAM_VRF_SUBSCRIPTION_ID` | Existing subscription identifier |
| `STREAM_VRF_KEY_HASH` | Selected upstream key hash |
| `STREAM_VRF_CONFIRMATIONS` | Confirmations; defaults to 3 |
| `STREAM_VRF_CALLBACK_GAS` | Adapter callback gas; defaults to 1,500,000 |
| `STREAM_VRF_MAX_CALLBACK_GAS` | Configured upstream limit; defaults to 2,500,000 |
| `STREAM_VRF_NATIVE_PAYMENT` | Native subscription billing; defaults to true |

Use an existing secure Foundry signer and the intended RPC endpoint:

```powershell
forge script script/current/DeployCurrentStack.s.sol:DeployCurrentStack --via-ir --isolate --skip test --rpc-url $env:SEPOLIA_RPC_URL --sender $env:STREAM_DEPLOYER --account stream-deployer --broadcast --slow
```

The adapter must be added as a consumer of the supplied subscription, and that
subscription must be funded before requesting entropy. This script does not
claim those external Chainlink operations are complete. Actor funding and
transaction costs also remain the broadcaster's responsibility.

When `STREAM_ARTIST` equals the deployer, the script accepts the nomination in a
separate post-genesis transaction. Otherwise the nominated artist must call
`acceptArtist` or provide its EIP-712 acceptance signature before any sale or
auction can mint. The deployment returns addresses and leaves standard Foundry
broadcast receipts under `broadcast/DeployCurrentStack.s.sol/<chainId>/`.

### Dedicated Sepolia account workflow

`scripts/run-current-stack-sepolia.ps1` uses public account metadata and encrypted
keystores under `$env:USERPROFILE/.codex/stream-testnet/`. Password records remain
protected by Windows DPAPI. Signing uses a temporary password file restricted to
the current Windows identity and SYSTEM, removed in `finally`; password values
never enter child-process arguments.
The helper never exports a private key or saves signatures in its public report.
Use PowerShell 7. Its default invocation performs live reads only:

```powershell
pwsh -NoProfile -File scripts/run-current-stack-sepolia.ps1 -Stage Preflight
```

It verifies the actual coordinator and proving key, reads recent base fees and
the deployer balance, and calculates a full-flow budget before allowing any
transaction. The expected fee budget includes a modest reserve; the per-call
maximum fee remains a separate bound. The default demo mint price is 0.000001
Sepolia ETH, and the requested native subscription deposit is 0.005 Sepolia ETH.
`-MaxFeePerGasWei`, `-PriorityFeeWei`, `-SubscriptionFundingWei`, and `-MintPriceWei`
allow explicit public operating values. None is a signing secret.

After funding, run these stages in order with `-Broadcast`:

| Stage | Result |
| --- | --- |
| `Subscription` | Creates the subscription, reads its actual receipt ID, funds it, verifies ownership and native balance |
| `Deploy` | Runs the real VRF stack simulation, checks every gas limit, checkpoints the exact plan, deploys, and saves public addresses and receipts |
| `ResumeDeploy` | Resumes the checkpointed Forge transaction sequence, charging the estimate only for outstanding transactions; recovers a completed run without signing |
| `Activate` | Registers the adapter as a consumer and relays the artist's signed acceptance |
| `Mint` | Makes the low-price signed purchase and submits a real VRF request |
| `Readback` | Reads provider delivery, final metadata, royalties, subscription state, and live runtime code hashes; no `-Broadcast` needed |
| `Settle` | After final metadata, releases both shares and transfers the token to the artist |

If the paid mint succeeds but the request does not, `RequestEntropy` resumes from
the recorded token. Each confirmed transaction is retained immediately in
`$env:TEMP/6529stream-current-sepolia/state.json`, without raw signing arguments.
For an interrupted Forge deployment, retain its standard broadcast files and use
`ResumeDeploy` on the same source commit. The helper verifies each recorded
transaction's sender, nonce, target, value, and calldata hash. A fresh `Deploy`
is blocked by an existing attempt or broadcast file. If the broadcast file is
missing, recover the receipts before continuing. Only one process should own the
dedicated deployer's nonce sequence.

Subscription IDs incorporate a block hash. The live helper therefore waits for
the actual `SubscriptionCreated` receipt before constructing deployment calldata.
It never uses a subscription ID predicted by a script simulation.

`RehearseSepoliaCurrentStack.s.sol` separately tests deployment against the real
coordinator on a pinned fork. It grants simulated ETH, creates and funds a fork
subscription, deploys the stack, adds the consumer, and verifies the readbacks.
It does not forge a VRF response or claim an oracle fulfillment. Run it with a
Sepolia `--fork-url` and `--fork-block-number`, `--via-ir --isolate`, and the three
public `STREAM_DEPLOYER`, `STREAM_ARTIST`, and `STREAM_PLATFORM_SIGNER` values.
This rehearsal entry point is for dry runs only; use `DeployCurrentStack` through
the helper for a real broadcast.

Coordinator and key parameters come from the
[Chainlink Sepolia network configuration](https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia-testnet).
The helper checks the deployed coordinator's `s_config` and `s_provingKeys` before
use: 3 confirmations, 1,500,000 callback gas, a 2,500,000 upstream maximum, and
native subscription billing.

The complete fork rehearsal at Sepolia block 11670719 includes 48 transactions
and all linked libraries: 100,267,574 estimated execution gas before the demo.
Its largest transaction gas limit at the helper's 120% multiplier is 16,175,894,
below Sepolia's 16,777,216 cap. These are simulation measurements, not live
receipts. Each real deployment is simulated again against its actual subscription.

Run the helper's offline receipt/recovery regression checks with:

```powershell
pwsh -NoProfile -File scripts/test_current_stack_sepolia.ps1
```
