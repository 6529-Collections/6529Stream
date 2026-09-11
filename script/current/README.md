# Current-stack development deployment

The full-v1 integration branch is migrating this workflow to the modular artist
suite and version-2 native/auction authorizations. Deployment now returns a
scheduled authority-activation batch; it does not yet complete artist onboarding,
phase consent or the Manager ownership handoff. See
[current artist activation](../../docs/integrations/current-artist-activation.md).
The PowerShell recipes and measurements below describe the retained RC1 workflow
until their migration and a fresh complete rehearsal pass. Use the frozen RC1
checkout to reproduce that evidence.

`DeployCurrentStack.s.sol` deploys the current Core, governance, canonical module
registry, mint manager and ledger, signed native sale, English auction, accepted
artist registry, entropy coordinator, metadata router, royalty resolver, and
immutable split wallet. It commits one genesis plan, prepares its catalog in a
separate transaction, then atomically activates and seals the stack. It freezes the
SystemManifest pointer, and publishes an explicitly labeled development manifest.
These module metadata hashes describe development configurations. They are not
release checksums, audit evidence, or a frozen release candidate.

The deployment uses `FOUNDRY_PROFILE=current`, Solidity 0.8.19, optimizer 200 runs, and **global via-IR**, the
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

Start Anvil in a separate terminal with the normal transaction gas cap enabled:

```powershell
anvil --host 127.0.0.1 --port 8547 --chain-id 31337 --gas-limit 30000000 --enable-tx-gas-limit --quiet
```

```powershell
pwsh -NoProfile -File scripts/run-current-stack.ps1 -RpcUrl http://127.0.0.1:8547
```

The helper deploys, accepts collection attribution, signs an exact fixed-price
sale through Anvil's EIP-712 RPC, pays 0.01 ETH, requests and completes development
entropy, exports final onchain metadata and artwork, releases both split shares,
and transfers the NFT. Public addresses and receipts are saved to
`$env:TEMP/6529stream-current-local/current-stack.json`. Use `-DeployOnly` to stop
after deployment or `-OutputDirectory` to choose a fresh evidence directory.
Compilation, cache, and broadcast outputs default to separate subdirectories of
that directory; all three can be supplied explicitly. An existing deployment
checkpoint, unsigned plan or broadcast file blocks an accidental fresh deployment. Keep a failed
run for diagnosis and use a fresh directory for a new local deployment.

Before writing a deployment checkpoint or broadcasting, the local runner simulates
the complete plan with the same Forge arguments, checks every transaction against
the 16,777,216 gas cap, and verifies the source commit, sender, chain and sequential
nonces. Sepolia also checks its complete unsigned plan before signing. A late
over-cap transaction therefore stops the whole deployment before its first
transaction. The error identifies the transaction, limit and selected
`-DeploymentGasEstimateMultiplier`; review any lower multiplier explicitly and
rerun. Neither runner reduces limits or disables the cap automatically. Simulation
is a preflight observation: another transaction or state change before broadcast
can still invalidate it. Preserve partial receipts if a later broadcast fails;
Sepolia's `ResumeDeploy` retains its existing checkpoint and nonce checks.

The helper checks the accepted artist, decodes the token and entropy request from
their own receipts, and requires the callback to be mined after the request. It
asserts a nonzero final seed, stored and delivered provider result, Core's
`MetadataUpdate` event, no pending metadata notification, both 90/10 withdrawals,
and the NFT's final owner. `-DemonstrateOnly` completes a previously successful
`-DeployOnly` run; it rejects an already attempted mint.
For the extended deployment, pass `-RequireExtendedStack`: the local demonstration
then requires both the ERC20 sale and primary revenue resolver addresses plus an
active registered Executor at Core's state export publisher pointer. Older pinned
baseline deployments remain readable without that flag. Both local and Sepolia
address maps retain the newer contracts when their creation receipts exist.

`DevelopmentEntropyProvider` accepts controller-supplied values. **These are not
secure randomness.** Its constructor rejects every chain except 31337. The local
mode never presents this provider as Chainlink VRF.

### Reuse a retained compilation safely

Both runners set and restore the `current` profile and compile the complete
current script selection with `--skip test`. Do not add per-script skip filters:
they can select a different compiler input and invalidate reuse. The complete raw
Foundry output and its paired cache are required; a published ABI/bytecode export
alone is not a reusable Foundry cache.

For an initial build, use fresh output paths:

```powershell
$env:FOUNDRY_PROFILE = 'current'
forge build --skip test --build-info --out "$env:TEMP/stream-raw/out" --cache-path "$env:TEMP/stream-raw/cache"
```

Preserve that raw pair. Prepare a separate writable copy before running a script:

