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