```powershell
python -m tools.deployment.prepare_current_stack_compilation --artifacts "$env:TEMP/stream-raw/out" --cache "$env:TEMP/stream-raw/cache" --destination "$env:TEMP/stream-local-compiler"
pwsh -NoProfile -File scripts/run-current-stack.ps1 -OutputDirectory "$env:TEMP/stream-local-demo" -ArtifactDirectory "$env:TEMP/stream-local-compiler/out" -CacheDirectory "$env:TEMP/stream-local-compiler/cache"
```

Preparation verifies source freshness, compiler settings, the full compiler
input, and selected artifacts. It hash-checks every copied file, rebases only the
writable cache's two output-location fields, and checks the original pair again.
`compilation-workspace.json` records those identities. The same helper accepts
`--repo-root` when invoked from another directory. A successful copy does not
promise a cache hit: the subsequent Forge log must actually report
`No files changed, compilation skipped`. Source or configuration changes require
a new compilation and new evidence; never relabel an older prepared candidate.

### Real adapter, local upstream callback

The separate VRF rehearsal uses the actual `StreamEntropyProviderVRF` artifact
and the clearly named `MockVRFCoordinatorV2Plus` test artifact. It does not compile
or use a real subscription. Before the first mint, it deploys both contracts,
verifies source-bound artifacts, executable runtime and public configuration,
and changes the collection provider through its normal delayed governance call.
Only Anvil's clock advances; contract storage and authority checks are unchanged.

```powershell
pwsh -NoProfile -File scripts/run-current-stack.ps1 -DeployOnly -OutputDirectory "$env:TEMP/stream-vrf-demo" -ArtifactDirectory "$env:TEMP/stream-local-compiler/out" -CacheDirectory "$env:TEMP/stream-local-compiler/cache"
pwsh -NoProfile -File scripts/rehearse-current-stack-vrf.ps1 -OutputDirectory "$env:TEMP/stream-vrf-demo" -ArtifactDirectory "$env:TEMP/stream-local-compiler/out" -MockArtifactFile out/MockVRFCoordinatorV2Plus.sol/MockVRFCoordinatorV2Plus.json -CallbackGasLimit 500000
```

The mock artifact normally comes from the test build. If absent, build its single
source with `forge build test/mocks/MockVRFCoordinatorV2Plus.sol` into separate
output/cache directories and supply that artifact's path. The rehearsal refuses
stale source hashes. It preserves a call trace and distinguishes the adapter
callback frame's gas from the entire fulfillment transaction's gas. Request and
callback are separate mined transactions, with explicit Core notification and
final metadata assertions. This proves the local callback path, including its
gas cap; it does not prove Chainlink's proof verification, billing, solvency or
service delivery. Its default 500,000 cap does not alter Sepolia's 1,500,000 cap.

Run the offline helper regressions without an RPC node:

```powershell
python -m unittest tools.deployment.test_prepare_current_stack_compilation
pwsh -NoProfile -File scripts/test_current_stack_local.ps1
```

For deployment simulation without an RPC endpoint:

```powershell
$env:STREAM_DEPLOYER = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
$env:STREAM_PROTOCOL_TREASURY = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8'
$env:FOUNDRY_PROFILE = 'current'
forge script script/current/DeployCurrentStack.s.sol:DeployCurrentStack --via-ir --build-info --isolate --skip test --sender $env:STREAM_DEPLOYER
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

Inspect the unsigned deployment simulation against the intended RPC endpoint:

```powershell
$env:FOUNDRY_PROFILE = 'current'
forge script script/current/DeployCurrentStack.s.sol:DeployCurrentStack --via-ir --build-info --isolate --skip test --rpc-url $env:SEPOLIA_RPC_URL --sender $env:STREAM_DEPLOYER
```

For broadcasting, use the resumable Sepolia helper below. It checks the complete
unsigned plan against the transaction gas cap before its first deployment send.
Choose `-DeploymentGasEstimateMultiplier` from that fresh complete-plan result;
Forge's default margin exceeds the cap for the demonstrated 45-transaction plan.

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
The helper never exports a private key. Its local operational checkpoint retains
the exact call arguments, including sale signatures, so an interrupted send can
be recovered. Keep that checkpoint private and outside tracked release evidence.
The `Status` report omits those arguments and needs no account or keystore file.
Use PowerShell 7. Its default invocation performs live reads only:

```powershell
pwsh -NoProfile -File scripts/run-current-stack-sepolia.ps1 -Stage Preflight
pwsh -NoProfile -File scripts/run-current-stack-sepolia.ps1 -Stage Status -OutputDirectory $env:TEMP/6529stream-current-sepolia
```

It verifies the actual coordinator and proving key, reads recent base fees and
the deployer balance, and calculates a full-flow budget before deployment.
Individual calls check their own maximum cost; delivery retries can proceed
without funding another deployment or another randomness request.
The expected fee budget includes a modest reserve; the per-call
maximum fee remains a separate bound. The default demo mint price is 0.000001
Sepolia ETH. The default native subscription reserve is 1.2 Sepolia ETH for this
500 gwei lane and 1,500,000 callback limit. This is refundable subscription capital,
separate from the much smaller actual fulfillment charge. Chainlink's service can
leave an accepted request pending until this maximum-cost reserve is funded.
`-MaxFeePerGasWei`, `-PriorityFeeWei`, `-SubscriptionFundingWei`, and `-MintPriceWei`
allow explicit public operating values. None is a signing secret.

The helper checks the live lane cap, native premium and flat fee, with 300,000 gas
for verification and coordinator overhead. It rejects a target below that reserve.
The demonstrated request's Subscription Manager displayed a 1.1133045 ETH Max Cost;
its initial 0.005 ETH deposit was insufficient, even though transaction gas was
affordable. A later 1.12 ETH target exceeds the checked 1.116 ETH reserve. Unused
capital remains in the owned subscription; it is not reported as gas spent.

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
| `Status` | Reads checkpoint progress, pending transactions, subscription and token state without credentials, signing or checkpoint changes |
| `RetryEntropyDelivery` | Retries delivery of randomness already held by the provider; never requests a new random draw |
| `RetryMetadataNotification` | Retries an outstanding Core metadata notification after terminal entropy |

If the paid mint succeeds but the request does not, `RequestEntropy` resumes from
the recorded token. `Mint` also resumes its existing purchase/request rather
than buying another token. Before publication, the helper signs in memory,
validates the complete transaction envelope, and atomically saves its hash,
nonce and exact arguments in the local checkpoint. Signed transaction bytes
are sent over stdin and are never stored. A restart retrieves the same hash
or recreates that exact transaction; it does not allocate a replacement nonce.
An unknown or replaced nonce, reverted transaction, or changed chain inclusion
stops with a reconciliation message. Confirmed subscription, acceptance,
purchase, request and settlement steps are recovered before new inputs are built.

Keep `$env:TEMP/6529stream-current-sepolia/state.json` and its output directory
for the lifetime of this run. A sender lock prevents concurrent runner processes
from managing the same Sepolia account. `-ReceiptWaitSeconds` bounds receipt
waiting (default 30); a pending transaction can be checked with `Status` and
recovered by rerunning its original stage. This workflow does not automatically
raise fees or replace a transaction whose outcome is uncertain.

Delivery retry calls may mine successfully while the inner delivery remains
pending. The helper rereads the actual provider/pending state before reporting
completion. Retries use an explicit `-RetryGasLimit` (default 2,000,000), because
gas estimation can otherwise settle on a cheap unsuccessful inner delivery.
If another attempt is needed, use the next `-RetryAttempt` number. Reusing a
completed attempt only reconciles its receipt and current result.

```powershell
pwsh -NoProfile -File scripts/run-current-stack-sepolia.ps1 -Stage RetryEntropyDelivery -RetryAttempt 1 -Broadcast
pwsh -NoProfile -File scripts/run-current-stack-sepolia.ps1 -Stage RetryMetadataNotification -RetryAttempt 1 -Broadcast
```

For an interrupted Forge deployment, retain its standard broadcast files and use
`ResumeDeploy` on the same source commit. The helper verifies each recorded
transaction's sender, nonce, target, value, and calldata hash. A fresh `Deploy`
is blocked by an existing attempt or broadcast file. If the broadcast file is
missing, recover the receipts before continuing. Only one process should own the
dedicated deployer's nonce sequence.

For a new deployment, use a new `-OutputDirectory` and distinct
`-ArtifactDirectory`, `-CacheDirectory`, and `-BroadcastDirectory` paths. Keep
those same paths for its later stages and recovery. Relative compiler and
broadcast paths resolve from the repository root. Archive an earlier deployment's
complete compiler outputs, build-info, broadcast files, and public state before
compiling a corrected candidate; earlier addresses remain historical evidence.
`-DeploymentGasEstimateMultiplier` controls the explicit deployment gas margin
(default 120 percent). Use the same value when resuming. A complete simulation
must show every buffered limit below the chain cap before the helper signs;
the 45-transaction plan prepared on 10 September 2026 uses 109 percent, with a
maximum planned limit of 16,627,237 gas. Its 115 percent plan exceeds the cap.
Choose the margin from the complete fresh plan for each deployment; an earlier
candidate's accepted margin does not establish that a later plan fits.

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

The historical fork rehearsal at Sepolia block 11670719 includes 48 transactions
and all linked libraries: 100,267,574 estimated execution gas before the demo.
Its largest transaction gas limit at the helper's 120% multiplier is 16,175,894,
below Sepolia's 16,777,216 cap. These are simulation measurements, not live
receipts, and they predate the current 45-transaction plan. Each real deployment
is simulated again against its actual subscription.

Run the helper's offline receipt/recovery regression checks with:

```powershell
pwsh -NoProfile -File scripts/test_current_stack_sepolia.ps1
pwsh -NoProfile -File scripts/test_current_stack_transaction_journal.ps1
pwsh -NoProfile -File scripts/test_current_stack_launch_status.ps1
```
